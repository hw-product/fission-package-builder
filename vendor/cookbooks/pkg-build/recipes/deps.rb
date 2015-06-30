# These are all the things we want all the time. So load them!

Mixlib::ShellOut.send(:remove_const, :DEFAULT_READ_TIMEOUT)
Mixlib::ShellOut.send(:const_set, :DEFAULT_READ_TIMEOUT, 3600)

include_recipe 'apt'
include_recipe 'builder'
include_recipe 'fpm-tng'

if(node[:pkg_build][:reprepro])
  include_recipe 'reprepro'
  include_recipe 'pkg-build::helpers'
end

node.set[:pkg_build][:builder] = true

