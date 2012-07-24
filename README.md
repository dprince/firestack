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
