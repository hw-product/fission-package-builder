include_recipe 'pkg-build::deps'

ruby_block 'Detect omnibus ruby' do
  block do
    if(node[:languages][:ruby][:ruby_bin].include?('/opt/chef'))
      raise 'Cannot build passenger against omnibus Chef Ruby installation!'
    end
  end
  not_if do
    node[:pkg_build][:passenger][:allow_omnibus_chef_ruby]
  end
end

if(node[:pkg_build][:use_pkg_build_ruby])
  ruby_name = [node[:pkg_build][:pkg_prefix]]
  if(node[:pkg_build][:ruby][:suffix_version])
      ruby_name << "ruby#{node[:pkg_build][:ruby][:version]}"
  else
      ruby_name << 'ruby'
  end
  ruby_name = ruby_name.compact.join('-')
end

%w(libcurl4-gnutls-dev apache2 apache2-prefork-dev).each do |dep_pkg|
  package dep_pkg
end

libpassenger_name = [node[:pkg_build][:pkg_prefix], 'libapache2-mod-passenger'].compact.join('-')
passenger_gem_name = [node[:pkg_build][:pkg_prefix], 'rubygem-passenger'].compact.join('-')
gem_prefix = node[:pkg_build][:gems][:dir] || node[:languages][:ruby][:gems_dir]
pass_prefix = "gems/passenger-#{node[:pkg_build][:passenger][:version]}"
builder_dir "passenger-#{node[:pkg_build][:passenger][:version]}" do
  init_command "#{node[:pkg_build][:gems][:exec]} install --install-dir . --no-ri --no-rdoc --ignore-dependencies -E --version #{node[:pkg_build][:passenger][:version]} passenger"
  suffix_cwd "gems/passenger-#{node[:pkg_build][:passenger][:version]}"
  commands [
    "#{node[:pkg_build][:rake_bin]} apache2",
    'mkdir -p $PKG_DIR/libmod/etc/apache2/mods-available',
    "mkdir -p $PKG_DIR/libmod/#{node[:pkg_build][:passenger][:root]}/apache2/modules",
    "mkdir -p $PKG_DIR/libmod/#{node[:pkg_build][:passenger][:root]}/phusion-passenger",
    "cp ext/apache2/mod_passenger.so $PKG_DIR/libmod/#{node[:pkg_build][:passenger][:root]}/apache2/modules",
    "echo \"<IfModule mod_passenger.c>\\n  PassengerRoot #{node[:pkg_build][:gems][:dir]}/gems/passenger-#{node[:pkg_build][:passenger][:version]}\n  PassengerRuby #{node[:pkg_build][:ruby_bin]}\\n</IfModule>\\n\" > $PKG_DIR/libmod/etc/apache2/mods-available/passenger.conf",
    "echo \"LoadModule passenger_module #{node[:pkg_build][:passenger][:root]}/apache2/modules/mod_passenger.so\" > $PKG_DIR/libmod/etc/apache2/mods-available/passenger.load",
    "mkdir -p $PKG_DIR/gem/#{node[:pkg_build][:gems][:dir]}",
    "cp -a ../../gems $PKG_DIR/gem/#{node[:pkg_build][:gems][:dir]}",
    "cp -a ../../specifications $PKG_DIR/gem/#{node[:pkg_build][:gems][:dir]}",
    "cp -a ../../bin $PKG_DIR/gem/#{node[:pkg_build][:ruby_bin_dir]}",
  ]
end

fpm_tng_gemdeps 'passenger' do
  gem_package_name_prefix [node[:pkg_build][:pkg_prefix], 'rubygem'].compact.join('-')
  gem_gem node[:pkg_build][:gems][:exec]
  reprepro node[:pkg_build][:reprepro]
  version node[:pkg_build][:passenger][:version]
end

fpm_tng_package libpassenger_name do
  output_type 'deb'
  version node[:pkg_build][:passenger][:version]
  description 'Passenger apache module installation'
  chdir File.join(node[:builder][:packaging_dir], "passenger-#{node[:pkg_build][:passenger][:version]}", 'libmod')
  depends [
    'apache2', 'apache2-mpm-prefork', passenger_gem_name, node[:pkg_build][:passenger][:ruby_dependency]
  ].compact
  reprepro node[:pkg_build][:reprepro]
end

fpm_tng_package passenger_gem_name do
  output_type 'deb'
  version node[:pkg_build][:passenger][:version]
  description 'Passenger apache module installation'
  chdir File.join(node[:builder][:packaging_dir], "passenger-#{node[:pkg_build][:passenger][:version]}", 'gem')
  depends %w(fastthread daemon-controller rack).map{|x|[node[:pkg_build][:pkg_prefix], 'rubygem', x].compact.join('-') }
  reprepro node[:pkg_build][:reprepro]
end
