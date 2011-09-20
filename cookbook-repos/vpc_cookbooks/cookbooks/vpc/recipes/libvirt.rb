# Downgrade libvirt
libvirt_version=node[:vpc][:libvirt][:version]
execute "apt-get -y --force-yes install libvirt0=#{libvirt_version} libvirt-bin=#{libvirt_version} python-libvirt=#{libvirt_version}" do
  not_if "dpkg -l libvirt-bin | grep #{libvirt_version}"
end
