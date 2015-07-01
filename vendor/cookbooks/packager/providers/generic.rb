include ::Packager::Reactor::Core

action :build do
  args = Smash.new(new_resource.args)
  args[:source] ||= {}
  reactor do
    builder args[:build][:name] do
      if(args[:target_store])
        init_command "cp -R #{::File.join(args[:target_store], '*')} ."
      end
      args[:source].each do |k,v|
        self.send(k,v)
      end
      environment node[:packager][:environment].merge(args[:build][:environment] || {}).merge('PACKAGER_PKG_DIR' => '$PKG_DIR')
      commands args[:build][:commands][:build]
      creates '/tmp/always/build'
    end

    fpm_tng_package args[:build][:name] do
      args.fetch(:packaging, {}).each do |p_key, p_val|
        self.send(p_key, p_val)
      end
      output_type args[:target][:package]
      if(args[:dependencies][:runtime])
        depends args[:dependencies][:runtime]
      end
      version args[:build].fetch(:version, node[:packager][:environment]['PACKAGER_VERSION'])
      chdir lazy{ node[:builder][:builds][args[:build][:name]][:packaging_path] }
    end
  end
end
