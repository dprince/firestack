OpenStack VPC
=============

Description
-----------

Create your own Openstack Virtual Private Cloud. Openstack VPC includes a set of rake tasks to:

 * Creates a group of servers (VPC, XenServer)

 * Build packages and create an RPM repo. (Fedora)

 * Install and configure packages on nodes (via Puppet).

 * Configure keystone data, load glance images, etc.

 * Run various test suites (Torpedo, Tempest, SmokeTests)

Useful for developmental and functional testing.

Requirements
------------

 -Kytoon: https://github.com/dprince/kytoon

For Cloud Servers VPC group types you'll also need a Cloud Servers VPC
API to hit. See this project for details:

 -Cloud Servers VPC: https://github.com/rackspace/cloud_servers_vpc

For XenServer you'll need a machine installed with XenServer 5.6+. See
notes in the Kytoon XenServer provider for the required setup.

Examples
--------

Available tasks:

	rake fedora:create_rpm_repo   # Create an RPM repo.
	rake fedora:fill_cache        # Upload packages to the cache URL.
	rake glance:build_packages    # Build Glance packages.
	rake glance:install_source    # Install local Glance source code into the g...
	rake group:create             # Create a new group of cloud servers
	rake group:delete             # Delete a cloud server group
	rake group:gateway_ip         # Print the VPN gateway IP address
	rake group:list               # List existing cloud server groups.
	rake group:show               # Print information for a cloud server group
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
rake group:create SERVER_GROUP_JSON="config/server_group_fedora.json"

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
See the example bash scripts in this directory for detailed examples using Cloud Servers VPC and XenServer.
