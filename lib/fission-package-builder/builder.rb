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
        start_build
        message.confirm!
      end

      def load_config(repo_path)
        Packager.load(File.join(repo_path, Packager.file_name))
      end

      def build_chef_json(config)

      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::Validators::Validate)
Fission.register(:fission_package_builder, Fission::PackageBuilder::Builder)
