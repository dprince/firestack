export GROUP_TYPE=libvirt
export DISTRO_NAME=fedora
rake kytoon:create GROUP_CONFIG="config/server_group_libvirt.json"

rake build_misc
rake build:packages # see config/packages

# required for Torpedo
rake fog:build_packages
rake torpedo:build_packages

rake create_package_repo

rake puppet:install SOURCE_URL="git://github.com/redhat-openstack/openstack-puppet.git" PUPPET_CONFIG="single_node_mysql"

rake keystone:configure
rake glance:load_images
# Uncomment to configure quantum
#
#rake quantum:configure

export TORPEDO_SERVER_BUILD_TIMEOUT=180
export TORPEDO_SSH_TIMEOUT=120
export TORPEDO_PING_TIMEOUT=60
export TORPEDO_TEST_REBUILD_SERVER=true
export TORPEDO_FLAVOR_REF=1
export TORPEDO_IMAGE_NAME="ami-tty"
rake torpedo
