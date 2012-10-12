# NOTE(dprince): The Ubuntu packages builders are a bit outdated.
# Would love to see someone else pick these up:
#   https://lists.launchpad.net/openstack/msg07900.html

namespace :ubuntu do

    task :build_nova => :tarball do

        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~openstack-ubuntu-packagers/nova/ubuntu"
        end

        nova_revision = get_revision(src_dir)
        raise "Failed to get nova revision." if nova_revision.empty?

        puts "Building nova packages using: #{deb_packager_url}"

        remote_exec %{
if ! /usr/bin/dpkg -l add-apt-key &> /dev/null; then
  cat > /etc/apt/sources.list.d/nova_ppa-source.list <<-EOF_CAT
deb http://ppa.launchpad.net/nova-core/trunk/ubuntu $(lsb_release -sc) main
EOF_CAT
  apt-get -y -q install add-apt-key &> /dev/null || { echo "Failed to install add-apt-key."; exit 1; }
  add-apt-key 2A2356C9 &> /dev/null || \
  add-apt-key 2A2356C9 -k keyserver.ubuntu.com &> /dev/null || \
  { echo "Failed to add apt key for PPA."; exit 1; }
  apt-get -q update &> /dev/null || { echo "Failed to apt-get update."; exit 1; }
fi

if ! /usr/bin/dpkg -l python-novaclient &> /dev/null; then
DEBIAN_FRONTEND=noninteractive apt-get -y -q install dpkg-dev bzr git quilt debhelper python-m2crypto python-all python-setuptools python-sphinx python-distutils-extra python-twisted-web python-gflags python-mox python-carrot python-boto python-amqplib python-ipy python-sqlalchemy-ext  python-eventlet python-routes python-webob python-cheetah python-nose python-paste python-pastedeploy python-tempita python-migrate python-netaddr python-novaclient python-lockfile pep8 python-sphinx &> /dev/null || { echo "Failed to install prereq packages."; exit 1; }
fi

BUILD_TMP=$(mktemp -d)
cd "$BUILD_TMP"
mkdir nova && cd nova
tar xzf /tmp/nova.tar.gz 2> /dev/null || { echo "Failed to extract nova source tar."; exit 1; }
cd ..
bzr checkout --lightweight #{deb_packager_url} nova &> /tmp/bzrnova.log || { echo "Failed checkout nova builder: #{deb_packager_url}."; cat /tmp/bzrnova.log; exit 1; }
cd nova
sed -e 's|^nova-compute-deps.*|nova-compute-deps=adduser|' -i debian/ubuntu_control_vars
sed -e 's|.*modprobe nbd.*||' -i debian/nova-compute.upstart.in
sed -e 's| --flagfile=\/etc\/nova\/nova-compute.conf||' -i debian/nova-compute.upstart.in
echo "nova (9999.1-vpc#{nova_revision}) $(lsb_release -sc); urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
BUILD_LOG=$(mktemp)
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> $BUILD_LOG || { echo "Failed to build nova packages."; cat $BUILD_LOG; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/nova*
rm -f /root/openstack-packages/python-nova*
cp $BUILD_TMP/*.deb /root/openstack-packages
rm -Rf "$BUILD_TMP"
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            puts out
            fail "Build packages failed!" unless ok
        end
    end

    task :build_glance => :tarball do

        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~openstack-ubuntu-packagers/glance/ubuntu"
        end
        pwd=Dir.pwd
        glance_revision=get_revision(src_dir)
        raise "Failed to get glance revision." if glance_revision.empty?

        puts "Building glance packages using: #{deb_packager_url}"

        remote_exec %{
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
#No jsonschema packages for Oneiric.... so lets do this for now (HACK!)
sed -e 's|^import jsonschema||' -i glance/schema.py
sed -e 's|jsonschema.validate.*|pass|' -i glance/schema.py
sed -e 's|jsonschema.ValidationError|Exception|' -i glance/schema.py
echo "glance (9999.1-vpc#{glance_revision}) $(lsb_release -sc); urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
BUILD_LOG=$(mktemp)
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> $BUILD_LOG || { echo "Failed to build packages."; cat $BUILD_LOG; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/glance*
cp $BUILD_TMP/*.deb /root/openstack-packages
rm -Rf "$BUILD_TMP"
        } do |ok, out|
            puts out
            fail "Build packages failed!" unless ok
        end

    end

    task :build_keystone => :tarball do

        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        deb_packager_url=ENV['DEB_PACKAGER_URL']
        if deb_packager_url.nil? then
            deb_packager_url="lp:~openstack-ubuntu-packagers/keystone/ubuntu"
        end
        pwd=Dir.pwd
        keystone_revision=get_revision(src_dir)
        raise "Failed to get keystone revision." if keystone_revision.empty?

        puts "Building keystone packages using: #{deb_packager_url}"

        remote_exec %{
if ! /usr/bin/dpkg -l add-apt-key &> /dev/null; then
  cat > /etc/apt/sources.list.d/nova_ppa-source.list <<-EOF_CAT
deb http://ppa.launchpad.net/nova-core/trunk/ubuntu $(lsb_release -sc) main
EOF_CAT
  apt-get -y -q install add-apt-key &> /dev/null || { echo "Failed to install add-apt-key."; exit 1; }
  add-apt-key 2A2356C9 &> /dev/null || { echo "Failed to add apt key for PPA."; exit 1; }
  apt-get -q update &> /dev/null || { echo "Failed to apt-get update."; exit 1; }
fi

DEBIAN_FRONTEND=noninteractive apt-get -y -q install dpkg-dev bzr git quilt debhelper python-m2crypto python-all python-setuptools python-sphinx python-distutils-extra python-twisted-web python-gflags python-mox python-carrot python-boto python-amqplib python-ipy python-sqlalchemy-ext python-passlib python-eventlet python-routes python-webob python-cheetah python-nose python-paste python-pastedeploy python-tempita python-migrate python-netaddr python-lockfile pep8 python-sphinx &> /dev/null || { echo "Failed to install prereq packages."; exit 1; }

BUILD_TMP=$(mktemp -d)
cd "$BUILD_TMP"
mkdir keystone && cd keystone
tar xzf /tmp/keystone.tar.gz 2> /dev/null || { echo "Failed to extract keystone source tar."; exit 1; }
rm -rf .bzr
rm -rf .git
cd ..
bzr checkout --lightweight #{deb_packager_url} keystone &> /tmp/bzrkeystone.log || { echo "Failed checkout keystone builder: #{deb_packager_url}."; cat /tmp/bzrkeystone.log; exit 1; }
rm -rf keystone/.bzr
rm -rf keystone/.git
cd keystone
echo "keystone (9999.1-vpc#{keystone_revision}) $(lsb_release -sc); urgency=high" > debian/changelog
echo " -- Dev Null <dev@null.com>  $(date +\"%a, %e %b %Y %T %z\")" >> debian/changelog
BUILD_LOG=$(mktemp)
DEB_BUILD_OPTIONS=nocheck,nodocs dpkg-buildpackage -rfakeroot -b -uc -us -d \
 &> $BUILD_LOG || { echo "Failed to build keystone packages."; cat $BUILD_LOG; exit 1; }
cd /tmp
[ -d /root/openstack-packages ] || mkdir -p /root/openstack-packages
rm -f /root/openstack-packages/keystone*
cp $BUILD_TMP/*.deb /root/openstack-packages
rm -Rf "$BUILD_TMP"
BASH_EOF
        } do |ok, out|
            puts out
            fail "Build packages failed!" unless ok
        end
    end

end
