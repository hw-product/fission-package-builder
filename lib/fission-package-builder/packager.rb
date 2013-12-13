require 'attribute_struct'

module Fission
  module PackageBuilder
    class Packager < AttributeStruct
      class << self

        attr_accessor :file_name

        def build(&block)
          new(&block)._dump
        end

        def load(path)
          if(File.exists?(path))
            if(defined?(Sandbox))
              Sandbox.eval(File.read(path))
            else
              PackageBuilder.class_eval do
                eval(File.read(path))
              end
            end
          else
            raise Error::PkgrFileNotFound.new("Failed to locate pkgr file: #{path}")
          end
        end
      end
    end

    # Alias for short form
    Pkgr = Packager
    # Default file name
    Packager.file_name = '.packager'
  end
end
