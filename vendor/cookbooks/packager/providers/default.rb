

action :run do
  node.set[:fpm_tng][:exec] = 'fpm'
  builder = lambda do |config|
    resource_type = "packager_#{config[:build][:template]}".to_sym
    self.send(resource_type, "#{config[:build][:name]}") do
      args config
    end
  end

  dep_builder = lambda do |opts|
    if(opts.retrieve(:dependencies, :package))
      opts[:dependencies][:package].each do |name, config|
        dep_config = config.merge(:target => opts[:target])
        dep_builder.call(dep_config)
      end
    end
    builder.call(opts)
  end

  dep_builder.call(::Packager.to_smash(new_resource.build))

end
