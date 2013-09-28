require 'fission/utils/message_unpack'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Validate < Carnivore::Callback

      include Fission::Utils::MessageUnpack

      def valid?(message)
        !unpack(message).has_key?(:user)
      end

      def execute(message)
        info "#{message} is not validated. Forwarding to validator."
        payload = unpack(message)
        Celluloid::Actor[:fission_bus].transmit(
          payload, :validator
        )
      end

    end
  end
end
