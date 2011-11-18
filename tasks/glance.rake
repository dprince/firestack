include ChefVPCToolkit::CloudServersVPC

namespace :glance do

    desc "Push source into a glance installation."
    task :install_source => :tarball do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        server_name = "glance1" if server_name.nil?
        pwd=Dir.pwd
        out=%x{
cd #{src_dir}
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/glance.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/share/pyshared
rm -Rf glance
tar xf /tmp/glance.tar.gz 2> /dev/null || { echo "Failed to extract glance source tar."; exit 1; }
for FILE in $(find glance -name '*.py'); do
    DIR=$(dirname /usr/lib/pymodules/python2.6/$FILE)
    [ -d $DIR ] || mkdir -p $DIR
    [ -f /usr/lib/pymodules/python2.6/$FILE ] || ln -s /usr/share/pyshared/$FILE /usr/lib/pymodules/python2.6/$FILE
done
[ -f /etc/init/glance-api.conf ] && service glance-api restart
[ -f /etc/init/glance-registry.conf ] && service glance-registry restart
EOF_SERVER_NAME
BASH_EOF
RETVAL=$?
exit $RETVAL
        }
        puts out

    end

    desc "Build packages from a local glance source directory."
    task :build_packages => :tarball do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~openstack-ubuntu-packagers/glance/ubuntu"
        end
        pwd=Dir.pwd
        glance_revision=get_revision(src_dir)
        raise "Failed to get glance revision." if glance_revision.empty?

        puts "Building glance packages using: #{deb_packager_url}"

        out=%x{
cd #{src_dir}
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

DEBIAN_FRONTEND=noninteractive apt-get -y -q install dpkg-dev bzr git quilt debhelper python-m2crypto python-all python-setuptools python-sphinx python-distutils-extra python-twisted-web python-gflags python-mox python-carrot python-boto python-amqplib python-ipy python-sqlalchemy-ext  python-eventlet python-routes python-webob python-cheetah python-nose python-paste python-pastedeploy python-tempita python-migrate python-netaddr python-glance python-lockfile pep8 python-sphinx &> /dev/null || { echo "Failed to install prereq packages."; exit 1; }

BUILD_TMP=$(mktemp -d)
cd "$BUILD_TMP"
mkdir glance && cd glance
tar xzf /tmp/glance.tar.gz 2> /dev/null || { echo "Falied to extract glance source tar."; exit 1; }
rm -rf .bzr
rm -rf .git
cd ..
bzr checkout --lightweight #{deb_packager_url} glance &> /tmp/bzrglance.log || { echo "Failed checkout glance builder: #{deb_packager_url}."; cat /tmp/bzrglance.log; exit 1; }
rm -rf glance/.bzr
rm -rf glance/.git
cd glance
echo "glance (9999.1-vpc#{glance_revision}) $(lsb_release -sc); urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
QUILT_PATCHES=debian/patches quilt push -a || \ { echo "Failed to patch glance."; exit 1; }
BUILD_LOG=$(mktemp)
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> $BUILD_LOG || { echo "Failed to build packages."; cat $BUILD_LOG; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/glance*
cp $BUILD_TMP/*.deb /root/openstack-packages
rm -Rf "$BUILD_TMP"
BASH_EOF
RETVAL=$?
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Build packages failed!"
        end

    end

    task :tarball do
        gw_ip = ServerGroup.fetch(:source => "cache").vpn_gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        glance_revision = get_revision(src_dir)
        raise "Failed to get glance revision." if glance_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f glance/version.py ] \
                || { echo "Please specify a valid glance project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            tar czf $MY_TMP/glance.tar.gz . 2> /dev/null || { echo "Failed to create glance source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/glance.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, res|
            fail "Unable to create glance tarball! \n #{res}" unless ok
        end
    end

end
