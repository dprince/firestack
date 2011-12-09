#!/bin/bash

USAGE="usage: $0 xenserver_ip nova_path keystone_path glance_path <nova_packager_url>'"

if [ $# -ne 4 ]; then
    echo $USAGE;
    exit 1;
fi

XENSERVER_IP="$1"
NOVA="$2"
KEYSTONE="$3"
GLANCE="$4"
XENSERVER_NAME="xen1"
CONFIG="config/node_json_configs/xen.json"

rake group:create
rake group:poll

# NOTE: we build packages right now because the PPA won't work on Cloud Servers
# There are a couple show stoppers:
#
# - libvirt 0.8.8 doesn't quite work: https://bugs.launchpad.net/bugs/790837
# - Additionally the init script for nova-compute modprobes 'nbd'
#
# Until we fix these issues building packages is required.
rake nova:build_packages SOURCE_DIR=$NOVA

rake nova:build_rpms SOURCE_DIR=$NOVA

rake keystone:build_packages SOURCE_DIR=$KEYSTONE

rake glance:build_packages SOURCE_DIR=$GLANCE

rake chef:push_repos
rake chef:install CONFIG=$CONFIG

rake xen:bootstrap XENSERVER_IP=$XENSERVER_IP SERVER_NAME=$XENSERVER_NAME

sleep 10

rake chef:install SERVER_NAME=$XENSERVER_NAME CONFIG=$CONFIG

rake chef:poll_clients SERVER_NAME=$XENSERVER_NAME

rake ssh bash <<-EOF_BASH
if ! grep -c "compute1.vpc" /etc/hosts &> /dev/null; then
echo "172.19.0.101     compute1.vpc compute1" >> /etc/hosts
fi
EOF_BASH

rake chef:install SERVER_NAME=compute1 CONFIG=$CONFIG

# NOTE: use full hostname here because nova-agent sets hostname as
# hostname.domain (will talk to Chris to see if we want to add this as
# an agent feature)

rake chef:poll_clients SERVER_NAME=compute1.vpc
