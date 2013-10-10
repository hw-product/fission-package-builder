require 'fission'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Repository < Fission::Callback

      include Fission::Utils::MessageUnpack

      def valid?(message)
        !unpack(message).has_key?(:repository)
      end

      def execute(message)
        info "#{message} repository not provided. Forwarding to code fetcher."
        payload = unpack(message)
        Celluloid::Actor[:fission_code_fetcher].transmit(payload, message)
      end

    end
  end
end

Fission.register(:fission_package_builder, Fission::PackageBuilder::Repository)
