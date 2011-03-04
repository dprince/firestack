# NOTE: I manually reimplented the nova-compute startup here so that it
# works on stock cloud servers. This works around the fact that stock
# Ubuntu Cloud Servers images don't have the 'nbd' (network block device)
# kernel module.

include_recipe "nova::common"

package "nova-compute" do
  options "--force-yes"
  action :install
end

cookbook_file "/etc/init/nova-compute.conf" do
  source "nova-compute.conf"
  mode "0644"
end

service "nova-compute" do
  restart_command "restart nova-compute"
  stop_command "stop nova-compute"
  start_command "start nova-compute"
  status_command "status nova-compute | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
  supports :status => true, :restart => true
  action :start
  subscribes :restart, resources(:template => "/etc/nova/nova.conf")
end
