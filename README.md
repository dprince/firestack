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

Examples
--------

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


```bash

#create a group
rake kytoon:create SERVER_GROUP_JSON="config/server_group_fedora.json"

#build Nova packages
rake nova:build_packages \
    RPM_PACKAGER_URL="git://github.com/fedora-openstack/openstack-nova.git" \
    SOURCE_URL="git://github.com/openstack/nova.git" \
    SOURCE_BRANCH="master" GIT_MERGE="master"

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
See the example bash scripts in this directory for detailed examples using libvirt and XenServer kytoon providers.
