include_recipe 'pkg-build'

versions = node[:pkg_build][:ruby][:versions].dup
if(node[:pkg_build][:ruby][:version])
  versions << "#{node[:pkg_build][:ruby][:version]}-#{node[:pkg_build][:ruby][:patchlevel]}"
end
versions.uniq!
comparable_versions = []

versions.uniq.each do |r_ver|
  version, patchlevel = r_ver.split('-')
  comparable_versions << [Gem::Version.new(version), patchlevel.nil? ? nil : patchlevel.to_s[1,patchlevel.length].to_i]
  
  if(node[:pkg_build][:isolate])
    pkg_build_isolate ['ruby', version, patchlevel].compact.join('-') do
      container 'ubuntu_1204'
      attributes(
        :pkg_build => {
          :ruby => {
            :version => version,
            :patchlevel => patchlevel,
            :suffix_version => node[:pkg_build][:ruby][:suffix_version],
            :replace_deprecated => node[:pkg_build][:ruby][:replace_deprecated],
            :extra_configure_args => node[:pkg_build][:ruby][:extra_configure_args],
          }
        }
      )
      run_list %w(recipe[pkg-build::ruby])
      not_if do
        ruby_build = PkgBuild::Ruby.ruby_build(node, version, patchlevel)
        File.exists?(File.join(node[:fpm_tng][:package_dir], "#{ruby_build}.deb"))
      end
    end
  else
    include_recipe 'pkg-build::deps'
    build_ruby r_ver do
      version version
      patchlevel patchlevel
      if(node[:pkg_build][:repository])
        repository node[:pkg_build][:repository]
      end
    end
  end
end

if(node[:pkg_build][:isolate])
  Chef::Log.info 'Building custom Ruby containers'
  grouped_v = comparable_versions.group_by{|v| v.first}
  grouped_v.each do |version, comps|
    install_version = comps.sort do |a,b|
      unless(a.first == b.first)
        a.first <=> b.first
      else
        a.last <=> b.last
      end
    end.last
    ruby_build = PkgBuild::Ruby.ruby_build(node, install_version.first.version, install_version.last)
    ruby_dpkg = File.join(node[:fpm_tng][:package_dir], "#{ruby_build}.deb")

    commands = ["dpkg -i #{ruby_dpkg}; apt-get -f -q -y install", "gem install --no-ri --no-rdoc rubygems-update"]
    if (node[:pkg_build][:ruby][:rubygems][:version] == 'latest')
      commands << "gem update --system"
    else
      commands << "gem update --system #{node[:pkg_build][:ruby][:rubygems][:version]}"
    end
    commands << "gem install --no-ri --no-rdoc fpm"

    node[:pkg_build][:isolated_containers].each do |name, opts|
      lxc_container "#{name}-ruby#{version.version}" do
        action :create
        clone name
        default_fstab false
        initialize_commands commands
      end
    end
  end
end
