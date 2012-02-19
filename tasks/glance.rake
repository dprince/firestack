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
    task :build_packages do
        if ENV['RPM_PACKAGER_URL'].nil? then
            Rake::Task["glance:build_ubuntu_packages"].invoke
        else
            Rake::Task["glance:build_fedora_packages"].invoke
        end
    end

    # FIXME : this looks very similar to nova:build_fedora_packages, reuse some of it
    task :build_fedora_packages do
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-glance.git")
        packager_branch= ENV.fetch("RPM_PACKAGER_BRANCH", "master")
        git_master = ENV.fetch("GIT_MASTER", "git://github.com/openstack/glance.git")
        merge_master = ENV.fetch("MERGE_MASTER", "")
        git_revision = ENV.fetch("REVISION", "")
        src_url = ENV["SOURCE_URL"]
        src_branch = ENV.fetch("SOURCE_BRANCH", "master")
        build_docs = ENV.fetch("BUILD_DOCS", "")
        raise "Please specify a SOURCE_URL." if src_url.nil?

        puts "Building glance packages using: #{packager_url}:#{packager_branch} #{src_url}:#{src_branch}"

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

yum install -q -y git fedpkg python-setuptools

BUILD_LOG=$(mktemp)

test -e openstack-glance && rm -rf openstack-glance
test -e glance_source && rm -rf glance_source

#{BASH_COMMON}

git_clone_with_retry "#{git_master}" "glance_source"
cd glance_source
git fetch "#{src_url}" "#{src_branch}" || fail "Failed to git fetch branch $GLANCE_BRANCH."
git checkout -q FETCH_HEAD || fail "Failed to git checkout FETCH_HEAD."
GLANCE_REVISION=#{git_revision}
if [ -n "$GLANCE_REVISION" ]; then
	git checkout $GLANCE_REVISION || \
		fail "Failed to checkout revision $GLANCE_REVISION."
else
	GLANCE_REVISION=$(git rev-parse --short HEAD)
	[ -z "$GLANCE_REVISION" ] && \
		fail "Failed to obtain glance revision from git."
fi
echo "GLANCE_REVISION=$GLANCE_REVISION"

if [ -n "#{merge_master}" ]; then
	git merge master || fail "Failed to merge master."
fi

PACKAGE_REVISION=$(date +%s)_$(git log --format=%h -n 1)
python setup.py sdist &> $BUILD_LOG || { echo "Failed to run sdist."; cat $BUILD_LOG; exit 1; }

cd 
git_clone_with_retry "#{packager_url}" "openstack-glance" || { echo "Unable to clone repos : #{packager_url}"; exit 1; }
cd openstack-glance
[ #{packager_branch} != "master" ] && { git checkout -t -b #{packager_branch} origin/#{packager_branch} || { echo "Unable to checkout branch :  #{packager_branch}"; exit 1; } }
cp ~/glance_source/dist/*.tar.gz .
sed -i.bk -e "s/\\(Release:.*\\.\\).*/\\1$PACKAGE_REVISION/g" openstack-glance.spec
sed -i.bk -e "s/Source0:.*/Source0:      $(ls *.tar.gz)/g" openstack-glance.spec
[ -z "#{build_docs}" ] && sed -i -e 's/%global with_doc .*/%global with_doc 0/g' openstack-glance.spec
md5sum *.tar.gz > sources 

# tmp workaround
sed -i.bk openstack-glance.spec -e 's/.*dnsmasq-utils.*//g'

# install dependencies
fedpkg srpm &> $BUILD_LOG || { echo "Failed to build srpm."; cat $BUILD_LOG; exit 1; }
yum-builddep -y *.src.rpm &> $BUILD_LOG || { echo "Failed to yum-builddep."; cat $BUILD_LOG; exit 1; }

# build rpm's
fedpkg local &> $BUILD_LOG || { echo "Failed to build glance packages."; cat $BUILD_LOG; exit 1; }
mkdir -p ~/rpms
find . -name "*rpm" -exec cp {} ~/rpms \\;

exit 0

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

    task :build_ubuntu_packages => :tarball do

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
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

ssh #{server_name} bash <<-"EOF_SERVER_NAME"

#add images
if [ ! -f /var/lib/glance/images_loaded ]; then
    mkdir -p /var/lib/glance/
    [ -f /root/openstackrc ] && source /root/openstackrc
    curl http://c3226372.r72.cf0.rackcdn.com/tty_linux.tar.gz | tar xvz -C /tmp/
    ARI_ID=`glance add name="ari-tty" type="ramdisk" disk_format="ari" container_format="ari" is_public=true < /tmp/tty_linux/ramdisk | tail -n 1 | sed 's/.*\: //g'`
    AKI_ID=`glance add name="aki-tty" type="kernel" disk_format="aki" container_format="aki" is_public=true < /tmp/tty_linux/kernel | tail -n 1 | sed 's/.*\: //g'`
    if glance add name="ami-tty" type="kernel" disk_format="ami" container_format="ami" ramdisk_id="$ARI_ID" kernel_id="$AKI_ID" is_public=true < /tmp/tty_linux/image; then
       touch /var/lib/glance/images_loaded
    fi
fi

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
