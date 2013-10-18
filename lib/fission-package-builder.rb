require 'fission'
require 'fission-package-builder/version'
require 'fission-package-builder/builder'

Dir.glob(File.join(File.dirname(__FILE__), 'fission-package-builder', 'validations', '*.rb')).each do |path|
  require "fission-package-builder/validations/#{File.basename(path).sub('.rb', '')}"
end
