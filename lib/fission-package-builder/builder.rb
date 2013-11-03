require 'fission/callback'
require 'fission-package-builder/packager'

module Fission
  module PackageBuilder
    class Builder < Fission::Callback

      def valid?(message)
        m = unpack(message)
        m[:user] && m[:repository]
      end

      def execute(message)
        m = unpack(message)
        config = load_config(m[:repository][:path])
        chef_json = build_chef_json(config, m)
        start_build(m[:message_id], chef_json)
        message.confirm!
      end

      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      def build_chef_json(config, params)
        JSON.dump(
          :fission => {
            :build => config.merge(
              :target_store => params[:repository][:path]
            )
          },
          :run_list => ['recipe[fission]']
        )
      end

      def start_build(uuid, json)
        json_path = File.join(workspace(:first_runs), "#{uuid}.json")
        File.open(json_path, 'w') do |f|
          f.puts json
        end
        log_file_path = File.join(workspace(:log), "#{uuid}.log")
        log_file = File.open(log_file_path, 'w')
        log_file.sync = true
        command = [chef_exec_path, '-j', json_path, '-c', write_solo_config(uuid)]
        debug "Starting command: #{command.join(' ')}"
        process_manager.process(uuid, command) do |process|
          process.io.stdout = process.io.stderr = log_file
          process.cwd = '/tmp'
          process.detach = true
          process.start
        end

      end

      def workspace(thing=nil)
        base = Carnivore::Config.get(:fission, :package_builder, :working_directory) || '/tmp'
        path = File.join(base, thing.to_s)
        unless(File.directory?(path))
          FileUtils.mkdir_p(path)
        end
        path
      end

      def solo_config_path(uuid)
        File.join(workspace(:solos), "#{uuid}-solo.rb")
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
        solo_path = solo_config_path(uuid)
        unless(File.exists?(solo_path))
          cache_path = workspace("chef-cache/#{uuid}")
          File.open(solo_path, 'w') do |file|
            file.puts "file_cache_path '#{cache_path}'"
            file.puts "cookbook_path '#{fission_cookbook_path}'"
          end
        end
        solo_path
      end

      def chef_exec_path
        Carnivore::Config.get(:fission, :package_builder, :chef_solo_path) || 'chef-solo'
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::Validators::Validate)
Fission.register(:fission_package_builder, Fission::PackageBuilder::Builder)
