require 'fission'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Repository < Fission::Callback

      include Fission::Utils::MessageUnpack

      def valid?(message)
        m = unpack(message)
        m[:data][:user] && !m[:data][:repository]
      end

      def execute(message)
        info "#{message} repository not provided. Forwarding to code fetcher."
        payload = unpack(message)
        transmit(:code_fetcher, payload)
      end

    end
  end
end

Fission.register(:package_builder, :validators, Fission::PackageBuilder::Repository)
