require 'fission'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Repository < Fission::Callback

      include Fission::Utils::MessageUnpack

      def valid?(message)
        m = unpack(message)
        m.has_key?(:user) && !m.has_key?(:repository)
      end

      def execute(message)
        info "#{message} repository not provided. Forwarding to code fetcher."
        payload = unpack(message)
        transmit(:fission_code_fetcher, payload)
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::PackageBuilder::Repository)
