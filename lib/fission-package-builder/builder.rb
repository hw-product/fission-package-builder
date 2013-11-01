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
        json_path = "/tmp/chef-#{uuid}.json"
        File.open(json_path, 'w') do |f|
          f.puts json
        end
        process_manager.process(uuid, ['chef-solo', '-j', json_path]) do |process|
          process.io.inherit!
          process.detach true
          process.start
        end
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::Validators::Validate)
Fission.register(:fission_package_builder, Fission::PackageBuilder::Builder)
