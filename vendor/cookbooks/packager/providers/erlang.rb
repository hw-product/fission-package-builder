include ::Packager::Reactor::Core

action :build do
  args = new_resource.args
  args[:source] ||= {}
  default_erlang_build!(args)

  node.set[:erlang][:install_method] = 'esl'
  run_context.include_recipe 'erlang'

  reactor do
    builder args[:build][:name] do
      if(args[:target_store])
        init_command "cp -R #{::File.join(args[:target_store], '*')} ."
      end
      args[:source].each do |k,v|
        self.send(k,v)
      end
      commands args[:build][:commands][:build]
      creates '/tmp/always/be/building'
    end

    fpm_tng_package args[:build][:name] do
      output_type args[:target][:package]
      depends args[:dependencies][:runtime] unless [args[:dependencies][:runtime]].flatten.compact.empty?
      version args[:build][:version]
      chdir lazy{ node[:builder][:builds][args[:build][:name]][:packaging_path] }
    end
  end
end

def default_erlang_build!(args)
  [:build, :commands, :build].inject(args) do |key|
    args[key] ||= Mash.new
  end
  install_prefix = args[:build][:install_prefix] || ::File.join('/opt', args[:build][:name])
  args[:build][:commands] ||= Mash.new
  args[:build][:commands][:build] = [
    './rebar delete-deps',
    './rebar clean',
    './rebar get-deps',
    './rebar compile',
    'cd rel && ../rebar generate',
    "mkdir -p $PKG_DIR/#{install_prefix}",
    "mv rel/* $PKG_DIR/#{install_prefix}/"
  ]
end
