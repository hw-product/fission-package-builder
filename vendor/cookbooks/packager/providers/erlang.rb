include ::Packager::Reactor::Core

action :build do

  args = Smash.new(new_resource.args)
  args[:source] ||= {}
  default_erlang_build!(args)

  node.set[:erlang][:install_method] = 'esl'
  run_context.include_recipe 'erlang'

  rebar_url = args[:build].fetch(:rebar_base_url, new_resource.rebar_base_url)
  rebar_version = args[:build].fetch(:rebar_version, new_resource.rebar_version)
  rebar_src_dir = '/usr/src/rebar'
  rebar_directory = ::File.join(rebar_src_dir, "rebar-#{rebar_version}")


  rebar_remote_location = ::File.join(rebar_url, rebar_version)
  rebar_asset_path = ::File.join(
    Chef::Config[:file_cache_path],
    ::File.basename(rebar_remote_location)
  )
  rebar_remote_location << '.tar.gz'

  # add rebar install
  remote_file rebar_asset_path do
    source rebar_remote_location
  end

  directory rebar_src_dir do
    recursive true
  end

  execute 'rebar unpack' do
    command "tar xvf #{rebar_asset_path}"
    cwd rebar_src_dir
    not_if do
      ::File.exists?(::File.join(rebar_directory, 'rebar'))
    end
  end

  execute 'build rebar' do
    command './bootstrap'
    cwd rebar_directory
    not_if do
      ::File.exists?(::File.join(rebar_directory, 'rebar'))
    end
  end

  link 'rebar bin link' do
    target_file '/usr/bin/rebar'
    to ::File.join(rebar_directory, 'rebar')
  end

  builds = []

  if(args[:build][:reloader])
    builds.push(:base) if args[:build][:reloader][:package] != 'only'
    builds.push(:reload)
  else
    builds << :base
  end

  builds.each do |build_type|

    if(build_type == :reload)
      set_reload!(args)
      resource_name = "#{args[:build][:name]}_reloader"
    else
      resource_name = args[:build][:name]
    end

    reactor do
      builder resource_name do
        if(args[:target_store])
          init_command "cp -R #{::File.join(args[:target_store], '*')} ."
        end
        args[:source].each do |k,v|
          self.send(k,v)
        end
        commands args[:build][:commands][:build].dup
        environment node[:packager][:environment].dup
        creates '/tmp/always/be/building'
      end

      fpm_tng_package resource_name do
        package_name args[:build][:name]
        output_type args[:target][:package]
        depends args[:dependencies][:runtime] unless [args[:dependencies][:runtime]].flatten.compact.empty?
        version args[:build][:version]
        chdir ::File.join(node[:builder][:packaging_dir], resource_name)
      end
    end

  end

end

def set_reload!(args)
  args[:build][:version] = "#{args[:build][:version]}-upgrade#{args[:build][:reloader][:from]}"
  install_prefix = args[:build][:install_prefix] || ::File.join('/opt', args[:build][:name])
  gen_prefix = "cd #{args[:build][:generate_cwd]}" if args[:build][:generate_cwd]
  args[:build][:commands][:build] = [
    'rebar delete-deps',
    'rebar clean',
    'rebar get-deps',
    'rebar compile',
    "rm -rf rel/$PACKAGER_NAME*",
    [gen_prefix, 'rebar generate'].compact.join(' && '),
    "mkdir -p rel/$PACKAGER_NAME-#{args[:build][:reloader][:from]}",
    "mkdir -p /tmp/$PACKAGER_NAME-#{args[:build][:reloader][:from]}",
    "dpkg-deb -x $PACKAGER_HISTORY_DIR/$PACKAGER_NAME-#{args[:build][:reloader][:from]}.$PACKAGER_TYPE /tmp/$PACKAGER_NAME-#{args[:build][:reloader][:from]}",
    "cp -R /tmp/$PACKAGER_NAME-#{args[:build][:reloader][:from]}/$PACKAGER_INSTALL_PREFIX/* rel/$PACKAGER_NAME-#{args[:build][:reloader][:from]}/",
    [gen_prefix, "rebar generate-appups previous_release=$PACKAGER_NAME-#{args[:build][:reloader][:from]}"].compact.join(' && '),
    [gen_prefix, "rebar generate-upgrade previous_release=$PACKAGER_NAME-#{args[:build][:reloader][:from]}"].compact.join(' && '),
    "mkdir -p $PKG_DIR/#{install_prefix}",
    "dpkg-deb -x $PACKAGER_HISTORY_DIR/$PACKAGER_NAME-#{args[:build][:reloader][:from]}.$PACKAGER_TYPE $PKG_DIR",
    "tar -C $PKG_DIR/#{install_prefix} -zxf rel/${PACKAGER_NAME}_${PACKAGER_VERSION}.tar.gz"
  ]
end

def default_erlang_build!(args)
  [:build, :commands].inject(args) do |memo, key|
    memo[key] ||= Mash.new
  end
  gen_prefix = "cd #{args[:build][:generate_cwd]}" if args[:build][:generate_cwd]
  install_prefix = args[:build][:install_prefix] || ::File.join('/opt', args[:build][:name])
  unless(args[:build][:commands][:build])
    args[:build][:commands][:build] = [
      'rebar delete-deps',
      'rebar clean',
      'rebar get-deps',
      'rebar compile',
      [gen_prefix, 'rebar generate'].compact.join(' && '),
      "mkdir -p $PKG_DIR/#{install_prefix}",
      "mv rel/$PACKAGER_NAME/* $PKG_DIR/#{install_prefix}/"
    ]
  end

  if(args[:build][:reloader])
    latest = [args[:build][:history][:versions]].flatten.compact.uniq.sort do |x,y|
      Gem::Version.new(x) <=> Gem::Version.new(y)
    end.last
    case args[:build][:reloader]
    when TrueClass
      args[:build][:reloader] = Mash.new(
        :package => 'both', :from => latest
      )
    when Hash
      args[:build][:reloader][:package] ||= 'both'
      args[:build][:reloader][:from] ||= latest
    else
      raise TypeError.new("Unable to process provided reloader type. Expecting Hash. Got: #{args[:build][:reloader].class}")
    end
    # Test that we have seed package in history
    unless(::File.exists?(::File.join(node[:packager][:build][:history_directory], "#{args[:build][:name]}-#{args[:build][:reloader][:from]}.#{args[:target][:package]}")))
      # TODO: Log here
      args[:build][:reloader] = false
    end
  end
end
