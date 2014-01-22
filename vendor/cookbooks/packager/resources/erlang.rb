include ::Packager::Reactor::Station

actions :build
default_action :build

attribute :args, :kind_of => Hash, :required => true
attribute :rebar_base_url, :kind_of => String, :default => 'https://github.com/rebar/rebar/archive'
attribute :rebar_version, :kind_of => String, :default => '2.1.0'
