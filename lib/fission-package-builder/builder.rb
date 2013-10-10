require 'fission/callback'

module Fission
  module PackageBuilder
    class Builder < Fission::Callback

      def valid?(message)
        m = unpack(message)
        m[:user] && m[:repository] && m[:job] == 'package_builder'
      end

      def execute(message)
        info "#{message} building package"
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::Validators::Validate)
Fission.register(:fission_package_builder, Fission::PackageBuilder::Builder)
