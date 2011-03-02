#
# Cookbook Name:: glance
# Recipe:: api
#
#

include_recipe "#{@cookbook_name}::common"

glance_service "api" do
  opts({
    "host" => node[:glance][:host],
    "port" => node[:glance][:port],
    "registry-host" => node[:glance][:registry_host],
    "registry-port" => node[:glance][:registry_port],
    "log-dir" => node[:glance][:log_dir],
    "default-store" => node[:glance][:default_store],
    "filesystem-store-datadir" => node[:glance][:filesystem_store_datadir]
  })
end
