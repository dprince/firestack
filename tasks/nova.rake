include ChefVPCToolkit::CloudServersVPC

namespace :nova do

    desc "Push source into a nova installation."
    task :install_source do

        sg=ServerGroup.fetch(:source => "cache")
		gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?
        pwd=Dir.pwd
        out=%x{
cd #{src_dir}
[ -f nova/flags.py ] || { echo "Please specify a top level nova project dir."; exit 1; }
MY_TMP=$(mktemp -d)
tar czf $MY_TMP/nova.tar.gz ./nova
scp $MY_TMP/nova.tar.gz root@#{gw_ip}:/tmp/nova.tar.gz
ssh root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/nova.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/share/pyshared
rm -Rf nova
tar xf /tmp/nova.tar.gz
for FILE in $(find nova -name '*.py'); do
    DIR=$(dirname /usr/lib/pymodules/python2.6/$FILE)
    [ -d $DIR ] || mkdir $DIR
    [ -f /usr/lib/pymodules/python2.6/$FILE ] || ln -s /usr/share/pyshared/$FILE /usr/lib/pymodules/python2.6/$FILE
done
[ -f /etc/init/nova-api.conf ] && service nova-api restart
[ -f /etc/init/nova-compute.conf ] && service nova-compute restart
[ -f /etc/init/nova-network.conf ] && service nova-network restart
[ -f /etc/init/nova-scheduler.conf ] && service nova-scheduler restart
[ -f /etc/init/nova-objectstore.conf ] && service nova-objectstore restart
EOF_SERVER_NAME
BASH_EOF
rm -Rf "$MY_TMP"
        }
        puts out

    end

end
