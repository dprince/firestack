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

export EDITOR=vim
FLOATING_RANGE="#{floating_range}"
FIXED_RANGE="#{fixed_range}"
NETWORK_GATEWAY="#{network_gateway}"

NET_ID=$(quantum net-create public --shared | grep ' id ' | get_field 2)
SUBNET_ID=$(quantum subnet-create --ip_version 4 --gateway $NETWORK_GATEWAY $NET_ID $FIXED_RANGE | grep ' id ' | get_field 2)
ROUTER_ID=$(quantum router-create router1 | grep ' id ' | get_field 2)
quantum router-interface-add $ROUTER_ID $SUBNET_ID

if [ -f /etc/quantum/l3_agent.ini ]; then
  sed -e "s|.*router_id *=|router_id=$ROUTER_ID|g" -i /etc/quantum/l3_agent.ini
  service quantum-l3-agent restart
fi

EOF_SERVER_NAME

        } do |ok, out|
            puts out
            fail "Failed to configure networking!" unless ok
        end
    end

end
