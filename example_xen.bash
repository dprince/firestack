export GROUP_TYPE=xenserver
export DISTRO_NAME=fedora

rake kytoon:create GROUP_CONFIG="config/server_group_xen.json" GATEWAY_IP="<YOUR XENSERVER IP GOES HERE>"

rake nova:build_packages \
	SOURCE_URL="git://github.com/openstack/nova.git" \
	SOURCE_BRANCH="master" GIT_MERGE="master"

rake glance:build_packages \
	SOURCE_URL="git://github.com/openstack/glance.git" \
	SOURCE_BRANCH="master" GIT_MERGE="master"

rake swift:build_packages \
	SOURCE_URL="git://github.com/openstack/swift.git" \
	SOURCE_BRANCH="master" GIT_MERGE="master"

rake keystone:build_packages \
        SOURCE_URL="git://github.com/openstack/keystone.git" \
	SOURCE_BRANCH="master" GIT_MERGE="master"

rake cinder:build_packages \
	SOURCE_URL="git://github.com/openstack/cinder.git" \
	SOURCE_BRANCH="master" GIT_MERGE="master"

rake quantum:build_packages \
        SOURCE_URL="git://github.com/openstack/quantum.git" \
        SOURCE_BRANCH="master" GIT_MERGE="master"


rake build_misc

rake nova:build_python_novaclient \
	SOURCE_URL="git://github.com/openstack/python-novaclient.git"

rake glance:build_python_glanceclient \
	SOURCE_URL="git://github.com/openstack/python-glanceclient.git"

rake keystone:build_python_keystoneclient \
	SOURCE_URL="git://github.com/openstack/python-keystoneclient.git"

rake cinder:build_python_cinderclient \
	SOURCE_URL="git://github.com/openstack/python-cinderclient.git"

rake swift:build_python_swiftclient \
	SOURCE_URL="git://github.com/openstack/python-swiftclient.git"

rake quantum:build_python_quantumclient \
        SOURCE_URL="git://github.com/openstack/python-quantumclient.git"

rake fedora:create_rpm_repo

# Copy hosts file to each node
rake ssh bash <<-"EOF_COPY_HOSTS"
for IP in $(cat /etc/hosts | cut -f 1); do
[[ "$IP" != "127.0.0.1" ]] && scp /etc/hosts $IP:/etc/hosts
done
EOF_COPY_HOSTS

rake fedora:create_rpm_repo
rake xen:install_plugins SOURCE_URL="git://github.com/openstack/nova.git"

CONFIGURATION="xen_mysql_rabbit_swift"

# FIXME: need to figure out how to make xenbr1 a XenServer management
# interface.
# For now we replace XENAPI_CONNECTION_URL with the IP of xenbr0
XENBR0_IP=$(rake ssh 'ip a | grep xenbr0 | grep inet | sed -e "s|.*inet \([^/]*\).*|\1|"')
sed -e "s|XENAPI_CONNECTION_URL|http://$XENBR0_IP|g" -i config/puppet-configs/$CONFIGURATION/nova1.pp

unset SERVER_NAME
rake puppet:install SOURCE_URL="git://github.com/fedora-openstack/openstack-puppet.git" PUPPET_CONFIG="$CONFIGURATION"

#reserve the first 5 IPs for the server group
rake ssh bash <<-"EOF_RESERVE_IPS"
ssh nova1 bash <<-"EOF_NOVA1"
for NUM in {0..5}; do
nova-manage fixed reserve 192.168.0.$NUM
done
EOF_NOVA1
EOF_RESERVE_IPS

rake keystone:configure SERVER_NAME=nova1
rake glance:load_images_xen SERVER_NAME=nova1
