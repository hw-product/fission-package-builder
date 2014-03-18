require 'attribute_struct'
require 'multi_json'

module Fission
  module PackageBuilder
    class Packager < AttributeStruct
      class << self

        attr_accessor :file_name

        def build(&block)
          new(&block)._dump
        end

        def load(path)
          if(File.exist?(path))
            json_load(path) || ruby_load(path)
          else
            raise Error::PkgrFileNotFound.new("Failed to locate pkgr file: #{path}")
          end
        end

        def wrapper_file
          file = <<-WRAPPER
          require 'attribute_struct'
          require 'json'
          require 'tempfile'
          require 'securerandom'
          class Packager < AttributeStruct
            class << self
              def build(&block)
                file = File.open(File.join('/tmp', SecureRandom.uuid), 'w')
                file.puts JSON.dump(new(&block)._dump)
                file.close
                $stdout.puts file.path
              end
            end
          end
          WRAPPER
        end

        def ruby_load(path)
          ephemeral = Lxc::Ephemeral.new(
            :original => 'ubuntu_1204',
            :bind => File.dirname(path)
          )
          result = nil
          begin
            ephemeral.create!
            File.open(ephemeral.lxc.rootfs.join('tmp/pkgr.rb'), 'w') do |file|
              file.puts wrapper_file
            end
            com = "/opt/chef/embedded/bin/ruby -r/tmp/pkgr.rb -C#{File.dirname(path)} #{path}"
            result = ephemeral.lxc.execute(
              "/opt/chef/embedded/bin/ruby -r/tmp/pkgr -C#{File.dirname(path)} #{path}"
            )
            content = File.read(
              ephemeral.lxc.rootfs.join(
                result.stdout.strip
              )
            )
            result = MultiJson.load(content, :symbolize_keys => true)
          ensure
            ephemeral.cleanup
          end
          result
        end

        def json_load(path)
          begin
            MultiJson.load(File.read(path), :symbolize_keys => true)
          rescue MultiJson::LoadError
            nil
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
