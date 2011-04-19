include ChefVPCToolkit::CloudServersVPC

namespace :glance do

    desc "Push source into a glance installation."
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
[ -f glance/version.py ] || { echo "Please specify a top level glance project dir."; exit 1; }
MY_TMP=$(mktemp -d)
tar czf $MY_TMP/glance.tar.gz ./glance
scp $MY_TMP/glance.tar.gz root@#{gw_ip}:/tmp/glance.tar.gz
ssh root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/glance.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/share/pyshared
rm -Rf glance
tar xf /tmp/glance.tar.gz
for FILE in $(find glance -name '*.py'); do
    DIR=$(dirname /usr/lib/pymodules/python2.6/$FILE)
    [ -d $DIR ] || mkdir -p $DIR
    [ -f /usr/lib/pymodules/python2.6/$FILE ] || ln -s /usr/share/pyshared/$FILE /usr/lib/pymodules/python2.6/$FILE
done
[ -f /etc/init/glance-api.conf ] && service glance-api restart
[ -f /etc/init/glance-registry.conf ] && service glance-registry restart
EOF_SERVER_NAME
BASH_EOF
rm -Rf "$MY_TMP"
        }
        puts out

    end

end
