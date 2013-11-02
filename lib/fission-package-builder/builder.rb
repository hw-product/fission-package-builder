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
        config = load_config(message[:repository][:path])
        chef_json = build_chef_json(config)
        start_build(message[:message_id], chef_json)
        message.confirm!
      end

      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      def build_chef_json(config)
        JSON.dump(
          :fission => {
            :build => config
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
        process_manager.process(uuid, ['chef-solo', '-j', json_path, '-c', write_solo_config(uuid)]) do |process|
          process.io.stdout = process.io.stderr = log_file
          process.detach true
          process.start
        end
      end

      def workspace(thing=nil)
        base = Carnivore.get(:fission, :package_builder, :working_directory) || '/tmp'
        path = File.join(base, thing)
        unless(File.directory?(path))
          FileUtils.mkdir_p(path)
        end
        path
      end

      def solo_config_path(uuid)
        File.join(workspace, "#{uuid}-solo.rb")
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
        unless(File.exists?(solo_config_path))
          cache_path = workspace("chef-cache/#{uuid}")
          File.open(solo_path, 'w') do |file|
            file.puts "file_cache_path '#{cache_path}'"
            file.puts "cookbook_path '#{fission_cookbook_path}'"
          end
        end
        solo_path
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::Validators::Validate)
Fission.register(:fission_package_builder, Fission::PackageBuilder::Builder)
