include ChefVPCToolkit::CloudServersVPC

namespace :nova do

    desc "Push source into a nova installation."
    task :install_source do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        pwd=Dir.pwd
        out=%x{
cd #{src_dir}
[ -f nova/flags.py ] || { echo "Please specify a top level nova project dir."; exit 1; }
scp ./etc/nova/api-paste.ini root@#{gw_ip}:/tmp/api-paste.ini
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
for FILE in $(find nova -name '*.py' -o -name '*.template'); do
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
RETVAL=$?
rm -Rf "$MY_TMP"
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Install source failed!"
        end

    end

    desc "Smoke test nova."
    task :smoke_tests do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        pwd=Dir.pwd
        out=%x{
MY_TMP=$(mktemp -d)
cd tests/ruby
tar czf $MY_TMP/ruby-tests.tar.gz *
scp $MY_TMP/ruby-tests.tar.gz root@#{gw_ip}:/tmp/ruby-tests.tar.gz
rm -Rf "$MY_TMP"
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

    desc "Build packages from a local nova source directory."
    task :build_packages do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~openstack-ubuntu-packagers/nova/ubuntu"
        end
        pwd=Dir.pwd
        out=%x{
cd #{src_dir}
[ -f nova/flags.py ] || { echo "Please specify a top level nova project dir."; exit 1; }
MY_TMP=$(mktemp -d)
tar czf $MY_TMP/nova.tar.gz .
scp $MY_TMP/nova.tar.gz root@#{gw_ip}:/tmp/nova.tar.gz
ssh root@#{gw_ip} bash <<-"BASH_EOF"

aptitude -y -q install dpkg-dev bzr git quilt debhelper python-m2crypto python-all python-setuptools python-sphinx python-distutils-extra python-twisted-web python-gflags python-mox python-carrot python-boto python-amqplib python-ipy python-sqlalchemy-ext  python-eventlet python-routes python-webob python-cheetah python-nose python-paste python-pastedeploy python-tempita python-migrate python-netaddr python-glance python-novaclient python-lockfile pep8 python-sphinx &> /dev/null || { echo "Failed to install prereq packages."; exit 1; }

BUILD_TMP=$(mktemp -d)
cd "$BUILD_TMP"
mkdir nova && cd nova
tar xzf /tmp/nova.tar.gz
NOVA_REVISION=$(bzr version-info | grep revno | sed -e "s|revno: ||")
rm -rf .bzr
rm -rf .git
cd ..
bzr checkout --lightweight #{deb_packager_url} nova
rm -rf nova/.bzr
rm -rf nova/.git
cd nova
echo "nova (9999.1-bzr${NOVA_REVISION}) maverick; urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
QUILT_PATCHES=debian/patches quilt push -a || \
 { echo "Failed to patch nova."; exit 1; }
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> /dev/null || { echo "Failed to build packages."; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/nova*
rm -f /root/openstack-packages/python-nova*
cp $BUILD_TMP/*.deb /root/openstack-packages
rm -Rf "$BUILD_TMP"
BASH_EOF
RETVAL=$?
rm -Rf "$MY_TMP"
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Build packages failed!"
        end

    end

    desc "Tail nova logs."
    task :tail_logs do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?
        line_count=ENV['LINE_COUNT']
        line_count = 50 if line_count.nil?

        pwd=Dir.pwd
        out=%x{
ssh root@#{gw_ip} bash <<-"BASH_EOF"
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
tail -n #{line_count} /var/log/nova/nova-*
EOF_SERVER_NAME
BASH_EOF
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Tail logs failed!"
        end

    end

end
