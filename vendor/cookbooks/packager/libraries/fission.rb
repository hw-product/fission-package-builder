module Packager

  class Smash < Mash

    # keys:: Keys to walk into hash
    # Return value at and of key path
    def retrieve(*keys)
      keys.inject(self) do |memo, key|
        if(memo.has_key?(valid_key = key.to_s) || memo.has_key?(valid_key = key.to_sym))
          memo[valid_key]
        else
          break
        end
      end
    end

  end

  class << self

    def to_hash(hash)
      new_hash = Smash.new
      hash.each do |k,v|
        new_hash[k] = v.is_a?(Hash) ? to_hash(v) : v
      end
      new_hash
    end
    alias_method :to_smash, :to_hash

  end

  module Attribute
    def export_hash
      new_hash = Mash.new
      self.each do |k,v|
        new_hash[k] = v.respond_to?(:export_hash) ? v.export_hash : v
      end
      new_hash
    end

  end

  module Reactor

    module Station

      class << self
        def included(klass)
          klass.class_eval do
            attribute :disable_before, :kind_of => Array, :default => []
            attribute :disable_after, :kind_of => Array, :default => []
          end
        end
      end

    end

    module Core

      def reactor
        unless(block_given?)
          raise TypeError.new('`reactor` expects block. No block provided!')
        else
          execute_resources_if_enabled!(:before, :dependencies)
          if(new_resource.args.retrieve(:dependencies, :build))
            new_resource.args[:dependencies][:build].each do |pkg_name, pkg_version|
              package pkg_name do
                if(pkg_version)
                  version pkg_version
                end
              end
            end
          end
          execute_resources_if_enabled!(:after, :dependencies)
          execute_resources_if_enabled!(:before, :build)
          yield
          execute_resources_if_enabled!(:after, :build)
          run_callbacks!
        end
      end

      def run_callbacks!
        if(new_resource.args[:callbacks])
          new_resource.args[:callbacks].each do |name, config|
            case config[:type].to_sym
            when :fission
              raise NameError.new('Fission callback not implemented!')
            when :webservice
              raise NameError.new('Webservice callback not implemented!')
            else
              Chef::Log.error "Fission callback: Unknown callback type provided: #{config[:type]}"
            end
          end
        end
      end

      def execute_resources_if_enabled!(timing, location)
        if(new_resource.args.retrieve(:build, :commands, timing, location))
          unless(new_resource.send("disable_#{timing}").include?(location))
            new_resource.args[:build][:commands][timing][location].each do |com|
              case com
              when String
                execute "#{timing}_#{location}(#{com})" do
                  command com
                  cwd '/tmp'
                end
              when Hash
                execute "#{timing}_#{location}(#{com})" do
                  com.each do |k,v|
                    self.send(k,v)
                  end
                end
              else
                raise TypeError.new("Expecting String or Hash type. Got `#{com.class}` type instead.")
              end
            end
          end
        end
      end

    end
  end
end
