include ::Packager::Reactor::Core

action :build do
  args = Packager::Smash.new(new_resource.args)
  reactor do
    pkg_build_rails args[:build][:name] do
      package_name args[:build][:name]
      source args[:source][:location]
      ref args[:source][:reference]
      if(args[:configure] && args[:configure].is_a?(Hash))
        args[:configure].each do |k,v|
          self.send(k,v)
        end
      end
      dependencies args[:dependencies][:runtime]
      version args[:build][:version]
    end
  end
end
