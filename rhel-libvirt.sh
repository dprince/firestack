export DISTRO_NAME=rhel

export GROUP_TYPE=libvirt

# uncomment to create and provision VM
rake kytoon:create GROUP_CONFIG="config/server_group_rhel.json"
rake rhel:provision_vm

rake nova:build_packages \
	SOURCE_URL="git://github.com/openstack/nova.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-nova.git" \
        RPM_PACKAGER_BRANCH="el6"

rake glance:build_packages \
	SOURCE_URL="git://github.com/openstack/glance.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-glance.git" \
        RPM_PACKAGER_BRANCH="el6"

rake swift:build_packages \
	SOURCE_URL="git://github.com/openstack/swift.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-swift.git" \
        RPM_PACKAGER_BRANCH="el6"

rake keystone:build_packages \
        SOURCE_URL="git://github.com/openstack/keystone.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-keystone.git" \
        RPM_PACKAGER_BRANCH="el6"

rake cinder:build_packages \
	SOURCE_URL="git://github.com/openstack/cinder.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-cinder.git" \
        RPM_PACKAGER_BRANCH="el6"

rake quantum:build_packages \
	SOURCE_URL="git://github.com/openstack/quantum.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-quantum.git" \
        RPM_PACKAGER_BRANCH="el6"

rake nova:build_python_novaclient \
	SOURCE_URL="git://github.com/openstack/python-novaclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-novaclient.git" \
	RPM_PACKAGER_BRANCH="el6"

rake glance:build_python_glanceclient \
	SOURCE_URL="git://github.com/openstack/python-glanceclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-glanceclient.git" \
        RPM_PACKAGER_BRANCH="el6"

rake keystone:build_python_keystoneclient \
	SOURCE_URL="git://github.com/openstack/python-keystoneclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-keystoneclient.git" \
        RPM_PACKAGER_BRANCH="el6"

rake cinder:build_python_cinderclient \
	SOURCE_URL="git://github.com/openstack/python-cinderclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-cinderclient.git" \
        RPM_PACKAGER_BRANCH="el6"

rake swift:build_python_swiftclient \
	SOURCE_URL="git://github.com/openstack/python-swiftclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-swiftclient.git" \
        RPM_PACKAGER_BRANCH="el6"

rake quantum:build_python_quantumclient \
	SOURCE_URL="git://github.com/openstack/python-quantumclient.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-quantumclient.git" \
        RPM_PACKAGER_BRANCH="el6"

rake oslo_config:build_packages \
	SOURCE_URL="git://github.com/openstack/oslo-config.git" \
	SOURCE_BRANCH="master" \
        RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-python-oslo-config.git" \
        RPM_PACKAGER_BRANCH="el6"

# hook to build distro specific packages
rake build_misc

rake rhel:create_rpm_repo

rake puppet:install \
        SOURCE_URL="git://github.com/nunofsantos/openstack-puppet.git" \
        SOURCE_BRANCH="master" \
        PUPPET_CONFIG="single_node_mysql"

rake keystone:configure

#rake glance:load_images
# Uncomment to configure quantum
#
#rake quantum:configure
#rake torpedo
