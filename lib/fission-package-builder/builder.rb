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

      def valid?(message)
        super do |m|
          retrieve(m, :data, :account) && retrieve(m, :data, :repository)
        end
      end

      def execute(message)
        payload = unpack(message)
        begin
          payload[:data][:package_builder] = {}
          copy_path = repository_copy(payload[:message_id], payload[:data][:repository][:path])
          config = load_config(copy_path)
          chef_json = build_chef_json(config, payload, copy_path)
          start_build(payload[:message_id], chef_json)
          store_packages(payload)
          job_completed(:package_builder, payload, message)
        rescue Fission::Error => e
          error "Failure encountered: #{e.class}: #{e}"
          debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
          failed(payload, message, e.message)
        end
      end

      def store_packages(payload)
        keys = Dir.glob(File.join(workspace(payload[:message_id], :packages), '*')).map do |file|
          key = "#{payload[:message_id]}_#{File.basename(file)}"
          object_store.put(key, file)
          key
        end
        payload[:data][:package_builder][:keys] = keys
        true
      end

      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      def build_chef_json(config, params, target_store)
        config[:build][:version] ||= Time.now.strftime('%Y%m%d%H%M%S')
        params[:data][:package_builder][:version] = config[:build][:version]
        JSON.dump(
          :packager => {
            :build => config.merge(
              :target_store => target_store
            ),
            :environment => {
              'PACKAGER_VERSION' => config[:build][:version],
              'PACKAGER_COMMIT_SHA' => params[:data][:github][:after],
              'PACKAGER_PUSHER_NAME' => params[:data][:github][:pusher][:name],
              'PACKAGER_PUSHER_EMAIL' => params[:data][:github][:pusher][:email]
            }
          },
          :fpm_tng => {
            :package_dir => workspace(params[:message_id], :packages)
          },
          :run_list => ['recipe[packager]']
        )
      end

      def packages_directory
        unless(@pkg_dir)
          @pkg_dir = Carnivore::Config.get(:fission, :package_builder, :packages_directory) || '/tmp/packages'
          FileUtils.mkdir_p(@pkg_dir)
        end
        @pkg_dir
      end

      def start_build(uuid, json)
        json_path = File.join(workspace(uuid, :first_runs), "#{uuid}.json")
        File.open(json_path, 'w') do |f|
          f.puts json
        end
        log_file_path = File.join(workspace(uuid, :log), "#{uuid}.log")
        log_file = File.open(log_file_path, 'w')
        log_file.sync = true
        command = [chef_exec_path, '-j', json_path, '-c', write_solo_config(uuid)]
        ephemeral = Lxc::Ephemeral.new(
          :original => 'ubuntu_1204',
          :bind => packages_directory,
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

      def workspace(uuid, thing=nil)
        base = Carnivore::Config.get(:fission, :package_builder, :working_directory) || '/tmp'
        path = File.join(base, uuid, thing.to_s)
        unless(File.directory?(path))
          FileUtils.mkdir_p(path)
        end
        path
      end

      def repository_copy(uuid, repo_path)
        code_path = workspace(uuid, :code)
        Fission::Assets::Packer.unpack(object_store.get(repo_path), code_path)
      end

      def fission_cookbook_path
        unless(@cookbook_path)
=begin
# For now we need to use relative pathing since we are forcibly
# loading paths when running via jar
          spec = Gem::Specification.find_by_name(
            'fission-package-builder',
            Fission::PackageBuilder::VERSION.version
          )
          @cookbook_path = File.join(spec.full_gem_path, 'vendor/cookbooks')
=end
          @cookbook_path = File.expand_path(File.join(File.dirname(__FILE__), '../../vendor/cookbooks'))
        end
        @cookbook_path
      end

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

      def cookbook_copy(uuid)
        local_path = workspace(uuid, :cookbooks)
        directory_copy(fission_cookbook_path, local_path)
        local_path
      end

      def chef_exec_path
        Carnivore::Config.get(:fission, :package_builder, :chef_solo_path) || 'chef-solo'
      end

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

    end
  end
end

Fission.register(:package_builder, :validators, Fission::Validators::Validate)
Fission.register(:package_builder, :validators, Fission::Validators::Repository)
Fission.register(:package_builder, :builder, Fission::PackageBuilder::Builder)
