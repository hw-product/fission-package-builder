include ::Packager::Reactor::Core

action :build do
  args = Packager::Smash.new(new_resource.args)
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
      output_type args[:target][:package]
      depends args[:dependencies][:runtime]
      version args[:build][:version] || node[:packager][:environment]['PACKAGER_VERSION']
      chdir lazy{ node[:builder][:builds][args[:build][:name]][:packaging_path] }
    end
  end
end
