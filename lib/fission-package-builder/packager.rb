require 'attribute_struct'

# TODO: Ideally we should ship this out to a separate process that can
# evaluate, dump hash, return and teardown

module Fission
  module PackageBuilder
    class Packager < AttributeStruct
      class << self

        attr_accessor :file_name

        def build(&block)
          new(&block)._dump
        end

        def load(path)
          PackageBuilder.eval(File.read(path))
        end
      end
    end

    # Alias for short form
    Pkgr = Packager
    # Default file name
    Package.file_name = '.pkgr.io'
  end
end
