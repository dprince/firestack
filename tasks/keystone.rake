include ChefVPCToolkit::CloudServersVPC

namespace :keystone do

    desc "Build packages from a local keystone source directory."
    task :build_packages do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~dan-prince/keystone/ubuntu-keystone-nodoc"
            #deb_packager_url="lp:~openstack-ubuntu-packagers/keystone/ubuntu"
        end
        pwd=Dir.pwd
        keystone_revision=get_revision(src_dir)
        raise "Failed to get keystone revision." if keystone_revision.empty?

        out=%x{
cd #{src_dir}
[ -f keystone/__init__.py ] || { echo "Please specify a top level keystone project dir."; exit 1; }
MY_TMP="#{mktempdir}"
tar czf $MY_TMP/keystone.tar.gz . 2> /dev/null || { echo "Failed to create keystone source tar."; exit 1; }
scp #{SSH_OPTS} $MY_TMP/keystone.tar.gz root@#{gw_ip}:/tmp/keystone.tar.gz
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

aptitude -y -q install dpkg-dev bzr git quilt debhelper python-m2crypto python-all python-setuptools python-sphinx python-distutils-extra python-twisted-web python-gflags python-mox python-carrot python-boto python-amqplib python-ipy python-sqlalchemy-ext  python-eventlet python-routes python-webob python-cheetah python-nose python-paste python-pastedeploy python-tempita python-migrate python-netaddr python-lockfile pep8 python-sphinx &> /dev/null || { echo "Failed to install prereq packages."; exit 1; }

BUILD_TMP=$(mktemp -d)
cd "$BUILD_TMP"
mkdir keystone && cd keystone
tar xzf /tmp/keystone.tar.gz 2> /dev/null || { echo "Failed to extract keystone source tar."; exit 1; }
rm -rf .bzr
rm -rf .git
cd ..
bzr checkout --lightweight #{deb_packager_url} keystone
rm -rf keystone/.bzr
rm -rf keystone/.git
cd keystone
echo "keystone (9999.1-vpc#{keystone_revision}) maverick; urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
#QUILT_PATCHES=debian/patches quilt push -a || \ { echo "Failed to patch keystone."; exit 1; }
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> /dev/null || { echo "Failed to build packages."; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/keystone*
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

end
