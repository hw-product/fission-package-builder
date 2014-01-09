include_recipe 'pkg-build::deps'

%w(
  openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev 
  libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev 
  autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config
).each do |r_dep|
  package r_dep
end

ruby_name = [node[:pkg_build][:pkg_prefix]]
if(node[:pkg_build][:ruby][:suffix_version])
  ruby_name << "ruby#{node[:pkg_build][:ruby][:version]}"
else
  ruby_name << 'ruby'
end

ruby_name = ruby_name.compact.join('-')
ruby_build = "#{ruby_name}-#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}"

builder_remote ruby_build do
  remote_file ::File.join(node[:pkg_build][:ruby][:uri_base], "ruby-#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}.tar.gz")
  suffix_cwd "ruby-#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}"
  commands [
    'autoconf',
    "./configure --prefix=#{node[:pkg_build][:ruby][:install_prefix]} --disable-install-doc --enable-shared --with-baseruby=#{RbConfig.ruby} --program-suffix=#{node[:pkg_build][:ruby][:version]}",
    "make",
    "make install DESTDIR=$PKG_DIR"
  ]
end

template File.join(node[:builder][:build_dir], ruby_build, 'postinst') do
  source 'ruby-postinst.erb'
  mode 0755
end

fpm_tng_package ruby_build do
  package_name ruby_name
  output_type 'deb'
  description "Ruby language - #{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}"
  version "#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}"
  chdir File.join(node[:builder][:packaging_dir], ruby_build)
  after_install File.join(node[:builder][:build_dir], ruby_build, 'postinst')
  depends %w(
    ca-certificates libc6 libffi6 libgdbm3 libncursesw5 libreadline6 libssl1.0.0 
    libtinfo5 libyaml-0-2 zlib1g
  )
  # provides - rake gem
  reprepro node[:pkg_build][:reprepro]
end

# TODO: If we get proper execution time attribute resolution, we can
#       make this work in a single converge. Until then, kill the run
#       and let it re-run so we are assured proper ruby bin is used
if(node[:pkg_build][:use_pkg_build_ruby])
  # TODO: Fix fpm notifications!
  execute 'refresh apt' do
    command 'apt-get update'
#    action :nothing
#    subscribes :run, "fpm_tng_package[#{ruby_name}]", :immediately
  end

  if(node[:pkg_build][:reprepro])
    service 'pkg-build-apache2' do
      action :nothing
      service_name 'apache2'
    end

    package ruby_name do
      action :upgrade
      notifies :restart, 'service[pkg-build-apache2]', :immediately
      notifies :create, 'ruby_block[New ruby kills chef run!]', :immediately
    end
  else
    execute 'install custom ruby' do
      command "dpkg -i #{
        File.join(
          node[:fpm_tng][:package_dir], 
          "#{ruby_build}-#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}.deb"
        )}"
#      action :nothing
#      subscribes :run, "fpm_tng_package[#{ruby_build}]", :immediately
      not_if do
        begin
          %x{ruby --version}.to_s.split(' ')[1] == "#{node[:pkg_build][:ruby][:version]}#{node[:pkg_build][:ruby][:patchlevel]}"
        rescue Errno::ENOENT
          false
        end
      end
      notifies :create, 'ruby_block[New ruby kills chef run!]', :immediately
    end
  end

  ruby_block 'New ruby kills chef run!' do
    action :nothing
    block do
      raise "New ruby installed (#{ruby_name})! Re-run chef so proper ruby is used"
    end
  end
end
