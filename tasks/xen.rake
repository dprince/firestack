require "base64"

include ChefVPCToolkit::CloudServersVPC
include ChefVPCToolkit::Util

def mask_to_cidr(mask)
    bitcount = 0
    mask.split('.').each do |octet|
        o = octet.to_i
        bitcount += (o & 1) and (o >>= 1) until o == 0
    end
  return bitcount
end

# By default Xenserver configures xenbr0 with the IP. This function
# moves the IP from the bridge back to eth0 so OpenVPN can use it
def move_xenbr_ip_to_eth0(xenserver_ip, vpn_gw_ip, client_vpn_ip)

    ifconfig_xenbr0=%x{ssh #{SSH_OPTS} root@#{xenserver_ip} ifconfig xenbr0 | grep 'inet addr'}.chomp
    def_route_xenbr0=%x{ssh #{SSH_OPTS} root@#{xenserver_ip} ip r | grep default}.chomp

    return false if ifconfig_xenbr0.nil? or ifconfig_xenbr0.empty?

    def_gw=def_route_xenbr0.scan(/default via ([0-9.]*)/).to_s
    ip_addr=ifconfig_xenbr0.scan(/inet addr:([0-9.]*)/).to_s
    bcast=ifconfig_xenbr0.scan(/Bcast:([0-9.]*)/).to_s
    mask=ifconfig_xenbr0.scan(/Mask:([0-9.]*)/).to_s
    cidr=mask_to_cidr(mask)

    return false if ip_addr == client_vpn_ip

    out=%x{
ssh #{SSH_OPTS} root@#{xenserver_ip} bash <<-"EOF_BASH"
cat > /root/move_ip.sh <<-"EOF_MOVE_IP"
ip addr del #{ip_addr}/#{cidr} brd #{bcast} scope global dev xenbr0
ip addr add #{ip_addr}/#{cidr} brd #{bcast} scope global dev eth0
brctl delif xenbr0 eth0
route del default gw #{def_gw} xenbr0
route add default gw #{def_gw} eth0
#route add -host #{vpn_gw_ip} gw #{def_gw} dev eth0
EOF_MOVE_IP
bash /root/move_ip.sh </dev/null &> /dev/null &
EOF_BASH
    }
    return true
    
end

namespace :xen do

    desc "Install plugins into the XenServer dom0."
    task :install_plugins do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        # default to xen1 if SERVER_NAME is unset
        server_name = "xen1" if server_name.nil?
        pwd=Dir.pwd
        out=%x{
cd #{src_dir}
[ -f nova/flags.py ] || { echo "Please specify a top level nova project dir."; exit 1; }
cd plugins/xenserver/xenapi
MY_TMP=$(mktemp -d -t tmp.XXXXXXXXXX)
tar czf $MY_TMP/plugins.tar.gz ./etc
scp #{SSH_OPTS} $MY_TMP/plugins.tar.gz root@#{gw_ip}:/tmp/plugins.tar.gz
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/plugins.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /
tar xf /tmp/plugins.tar.gz
chmod a+x /etc/xapi.d/plugins/*
sed -i -e "s/enabled=0/enabled=1/" /etc/yum.repos.d/CentOS-Base.repo
rpm -q parted &> /dev/null || yum install -y -q parted
EOF_SERVER_NAME
BASH_EOF

	}

		retval=$?
		puts out
		if not retval.success?
			fail "Failed to install plugins!"
		end

	end

    desc "Bootstrap a local XenServer install to a server group."
    task :bootstrap do

        group=ServerGroup.fetch(:source => "cache")
        gw_ip=group.vpn_gateway_ip

        xenserver_ip=ENV['XENSERVER_IP']
        raise "Please specify a XENSERVER_IP." if xenserver_ip.nil?
        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?

        # create VPN client keys for the server
        client=group.client(server_name)
        if client.nil? then
            client=Client.create(group, server_name, false)
            client.poll_until_online
			group=ServerGroup.fetch
			group.cache_to_disk
        end
        client=Client.fetch(:id => client.id, :source => "remote")
        vpn_interface=client.vpn_network_interfaces[0]

        root_ssh_pub_key=%x{rake ssh cat /root/.ssh/authorized_keys | grep cloud_servers_vpc}.chomp

        out=%x{

# SSH PUBLIC KEY CONFIG
ssh #{SSH_OPTS} root@#{xenserver_ip} bash <<-"EOF_BASH"
[ -d .ssh ] || mkdir .ssh
chmod 700 .ssh
cat > /root/.ssh/authorized_keys <<-"EOF_SSH_KEYS"
#{root_ssh_pub_key}
#{Util.load_public_key}
EOF_SSH_KEYS
chmod 600 /root/.ssh/authorized_keys
EOF_BASH
		}
		puts out

        move_xenbr_ip_to_eth0(xenserver_ip, gw_ip, vpn_interface.vpn_ip_addr)

        out=%x{

# SSH PUBLIC KEY CONFIG
ssh #{SSH_OPTS} root@#{xenserver_ip} bash <<-"EOF_BASH"

# EPEL
cat > /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL <<-"EOF_RPM_GPG_KEY"
#{IO.read(File.join(File.dirname(__FILE__), "RPM-GPG-KEY-EPEL"))}
EOF_RPM_GPG_KEY
cat > /etc/yum.repos.d/epel.repo <<-"EOF_EPEL"
#{IO.read(File.join(File.dirname(__FILE__), "epel.repo"))}
EOF_EPEL

rpm -qi openvpn &> /dev/null || yum install -y -q openvpn ntp
service openvpn stop

#OPENVPN CONF
cat > /etc/openvpn/xen1.conf <<-"EOF_VPN_CONF"
client
dev #{group.vpn_device}
proto #{group.vpn_proto}

remote #{group.vpn_gateway_ip} 1194

resolv-retry infinite
nobind
persist-key
persist-tun

ca ca.crt
cert xen1.crt
key xen1.key

ns-cert-type server

comp-lzo

up ./up.bash
down ./down.bash
up-delay
verb 3
EOF_VPN_CONF

cat > /etc/openvpn/xen1.crt <<-"EOF_CLIENT_CERT"
#{vpn_interface.client_cert}
EOF_CLIENT_CERT

cat > /etc/openvpn/xen1.key <<-"EOF_CLIENT_KEY"
#{vpn_interface.client_key}
EOF_CLIENT_KEY
chmod 600 /etc/openvpn/xen1.key

cat > /etc/openvpn/ca.crt <<-"EOF_CA_CERT"
#{vpn_interface.ca_cert}
EOF_CA_CERT

# Looks something like this: '1.2.3.4 dev eth0'
DEF_GW_WITH_DEV=$(ip r | grep default | sed -e "s|default via ||")

# NOTE: we hard code the broadcast addresses below since this all instances
# of this VPC group will use 172.19.127.255
cat > /etc/openvpn/down.bash <<-EOF_DOWN_BASH
#!/bin/bash
mv /etc/resolv.conf.bak /etc/resolv.conf
/sbin/ip addr del #{vpn_interface.vpn_ip_addr}/17 brd 172.19.127.255 scope global dev xenbr0
/sbin/route del -host #{gw_ip} gw $DEF_GW_WITH_DEV
EOF_DOWN_BASH
chmod 755 /etc/openvpn/down.bash

cat > /etc/openvpn/up.bash <<-EOF_UP_BASH
#!/bin/bash
mv /etc/resolv.conf /etc/resolv.conf.bak
cat > /etc/resolv.conf <<-"EOF_RESOLV_CONF"
search vpc
nameserver 172.19.0.1
EOF_RESOLV_CONF
/sbin/ip addr del #{vpn_interface.vpn_ip_addr}/17 brd 172.19.127.255 scope global dev tap0
/sbin/ip addr add #{vpn_interface.vpn_ip_addr}/17 brd 172.19.127.255 scope global dev xenbr0
/usr/sbin/brctl addif xenbr0 tap0
EOF_UP_BASH
chmod 755 /etc/openvpn/up.bash

# bootstrap the 32bit Chef client if it isn't already there
if ! rpm -q rubygem-chef &> /dev/null; then
CHEF_RPM_DIR=$(mktemp -d tmp.XXXXXXXXXX)
wget http://c2521002.r2.cf0.rackcdn.com/chef-client-0.9.8-centos5.5-i386.tar.gz -O $CHEF_RPM_DIR/chef.tar.gz &> /dev/null \
        || { echo "Failed to download Chef RPM tarball."; exit 1; }
cd $CHEF_RPM_DIR
tar xzf chef.tar.gz || { echo "Failed to extract Chef tarball."; exit 1; }
rm chef.tar.gz
cd chef*
yum install -q -y --nogpgcheck */*.rpm
rpm -q rubygem-chef &> /dev/null || { echo "Failed to install chef."; exit 1; }

# patch platform.rb so it detects xenserver as Centos
patch --quiet /usr/lib/ruby/gems/1.8/gems/chef-0.9.*/lib/chef/platform.rb <<"EOF_PATCH"
156a157,164
>           :xenserver   => {
>             :default => {
>               :service => Chef::Provider::Service::Redhat,
>               :cron => Chef::Provider::Cron,
>               :package => Chef::Provider::Package::Yum,
>               :mdadm => Chef::Provider::Mdadm
>             }
>           },
EOF_PATCH

fi

# Restart ntpd
/etc/init.d/ntpd restart < /dev/null &> /dev/null

#set hostname and update /etc/hosts
hostname #{server_name}
if ! grep "#{vpn_interface.vpn_ip_addr}" /etc/hosts > /dev/null; then
  echo "#{vpn_interface.vpn_ip_addr}   #{server_name}.#{group.domain_name} #{server_name}" >> /etc/hosts
fi

# Stop xapi (will be restart via Chef once openvpn starts)
service xapi stop &> /dev/null

route add -host #{gw_ip} gw $DEF_GW_WITH_DEV
service openvpn start

EOF_BASH
        }
        puts out

    end

    desc "Disconnect and cleanup Xen instance from VPC Group."
    task :disconnect do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to xen1 if SERVER_NAME is unset
        server_name = "xen1" if server_name.nil?
        pwd=Dir.pwd
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
ssh #{server_name} bash <<"EOF_XEN1_BASH"
[ -f /etc/logrotate.d/chef ] && rm /etc/logrotate.d/chef
chkconfig chef-client off
service chef-client stop &> /dev/null
[ -f /etc/chef/validation.pem ] && rm /etc/chef/validation.pem
[ -f /etc/chef/client.pem ] && rm /etc/chef/client.pem
rm -Rf /var/log/chef/*
rm -Rf /var/log/nova/*

for UUID in $(xe vm-list is-control-domain=false | grep uuid | sed -e 's|.*: ||'); do
echo "Destroying Xen instance uuid: $UUID"
xe vm-shutdown uuid=$UUID
xe vm-destroy uuid=$UUID
done

TMP_SHUTDOWN=$(mktemp -t tmp.XXXXXXXXXX)
echo 'sleep 2 && service openvpn stop' > $TMP_SHUTDOWN
bash $TMP_SHUTDOWN </dev/null &> /dev/null &
EOF_XEN1_BASH
BASH_EOF

	}

		retval=$?
		puts out
		if not retval.success?
			fail "Failed to disconnect #{server_name} from VPC Group!"
		end

	end

end
