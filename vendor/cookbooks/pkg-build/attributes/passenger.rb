default[:pkg_build][:passenger][:root] = File.dirname(node[:languages][:ruby][:bin_dir])
default[:pkg_build][:passenger][:version] = '3.0.18'
default[:pkg_build][:passenger][:ruby_dependency] = nil
default[:pkg_build][:passenger][:allow_omnibus_chef_ruby] = false
