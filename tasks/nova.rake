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
scp ./etc/api-paste.ini root@#{gw_ip}:/tmp/api-paste.ini
MY_TMP=$(mktemp -d)
tar czf $MY_TMP/nova.tar.gz ./nova
scp $MY_TMP/nova.tar.gz root@#{gw_ip}:/tmp/nova.tar.gz
ssh root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/api-paste.ini #{server_name}:/etc/nova/api-paste.ini
scp /tmp/nova.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/share/pyshared
rm -Rf nova
tar xf /tmp/nova.tar.gz
for FILE in $(find nova -name '*.py'); do
    DIR=$(dirname /usr/lib/pymodules/python2.6/$FILE)
    [ -d $DIR ] || mkdir -p $DIR
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

    desc "Smoke test nova."
    task :smoke_tests do

        sg=ServerGroup.fetch(:source => "cache")
		gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?
        pwd=Dir.pwd
        out=%x{
MY_TMP=$(mktemp -d)
cd tests/ruby
tar czf $MY_TMP/ruby-tests.tar.gz *
scp $MY_TMP/ruby-tests.tar.gz root@#{gw_ip}:/tmp/ruby-tests.tar.gz
ssh root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/ruby-tests.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
    if ! gem list | grep openstack-compute &> /dev/null; then
        gem install openstack-compute
    fi
    [ -d ~/ruby-tests ] || mkdir ~/ruby-tests
    cd ruby-tests
    tar xzf /tmp/ruby-tests.tar.gz
    bash ~/ruby-tests/run.sh
EOF_SERVER_NAME
BASH_EOF
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Test task failed!"
        end

    end

end
