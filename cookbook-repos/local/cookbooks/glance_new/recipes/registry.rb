#
# Cookbook Name:: glance
# Recipe:: registry
#
#

include_recipe "#{@cookbook_name}::common"

glance_service "registry" do
  opts ({"sql-connection" => node[:glance][:sql_connection]})
end
