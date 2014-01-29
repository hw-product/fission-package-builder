require 'fission/callback'
require 'fission/validators/validate'
require 'fission/validators/repository'
require 'fission-package-builder/errors'
require 'fission-package-builder/packager'

require 'fission-assets'
require 'fission-assets/packer'

require 'elecksee/ephemeral'

Lxc.use_sudo = true
Lxc.shellout_helper = :childprocess #:mixlib_shellout

module Fission
  module PackageBuilder
    class Builder < Fission::Callback

      attr_reader :object_store

      def setup(*args)
        @object_store = Fission::Assets::Store.new
        if(RUBY_PLATFORM == 'java')
#          require 'fission-package-builder/sandbox'
        end
      end

      # Only build if we have an account set and repository available
      def valid?(message)
        super do |m|
          retrieve(m, :data, :account) && retrieve(m, :data, :repository)
        end
      end

      def execute(message)
        failure_wrap(message) do |payload|
          begin
            payload[:data][:package_builder] = {}
            copy_path = repository_copy(payload[:message_id], payload[:data][:repository][:path])
            config = load_config(copy_path)
            chef_json = build_chef_json(config, payload, copy_path)
            load_history_assets(config, payload)
            start_build(payload[:message_id], chef_json, retrieve(config, :target))
            store_packages(payload)
            set_notifications(config, payload)
            job_completed(:package_builder, payload, message)
          rescue Lxc::CommandFailed
            set_notifications(config, payload, :failed)
            failed(payload, message, e.message)
          end
        end
      end

      # config:: packager config
      # payload:: Payload
      # Retrieve previous versions from asset store and add to history
      def load_history_assets(config, payload)
        if(versions = retrieve(config, :build, :history, :versions))
          versions = [versions].flatten.compact.uniq
          ext = retrieve(config, :target, :package)
          versions.each do |version|
            filename = "#{payload[:data][:package_builder][:name]}-#{version}.deb"
            key = generate_key(payload, filename)
            package = object_store.get(key)
            File.open(history = File.join(workspace(payload[:message_id], :history), filename), 'wb') do |file|
              while(bytes = package.read(2048))
                file.write bytes
              end
            end
            debug "Wrote history asset -> #{history}"
          end
        end
      end

      # payload:: payload
      # file:: File name or path
      # Generate the asset store key based on file and payload
      def generate_key(payload, file)
        key = [
          'packages',
          retrieve(payload, :data, :account, :name),
          File.basename(file)
        ].compact.join('_')
      end

      # payload:: Payload
      # Store packages into private data store
      def store_packages(payload)
        keys = Dir.glob(File.join(workspace(payload[:message_id], :packages), '*')).map do |file|
          key = generate_key(payload, file)
          object_store.put(key, file)
          key
        end
        payload[:data][:package_builder][:keys] = keys
        true
      end

      # repo_path:: Path to repository on local sytem
      # Returns hash'ed configuration file
      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      # config:: build config hash
      # params:: payload
      # target_store:: location to store built packages
      # Build the JSON for our chef run
      def build_chef_json(config, params, target_store)
        unless(config[:build][:version])
          if((ref = retrieve(params, :data, :github, :ref)).start_with?('refs/tags'))
            config[:build][:version] = ref.sub('refs/tags/', '')
          else
            config[:build][:version] = Time.now.strftime('%Y%m%d%H%M%S')
          end
        end
        params[:data][:package_builder][:name] = config[:build][:name] || retrieve(params, :data, :github, :repository, :name)
        params[:data][:package_builder][:version] = config[:build][:version]
        JSON.dump(
          :packager => {
            :build => config.merge(
              :target_store => target_store,
              :history_directory => workspace(params[:message_id], :history)
            ),
            :environment => {
              'PACKAGER_HISTORY_DIR' => workspace(params[:message_id], :history),
              'PACKAGER_NAME' => config[:build][:name],
              'PACKAGER_INSTALL_PREFIX' => config[:build][:install_prefix],
              'PACKAGER_TYPE' => config[:target][:package],
              'PACKAGER_VERSION' => config[:build][:version],
              'PACKAGER_COMMIT_SHA' => params[:data][:github][:after],
              'PACKAGER_PUSHER_NAME' => params[:data][:github][:pusher][:name],
              'PACKAGER_PUSHER_EMAIL' => params[:data][:github][:pusher][:email]
            }
          },
          :fpm_tng => {
            :package_dir => workspace(params[:message_id], :packages),
            :build_dir => workspace(params[:message_id], :fpm)
          },
          :run_list => ['recipe[packager]']
        )
      end

      # uuid:: unique ID (message id)
      # json:: chef json
      # base:: base container for ephemeral
      # Start the build
      def start_build(uuid, json, base={})
        if(base[:platform])
          base = "#{base[:platform]}_#{base.fetch(:version, '12.04').gsub('.', '')}"
        else
          base = 'ubuntu_1204'
        end
        json_path = File.join(workspace(uuid, :first_runs), "#{uuid}.json")
        File.open(json_path, 'w') do |f|
          f.puts json
        end
        log_file_path = File.join(workspace(uuid, :log), "#{uuid}.log")
        log_file = File.open(log_file_path, 'w')
        log_file.sync = true
        command = [chef_exec_path, '-j', json_path, '-c', write_solo_config(uuid)]
        ephemeral = Lxc::Ephemeral.new(
          :original => base,
          :bind => workspace(uuid),
          :ephemeral_command => command.join(' ')
        )
        begin
          ephemeral.start!
        rescue Lxc::CommandFailed => e
          error "Package build failed: #{e.result.stderr}"
          raise e
        end
        debug "Finished command: #{command.join(' ')}"
      end

      # uuid:: unique id (message id)
      # thing:: bucket in workspace
      # Return path to workspace (creates if required)
      def workspace(uuid, thing=nil)
        base = Carnivore::Config.get(:fission, :package_builder, :working_directory) || '/tmp'
        path = File.join(base, uuid, thing.to_s)
        unless(File.directory?(path))
          FileUtils.mkdir_p(path)
        end
        path
      end

      # uuid:: unique id (message id)
      # repo_path:: Repo to fetch
      # Unpacks repository into `code` workspace
      def repository_copy(uuid, repo_path)
        code_path = workspace(uuid, :code)
        Fission::Assets::Packer.unpack(object_store.get(repo_path), code_path)
      end

      # Path to packager specific cookbooks for building that are
      # vendored with the library
      def fission_cookbook_path
        unless(@cookbook_path)
          @cookbook_path = File.expand_path(File.join(File.dirname(__FILE__), '../../vendor/cookbooks'))
        end
        @cookbook_path
      end

      # uuid:: unique id (message id)
      # Writes the configuration file for chef
      def write_solo_config(uuid)
        solo_path = File.join(workspace(uuid, :solos), "solo.rb")
        unless(File.exists?(solo_path))
          cache_path = workspace(uuid, :chef_cache)
          cookbook_path = cookbook_copy(uuid)
          File.open(solo_path, 'w') do |file|
            file.puts "file_cache_path '#{cache_path}'"
            file.puts "cookbook_path '#{cookbook_path}'"
          end
        end
        solo_path
      end

      # uuid:: unique id (message id)
      # Copies vendored cookbooks to local path for chef run. Returns
      # path of copy
      # NOTE: Cookbooks need to be copied to allow proper bind
      # NOTE: This will be updated soon so containers have set
      # readonly bind defined in base container so ephemerals will
      # automatically have it available.
      def cookbook_copy(uuid)
        local_path = workspace(uuid, :cookbooks)
        directory_copy(fission_cookbook_path, local_path)
        local_path
      end

      # Path to chef-solo
      def chef_exec_path
        Carnivore::Config.get(:fission, :package_builder, :chef_solo_path) || 'chef-solo'
      end

      # source:: source directory
      # target:: target directory
      # Streaming file copy. This is to allow extracting files from a
      # jar to the local FS without hitting weird encoding issues.
      def directory_copy(source, target)
        unless(File.directory?(target))
          FileUtils.mkdir_p(target)
        end
        Dir.new(source).each do |_path|
          next if _path == '.' || _path == '..'
          path = File.join(source, _path)
          if(File.directory?(path))
            directory_copy(path, File.join(target, _path))
          else
            new_path = File.join(target, _path)
            unless(File.directory?(File.dirname(new_path)))
              FileUtils.mkdir_p(File.dirname(new_path))
            end
            begin
              source_file = File.open(path, 'rb')
              File.open(new_path, 'wb') do |new_file|
                while(data = source_file.read(2048))
                  new_file.print data
                end
              end
            rescue => e
              error "Failed to copy file to local system: #{path} -> #{new_path}"
              debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
            end
          end
        end
        true
      end

      # config:: Packager config
      # payload:: Payload
      # Set notification data in payload
      def set_notifications(config, payload, failed = false)
        set_mail_notification(config, payload, failed)
        set_github_status_notification(config, payload, failed)
        set_github_comment_notification(config, payload, failed)
      end

      # payload:: Payload
      # Attempt to extract error message from chef-stacktrace if file
      # exists and error is findable
      def extract_chef_stacktrace(payload)
        path = File.join(workspace(payload[:message_id], :chef_cache), 'chef-stacktrace.out')
        if(File.exists?(path))
          debug "Found chef stacktrace file for error extraction (#{path})"
          content = File.readlines(path)
          start = content.index{|line| line.start_with?('ERROR')}
          stop = content.index{|line| line.start_with?('Ran')}
          if(start && stop)
            error_msg = content.slice(start, stop - start + 1)
            debug "Extracted error message: #{error_msg}"

          end
        else
          debug "Failed to locate chef stacktrace file for error extraction (#{path})"
        end
      end

      # Set payload data for github notifications
      def set_github_status_notification(config, payload, failed = false)
        if(failed)
          payload[:data][:github_status] = {
            :state => :failed,
            :description => 'Package build failed',
            :target_url => job_url(payload)
          }
        else
          payload[:data][:github_status][:state] = :success
        end
      end

      # Set payload data for github comment
      def set_github_comment_notification(config, payload, failed = false)
        pkg = payload[:data][:package_builder]
        if(failed)
          payload[:data][:github_commit] = {
            :message => [
              "[#{origin[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
              "Package building attempt failed!\n\nExtracted error message:\n",
              "```",
              "#{extract_chef_stacktrace(payload) || '<unavailable>'}\n",
              "```",
              "- #{job_url(payload)}"
            ].join("\n")
          }
        else
          payload[:data][:github_commit] = {
            :message => "[#{origin[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})"
          }
        end
      end

      # Set payload data for mail type notifications
      def set_mail_notification(config, payload, failed = false)
        pkg = payload[:data][:package_builder]
        dest_email = config[:notify] ||
          retrieve(payload, :data, :github, :repository, :owner, :email) ||
          retrieve(payload, :data, :github, :pusher, :email)
        details = File.join(
          payload[:data][:github][:repository][:url].sub('git:', 'https:').sub('.git', ''),
          pkg[:version]
        )
        notify = {
          :destination => {
            :email => dest_email
          },
          :origin => {
            :email => origin[:email],
            :name => origin[:name]
          }
        }
        if(failed)
          error_message = extract_chef_stacktrace(payload)
          notify.merge!(
            :subject => "[#{origin[:application]}] FAILED #{pkg[:name]} build (version: #{pkg[:version]})",
            :message => "Package building attempt failed!\n\nExtracted error message:\n\n#{error_message || '<unavailable>'}\n\n- #{job_url(payload)}",
            :html => false
          )
        else
          notify.merge!(
            :subject => "[#{origin[:application]}] New #{pkg[:name]} created (version: #{pkg[:version]})",
            :message => "A new package has been built from the #{pkg[:name]} repository.\n\nRelease: #{pkg[:name]}-#{pkg[:version]}\nDetails: #{details}\n",
            :html => false
          )
        end
        payload[:data][:notification_email] = notify
      end

    end
  end
end

Fission.register(:package_builder, :validators, Fission::Validators::Validate)
Fission.register(:package_builder, :validators, Fission::Validators::Repository)
Fission.register(:package_builder, :builder, Fission::PackageBuilder::Builder)
