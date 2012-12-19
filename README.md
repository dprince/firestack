Firestack
=============

Description
-----------

A set of rake tasks to build packages and install OpenStack.

Features:
---------

 * Integrates with Kytoon to create groups of servers for installation.

 * Build packages and create a package repo.

 * Install and configure packages on nodes (via Puppet).

 * Tasks to configure keystone data, load glance images, etc.

 * Run various test suites (Torpedo, Tempest, Nova Smoke Tests)

Useful for developmental and functional testing.

Requirements
------------

 -Kytoon: https://github.com/dprince/kytoon

Tasks
-----

Available tasks:

	rake fedora:create_rpm_repo   # Create an RPM repo.
	rake fedora:fill_cache        # Upload packages to the cache URL.
	rake glance:build_packages    # Build Glance packages.
	rake glance:install_source    # Install local Glance source code into the g...
	rake kytoon:create             # Create a new group of cloud servers
	rake kytoon:delete             # Delete a cloud server group
	rake kytoon:gateway_ip         # Print the VPN gateway IP address
	rake kytoon:list               # List existing cloud server groups.
	rake kytoon:show               # Print information for a cloud server group
	rake keystone:build_packages  # Build Keystone packages.
	rake keystone:configure       # Configure keystone
	rake nova:build_packages      # Build Nova packages.
	rake nova:install_source      # Install local Nova source code into the group.
	rake nova:smoke_tests         # Run the nova smoke tests.
	rake nova:tail_logs           # Tail nova logs.
	rake puppet:install           # Install and configure packages on clients w...
	rake ssh                      # SSH into the most recently created VPN gate...
	rake stackattack:install      # Install stack attack and dependencies on SE...
	rake swift:build_packages     # Build Swift packages.
	rake tail_logs                # Tail nova, glance, keystone logs.
	rake tempest                  # Install and run Tempest.
	rake torpedo                  # Install and run Torpedo: Fast Openstack tests
	rake usage                    # Print help and usage information
	rake xen:install_plugins      # Install plugins into the XenServer dom0.



## Quickstart on Fedora 17 and RHEL 6

```bash
# Before using Firestack w/ Libvirt you need to have an image and a libvirt
# XML dom file on disk that will be used to clone new VM's for each 
# Firestack group.
LIBVIRT_XML_FILE=/path/to/libvirt/dom/xml

set -x

# install rubygems, rubygem-json, and Git, make, gcc, etc
for X in rubygems ruby-devel rubygem-bundler git make gcc; do
  rpm -q $X &> /dev/null || yum install -q -y $X
done

# Some older RHEL/Fedora distro don't have a bundler package
if ! gem list | grep bundler &> /dev/null; then
  gem install --no-rdoc --no-ri bundler
fi

git clone git://github.com/dprince/firestack.git
cd firestack
bundle install

# Configure the server group XML for Kytoon
cat >> config/server_group_libvirt.json <<EOF_CAT
{
    "name": "Fedora",
    "servers": [
	{
	    "hostname": "nova1",
	    "memory": "4",
	    "gateway": "true",
	    "original_xml": "$LIBVIRT_XML_FILE",
	    "create_cow": "true"
	}
    ]
}
EOF_CAT

# Configure kytoon.conf
# NOTE: This config assumes you have configured libvirt to run with your
# username. Alternately you can have Kytoon use sudo via the libvirt_use_sudo.
#
# See this puppet module if you are interested in quickly configuring worker
# nodes to allow a 'smokestack' user to make use of libvirt:
# https://github.com/dprince/smokestack-puppet/blob/master/modules/smokestack/manifests/libvirt.pp
cat >> ~/.kytoon.conf <<EOF_CAT
# The default group type.
# Set to one of: openstack, libvirt, xenserver
group_type: libvirt

# Libvirt settings
# Whether commands to create local group should use sudo
libvirt_use_sudo: False
EOF_CAT

# Generate an ssh keypair if you don't already have one
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ""
fi

# Now you are ready to run the example_libvirt.bash
# From here on out just run this directly!
bash example_libvirt.bash
```

Example Commands
----------------

Typically you'll want to create a runner script that creates a new group, builds packages, installs them, etc. See example_libvirt.bash as an example. The following commands are commonly used:

```bash
#create a group
rake kytoon:create SERVER_GROUP_JSON="config/server_group_fedora.json"

#build Nova packages
rake nova:build_packages \
    RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-nova.git" \
    SOURCE_URL="git://github.com/openstack/nova.git" \
    SOURCE_BRANCH="master"

#create an RPM repo
rake fedora:create_rpm_repo

#install/configure packages with Puppet
rake puppet:install SOURCE_URL="git://github.com/fedora-openstack/openstack-puppet.git" PUPPET_CONFIG="single_node_mysql"

#configure keystone
rake keystone:configure

#load glance images
rake glance:load_images

#Run test suites
rake torpedo
rake tempest

```

See the example bash script in this directory for detailed example using libvirt.
