namespace :quantum do

    desc "Build Quantum packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_quantum"].invoke
    end

    desc "Build Python Quantumclient packages."
    task :build_python_quantumclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_quantumclient"].invoke
    end

    desc "Configure a sample Quantum network."
    task :configure do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        floating_range=ENV['FLOATING_RANGE'] || "172.20.0.0/24"
        fixed_range=ENV['FIXED_RANGE'] || "192.168.0.0/24"
        network_gateway=ENV['NETWORK_GATEWAY'] || "192.168.0.1"
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
  [ -f /root/openstackrc ] && source /root/openstackrc
function get_field() {
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\\$(NF$1))"
        else
            field="\\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \\t]*\\\\|[ \\t]*' "{print $field}"
    done
}

set -x
export EDITOR=vim
FLOATING_RANGE="#{floating_range}"
FIXED_RANGE="#{fixed_range}"
NETWORK_GATEWAY="#{network_gateway}"

TENANT_ID=$(keystone tenant-list | grep " user1 " | get_field 1)

# Create a small network
# Since quantum command is executed in admin context at this point,
# ``--tenant_id`` needs to be specified.
NET_ID=$(quantum net-create --tenant_id $TENANT_ID net1 | grep ' id ' | get_field 2)
SUBNET_ID=$(quantum subnet-create --tenant_id $TENANT_ID --ip_version 4 --gateway $NETWORK_GATEWAY $NET_ID $FIXED_RANGE | grep ' id ' | get_field 2)
# Create a router, and add the private subnet as one of its interfaces
ROUTER_ID=$(quantum router-create --tenant_id $TENANT_ID router1 | grep ' id ' | get_field 2)
quantum router-interface-add $ROUTER_ID $SUBNET_ID
# Create an external network, and a subnet. Configure the external network as router gw
EXT_NET_ID=$(quantum net-create ext_net -- --router:external=True | grep ' id ' | get_field 2)
EXT_GW_IP=$(quantum subnet-create --ip_version 4 $EXT_NET_ID $FLOATING_RANGE -- --enable_dhcp=False | grep 'gateway_ip' | get_field 2)
quantum router-gateway-set $ROUTER_ID $EXT_NET_ID
#if [[ "$Q_PLUGIN" = "openvswitch" ]]; then
    #CIDR_LEN=${FLOATING_RANGE#*/}
    #ip addr add $EXT_GW_IP/$CIDR_LEN dev $PUBLIC_BRIDGE
    #ip link set $PUBLIC_BRIDGE up
#fi
EOF_SERVER_NAME

        } do |ok, out|
            puts out
            fail "Failed to configure networking!" unless ok
        end
    end

end
