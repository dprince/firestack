default[:vpc][:apt][:distro] = "maverick"
default[:vpc][:apt][:nova_ppa_url] = "http://ppa.launchpad.net/nova-core/trunk/ubuntu"
default[:vpc][:apt][:glance_ppa_url] = "http://ppa.launchpad.net/glance-core/trunk/ubuntu"
default[:vpc][:apt][:local_url] = "http://login.vpc/apt/openstack"

#set[:vpc][:apt][:ubuntu_mirror] = "archive.ubuntu.com"
set[:vpc][:apt][:ubuntu_mirror] = "mirror.rackspace.com"
