include ChefVPCToolkit::CloudServersVPC

namespace :keystone do

    desc "Build packages from a local keystone source directory."
    task :build_packages => :tarball do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
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

        out=%x{
cd #{src_dir}
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

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
        keystone_revision = get_revision(src_dir)
        raise "Failed to get keystone revision." if keystone_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f keystone/__init__.py ] \
                || { echo "Please specify a valid keystone project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".keystone-venv" ] && rm -Rf .keystone-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/keystone.tar.gz . 2> /dev/null || { echo "Failed to create keystone source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/keystone.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, res|
            fail "Unable to create keystone tarball! \n #{res}" unless ok
        end
    end

end
