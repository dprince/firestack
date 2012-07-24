export GROUP_TYPE=cloud_server_vpc
rake group:create SERVER_GROUP_JSON="config/server_group_fedora.json"

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

rake fedora:create_rpm_repo

rake puppet:install SOURCE_URL="git://github.com/fedora-openstack/openstack-puppet.git" PUPPET_CONFIG="single_node_mysql"

rake keystone:configure
rake glance:load_images
rake torpedo
