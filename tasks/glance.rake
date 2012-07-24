namespace :glance do

    desc "Push source into a glance installation."
    task :install_source => :tarball do
        server_name=ENV['SERVER_NAME']
        server_name = "glance1" if server_name.nil?
        remote_exec %{
scp /tmp/glance.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/lib/python2.7/site-packages
rm -Rf glance
tar xf /tmp/glance.tar.gz 2> /dev/null || { echo "Failed to extract glance source tar."; exit 1; }
service openstack-glance-api restart
service openstack-glance-registry restart
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Failed to install source!" unless ok
        end
    end

    desc "Build packages from a local glance source directory."
    task :build_packages do
        if ENV['RPM_PACKAGER_URL'].nil? then
            Rake::Task["glance:build_ubuntu_packages"].invoke
        else
            Rake::Task["glance:build_fedora_packages"].invoke
        end
    end

    task :build_fedora_packages do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-glance.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/glance.git"
        end
        ENV["PROJECT_NAME"] = "glance"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :build_ubuntu_packages => :tarball do

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

    task :tarball do
        gw_ip = ServerGroup.get(:source => "cache").vpn_gateway_ip
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
            [ -d ".glance-venv" ] && rm -Rf .glance-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/glance.tar.gz . 2> /dev/null || { echo "Failed to create glance source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/glance.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, res|
            fail "Unable to create glance tarball! \n #{res}" unless ok
        end
    end

    task :load_images do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
if [ ! -f /var/lib/glance/images_loaded ]; then
    mkdir -p /var/lib/glance/
    [ -f /root/openstackrc ] && source /root/openstackrc
    curl http://c3226372.r72.cf0.rackcdn.com/tty_linux.tar.gz | tar xvz -C /tmp/
    ARI_ID=`glance add name="ari-tty" type="ramdisk" disk_format="ari" container_format="ari" is_public=true --silent-upload < /tmp/tty_linux/ramdisk | tail -n 1 | sed 's/.*\: //g'`
    AKI_ID=`glance add name="aki-tty" type="kernel" disk_format="aki" container_format="aki" is_public=true --silent-upload < /tmp/tty_linux/kernel | tail -n 1 | sed 's/.*\: //g'`
    if glance add name="ami-tty" type="kernel" disk_format="ami" container_format="ami" ramdisk_id="$ARI_ID" kernel_id="$AKI_ID" is_public=true --silent-upload < /tmp/tty_linux/image; then
       touch /var/lib/glance/images_loaded
    fi
fi
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Load images failed!" unless ok
        end
    end

    task :load_images_xen do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        remote_exec %{
if [ -f /images/squeeze-agent-0.0.1.31.ova ]; then
  scp /images/squeeze-agent-0.0.1.31.ova #{server_name}:/tmp/
fi
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
if [ ! -f /var/lib/glance/images_loaded ]; then
    mkdir -p /var/lib/glance/
    [ -f /root/openstackrc ] && source /root/openstackrc
    if [ ! -f /tmp/squeeze-agent-0.0.1.31.ova ]; then
      cd /tmp
      curl http://c3324746.r46.cf0.rackcdn.com/squeeze-agent-0.0.1.31.ova -o /tmp/squeeze-agent-0.0.1.31.ova
    fi
    if glance add name="squeeze" disk_format="vhd" container_format="ovf" is_public=true --silent-upload < /tmp/squeeze-agent-0.0.1.31.ova; then
       touch /var/lib/glance/images_loaded
    fi
fi
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Load images failed!" unless ok
        end
    end

end
