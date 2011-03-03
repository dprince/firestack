package "libvirt-bin" do
  options "--force-yes"
  version node[:libvirt][:version]
  action :install
end
