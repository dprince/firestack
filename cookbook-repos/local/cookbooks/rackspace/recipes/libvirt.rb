package "libvirt0" do
  options "--force-yes"
  version node[:libvirt][:version]
  action :install
end

package "libvirt-bin" do
  options "--force-yes"
  version node[:libvirt][:version]
  action :install
end
