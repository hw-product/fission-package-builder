# Force world readable to allow easier inspection on completion
file '/var/log/chef/client.log' do
  mode 0644
  only_if do
    File.exists?('/var/log/chef/client.log')
  end
end

include_recipe 'apt'
include_recipe 'builder'
include_recipe 'fpm-tng'

packager 'build the world' do
  build node[:packager][:build]
end
