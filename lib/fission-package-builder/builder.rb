require 'fission/callback'
require 'fission-package-builder/packager'
require 'elecksee/ephemeral'

Lxc.use_sudo = true

module Fission
  module PackageBuilder
    class Builder < Fission::Callback

      def valid?(message)
        super
        m = unpack(message)
        m[:data][:user] && m[:data][:repository]
      end

      def execute(message)
        m = unpack(message)
        config = load_config(m[:data][:repository][:path])
        chef_json = build_chef_json(config, m)
        start_build(m[:message_id], chef_json)
        completed(m, message)
      end

      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      def build_chef_json(config, params)
        JSON.dump(
          :fission => {
            :build => config.merge(
              :target_store => repository_copy(params[:message_id], params[:data][:repository][:path])
            )
          },
          :fpm_tng => {
            :package_dir => workspace(params[:message_id], :packages)
          },
          :run_list => ['recipe[fission]']
        )
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
          :bind => '/tmp/packages',
          :ephemeral_command => command.join(' ')
        )
        begin
          ephemeral.start!
        rescue Lxc::CommandFailed => e
          error "Package build failed: #{e.result.stderr}"
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
        FileUtils.cp_r("#{repo_path}/.", code_path)
        code_path
      end

      def fission_cookbook_path
        unless(@cookbook_path)
          spec = Gem::Specification.find_by_name(
            'fission-package-builder',
            Fission::PackageBuilder::VERSION.version
          )
          @cookbook_path = File.join(spec.full_gem_path, 'vendor/cookbooks')
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
        FileUtils.cp_r("#{fission_cookbook_path}/.", local_path)
        local_path
      end

      def chef_exec_path
        Carnivore::Config.get(:fission, :package_builder, :chef_solo_path) || 'chef-solo'
      end

    end
  end
end

Fission.register(:package_builder, :validators, Fission::Validators::Validate)
Fission.register(:package_builder, :builder, Fission::PackageBuilder::Builder)
