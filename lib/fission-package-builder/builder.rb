require 'fission/utils/message_unpack'
require 'carnivore/callback'

module Fission
  module PackageBuilder
    class Builder < Carnivore::Callback

      include Fission::Utils::MessageUnpack

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
