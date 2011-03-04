# This recipe contains setup steps required for Nova Compute to work
# correctly on our Stock Ubuntu Cloud Servers images

# NOTE: (dprince) Inside of our VPC environments we already have a virbr0
# bridge interface so we can use that

#package "bridge-utils"
#execute "brctl addbr br100" do
  #not_if "brctl show | grep br100"
#end

directory "/dev/cgroup" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

execute "mount -t cgroup none /dev/cgroup -o devices" do
  not_if "mount | grep cgroup"
end

execute "apt-get -y --force-yes install libvirt0=#{node[:libvirt][:version]} libvirt-bin=#{node[:libvirt][:version]} python-libvirt=#{node[:libvirt][:version]}" do
  not_if "dpkg -l libvirt-bin | grep #{node[:libvirt][:version]}"
end

service "libvirt-bin"

cookbook_file "/etc/libvirt/qemu.conf" do
  source "qemu.conf"
  mode "0644"
  notifies :restart, resources(:service => "libvirt-bin")
end
