include_recipe 'pkg-build::deps'

redis_name = [node[:pkg_build][:pkg_prefix], 'redis', node[:pkg_build][:redis][:version]].compact.join('-')

builder_remote redis_name do
  remote_file "http://redis.googlecode.com/files/redis-#{node[:pkg_build][:redis][:version]}.tar.gz"
  suffix_cwd "redis-#{node[:pkg_build][:redis][:version]}"
  commands [
    'make',
    'make PREFIX=$PKG_DIR/usr/local install',
    'mkdir -p $PKG_DIR/var/lib/redis',
    'mkdir -p $PKG_DIR/var/log/redis',
    'mkdir -p $PKG_DIR/etc/redis',
    'mkdir -p $PKG_DIR/etc/init.d',
  ]
  creates File.join(node[:builder][:build_dir], redis_name, redis_name, 'src/redis.o')
end

template File.join(node[:builder][:build_dir], redis_name, 'preinst') do
  source 'redis/preinst.erb'
  mode 0755
end

template File.join(node[:builder][:build_dir], redis_name, 'postinst') do
  source 'redis/postinst.erb'
  mode 0755
end

template File.join(node[:builder][:packaging_dir], redis_name, 'etc/init.d/redis-server') do
  source 'redis/redis-server.erb'
  mode 0755
end


fpm_tng_package [node[:pkg_build][:pkg_prefix], 'redis-server'].compact.join('-') do
  output_type 'deb'
  description 'Redis search'
  depends %w(libc6 adduser)
  after_install File.join(node[:builder][:build_dir], redis_name, 'postinst')
  before_install File.join(node[:builder][:build_dir], redis_name, 'preinst')
  version node[:pkg_build][:redis][:version]
  chdir File.join(node[:builder][:packaging_dir], redis_name)
  reprepro node[:pkg_build][:reprepro]
end
