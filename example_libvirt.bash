export GROUP_TYPE=libvirt
rake kytoon:create GROUP_CONFIG="config/server_group_libvirt.json"

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

rake nova:build_python_novaclient \
	SOURCE_URL="git://github.com/openstack/python-novaclient.git"

rake glance:build_python_warlock
rake fedora:build_python_prettytable

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

rake puppet:install SOURCE_URL="git://github.com/fedora-openstack/openstack-puppet.git" PUPPET_CONFIG="single_node_mysql"

rake keystone:configure
rake glance:load_images
# Uncomment to configure quantum
#
#rake quantum:configure
rake torpedo
