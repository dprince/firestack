GROUP_TYPE=xenserver
# GATEWAY_IP points to your XenServer machine
rake group:create SERVER_GROUP_JSON="config/server_group_xen.json" GATEWAY_IP="123.123.123.123"

rake nova:build_packages \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-nova.git" \
        SOURCE_URL="git://github.com/openstack/nova.git" \
        SOURCE_BRANCH="master" GIT_MERGE="master"

rake glance:build_packages \
	RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-glance.git" \
	SOURCE_URL="git://github.com/openstack/glance.git" \
	jOURCE_BRANCH="master" 

#rake swift:build_packages \
	#RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-swift.git" \
	#SOURCE_URL="git://github.com/openstack/swift.git" \
	#SOURCE_BRANCH="master" 

rake keystone:build_packages \
	RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-keystone.git" \
        SOURCE_URL="git://github.com/openstack/keystone.git" \
        SOURCE_BRANCH="master"

rake keystone:build_python_keystoneclient SOURCE_URL="git://github.com/openstack/python-keystoneclient.git" RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-keystoneclient.git"

rake nova:build_python_novaclient SOURCE_URL="git://github.com/openstack/python-novaclient.git" RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-novaclient.git"

#rake swift:build_python_swiftclient SOURCE_URL="git://github.com/openstack/python-swiftclient.git" RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-swiftclient.git"

# Copy hosts file to each node
rake ssh bash <<-"EOF_COPY_HOSTS"
for IP in $(cat /etc/hosts | cut -f 1); do
[[ "$IP" != "127.0.0.1" ]] && scp /etc/hosts $IP:/etc/hosts
done
EOF_COPY_HOSTS

rake fedora:create_rpm_repo
rake xen:install_plugins SOURCE_URL="git://github.com/openstack/nova.git"
rake puppet:install SOURCE_URL="git://github.com/fedora-openstack/openstack-puppet.git" PUPPET_CONFIG="xen_mysql"

rake keystone:configure
rake glance:load_images_xen

#reserve the first 5 IPs for the server group
rake ssh bash <<-"EOF_RESERVE_IPS"
ssh nova1 bash <<-"EOF_NOVA1"
for NUM in {0..5}; do
nova-manage fixed reserve 192.168.0.$NUM
done
EOF_NOVA1
EOF_RESERVE_IPS

#rake torpedo MODE=xen
