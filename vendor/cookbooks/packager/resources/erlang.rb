include ::Packager::Reactor::Station

actions :build
default_action :build

attribute :args, :kind_of => Hash, :required => true
