require 'fission/utils/message_unpack'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Repository < Carnivore::Callback

      include Fission::Utils::MessageUnpack

      def valid?(message)
        !unpack(message).has_key?(:repository)
      end

      def execute(message)
        info "#{message} repository not provided. Forwarding to code fetcher."
        payload = unpack(message)
        Celluloid::Actor[:fission_bus].transmit(
          payload, :code_fetcher
        )
      end

    end
  end
end
