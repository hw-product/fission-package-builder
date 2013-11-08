$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'fission-package-builder/version'
Gem::Specification.new do |s|
  s.name = 'fission-package-builder'
  s.version = Fission::PackageBuilder::VERSION.version
  s.summary = 'Fission Package Builder'
  s.author = 'Heavywater'
  s.email = 'fission@hw-ops.com'
  s.homepage = 'http://github.com/heavywater/fission-package-builder'
  s.description = 'Fission Package Builder'
  s.require_path = 'lib'
  s.add_dependency 'fission'
  s.add_dependency 'carnivore'
  s.add_dependency 'attribute_struct'
  s.add_dependency 'elecksee'
  s.files = Dir['**/*']
end
