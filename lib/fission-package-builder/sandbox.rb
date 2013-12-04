require 'sandbox'
require 'carnivore/utils'
require 'attribute_struct'
require 'attribute_struct/attribute_hash'
require 'hashie'

module Fission
  module PackageBuilder
    class Sandbox < Sandbox::Safe

      include Carnivore::Utils::Logging

      class << self

        def eval(string, opts={})
          sandbox = new
          %w(hashie attribute_struct).each do |lib|
            path = $:.detect{|path| path.include?(lib)}
            if(path)
              sandbox.eval %{$: << '#{path}'}
            end
          end
          %w(hashie json attribute_struct attribute_struct/attribute_hash attribute_struct/monkey_camels).each do |lib|
            sandbox.require lib
          end
#            sandbox.activate!
          sandbox.eval(string, opts)
        end

      end

      def eval(*args)
        begin
          super
        rescue Exception => e
          error "Eval failed: #{e}"
          nil
        end
      end

    end
  end
end
