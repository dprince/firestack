include ChefVPCToolkit::CloudServersVPC

namespace :nova do

    desc "Push source into a nova installation."
    task :install_source => :tarball do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        out=%x{
cd #{src_dir}
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/nova.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/share/pyshared
rm -Rf nova
tar xf /tmp/nova.tar.gz 2> /dev/null || { echo "Failed to extract nova source tar."; exit 1; }
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
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Install source failed!"
        end

    end

    desc "Ruby Openstack API v1.0 tests."
    task :ruby_osapi_tests do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        mode=ENV['MODE'] # set to 'xen' or 'libvirt'
        mode = "libvirt" if mode.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output

        out=%x{
MY_TMP="#{mktempdir}"
cd tests/ruby
tar czf $MY_TMP/ruby-tests.tar.gz * 2> /dev/null || { echo "Failed to create nova tar."; exit 1; }
scp #{SSH_OPTS} $MY_TMP/ruby-tests.tar.gz root@#{gw_ip}:/tmp/ruby-tests.tar.gz
rm -Rf "$MY_TMP"
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/ruby-tests.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
    if ! gem list | grep openstack-compute.*1.0.2 &> /dev/null; then
        gem install openstack-compute -v 1.0.2
    fi
    if ! gem list | grep test-unit-ext &> /dev/null; then
        gem install test-unit-ext -v 0.5.0
    fi
    [ -d ~/ruby-tests ] || mkdir ~/ruby-tests
    cd ruby-tests
    tar xzf /tmp/ruby-tests.tar.gz 2> /dev/null || { echo "Failed to excract ruby tests tar."; exit 1; }
    source /root/novarc
    if [ ! -f ~/.ssh/id_rsa ]; then
           [ -d ~/.ssh ] || mkdir ~/.ssh
           ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N "" || \
                   echo "Failed to create private key."

    fi
    if [[ "#{mode}" == "libvirt" ]]; then
        # When using libvirt we use an AMI style image which require keypairs
        export KEYPAIR="/root/test.pem"
        dpkg -l euca2ools &> /dev/null || apt-get install -q -y euca2ools &> /dev/null
        [ -f "$KEYPAIR" ] || euca-add-keypair test > "$KEYPAIR"
        chmod 600 /root/test.pem
        echo "export KEYPAIR='$KEYPAIR'" > test.env
    elif [[ "#{mode}" == "xen" ]]; then
        echo "export SSH_TIMEOUT='60'" > test.env
        echo "export PING_TIMEOUT='60'" >> test.env
        echo "export SERVER_BUILD_TIMEOUT='420'" >> test.env
        echo "export TEST_SNAPSHOT_IMAGE='true'" >> test.env
        echo "export TEST_REBUILD_INSTANCE='true'" >> test.env
        echo "export TEST_RESIZE_INSTANCE='true'" >> test.env
    else
        echo "Invalid mode specified."
    fi
    source test.env
    if [ -n "#{xunit_output}" ]; then
        ./run_tests.rb --xml-report=TEST-ruby.xml
    else
        ./run_tests.rb
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

    desc "Run the nova smoke tests."
    task :smoke_tests do
        if ENV['PLATFORM'] == "FEDORA" then
            Rake::Task["nova:smoke_tests_fedora"].invoke
        else
            Rake::Task["nova:smoke_tests_ubuntu"].invoke
        end
    end

    task :smoke_tests_fedora do
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

echo rm -rf /tmp/smoketests | ssh #{server_name} 
scp -r /root/openstack-nova/*/smoketests #{server_name}:/tmp

ssh #{server_name} bash <<-"EOF_SERVER_NAME"

yum install -y python-pip python-nose python-paramiko python-nova-adminclient

if [ -n "#{xunit_output}" ]; then
pip-python install nosexunit > /dev/null
export NOSE_WITH_NOSEXUNIT=true
fi

cd /tmp/smoketests

nova-manage floating create 172.20.0.0/24
nova-manage project zipfile nova admin
unzip -o nova.zip
source novarc

[ -f /root/novacreds/novarc ] && source /root/novacreds/novarc
if [ -f /root/openstackrc ]; then
    if ! grep EC2_SECRET_KEY /root/openstackrc &> /dev/null; then
        echo "export EC2_SECRET_KEY=\"admin\"" >> /root/openstackrc
    fi
    source /root/openstackrc
fi


#add images
if [ ! -f /var/lib/glance/images_loaded ]; then
    mkdir -p /var/lib/glance/
    [ -f /root/openstackrc ] && source /root/openstackrc
    curl http://c3226372.r72.cf0.rackcdn.com/tty_linux.tar.gz | tar xvz -C /tmp/
    ARI_ID=`glance add name="ari-tty" type="ramdisk" disk_format="ari" container_format="ari" is_public=true < /tmp/tty_linux/ramdisk | sed 's/.*\: //g'`
    AKI_ID=`glance add name="aki-tty" type="kernel" disk_format="aki" container_format="aki" is_public=true < /tmp/tty_linux/kernel | sed 's/.*\: //g'`
    if glance add name="ami-tty" type="kernel" disk_format="ami" container_format="ami" ramdisk_id="$ARI_ID" kernel_id="$AKI_ID" is_public=true < /tmp/tty_linux/image; then
       touch /var/lib/glance/images_loaded
    fi
fi

IMG_ID=$(euca-describe-images | grep ami | tail -n 1 | cut -f 2)
export PYTHONPATH=/tmp
python run_tests.py --test_image=$IMG_ID

EOF_SERVER_NAME
BASH_EOF
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Test task failed!"
        end


    end

    task :smoke_tests_ubuntu do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
[ -f /tmp/nova.tar.gz ] && scp /tmp/nova.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

if [ ! -d /root/nova_source ]; then
  if [ -f /tmp/nova.tar.gz ]; then
    mkdir nova_source && cd nova_source
    tar xzf /tmp/nova.tar.gz 2> /dev/null || { echo "Failed to extract nova source tar."; exit 1; }
    cd ..
  else
    dpkg -l git &> /dev/null || apt-get -y -q install git &> /dev/null
    git clone https://github.com/openstack/nova.git /root/nova_source
  fi
fi

dpkg -l euca2ools &> /dev/null || apt-get -y -q install euca2ools &> /dev/null
dpkg -l python-pip &> /dev/null || apt-get -y -q install python-pip &> /dev/null
pip install nova-adminclient > /dev/null

# FIXME: need to update nova-adminclient so it doesn't pip install boto 1.9
[[ "$(lsb_release -sc)" == "oneiric" ]] && rm -Rf /usr/local/lib/python2.7/dist-packages/boto*

if [ -n "#{xunit_output}" ]; then
pip install nosexunit > /dev/null
export NOSE_WITH_NOSEXUNIT=true
fi

if grep -c "VolumeTests" /root/nova_source/smoketests/test_sysadmin.py &> /dev/null; then
  sed -e '/class Volume/q' /root/nova_source/smoketests/test_sysadmin.py \
   | sed -e 's/^class VolumeTests.*//g' > tmp_test_sysadmin.py
  mv tmp_test_sysadmin.py /root/nova_source/smoketests/test_sysadmin.py
fi
cd /root/nova_source/smoketests
[ -f /root/novarc ] && source /root/novarc
if [ -f /root/openstackrc ]; then
	if ! grep EC2_SECRET_KEY /root/openstackrc &> /dev/null; then
        echo "export EC2_SECRET_KEY=\"admin\"" >> /root/openstackrc
    fi
    source /root/openstackrc
fi
IMG_ID=$(euca-describe-images | grep ami | tail -n 1 | cut -f 2)
python run_tests.py --test_image=$IMG_ID

EOF_SERVER_NAME
BASH_EOF
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Test task failed!"
        end

    end

    desc "Ruby Openstack API v1.1 tests."
    task :ruby_osapi_v11_tests do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        mode=ENV['MODE'] # set to 'xen' or 'libvirt'
        mode = "libvirt" if mode.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output

        out=%x{
MY_TMP="#{mktempdir}"
cd tests/ruby1.1
tar czf $MY_TMP/ruby-tests.tar.gz * 2> /dev/null || { echo "Failed to create nova tar."; exit 1; }
scp #{SSH_OPTS} $MY_TMP/ruby-tests.tar.gz root@#{gw_ip}:/tmp/ruby-tests.tar.gz
rm -Rf "$MY_TMP"
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/ruby-tests.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
    if ! gem list | grep openstack-compute.*1.1.1 &> /dev/null; then
        gem install openstack-compute -v 1.1.1
    fi
    if ! gem list | grep test-unit-ext &> /dev/null; then
        gem install test-unit-ext -v 0.5.0
    fi
    [ -d ~/ruby-tests ] || mkdir ~/ruby-tests
    cd ruby-tests
    tar xzf /tmp/ruby-tests.tar.gz 2> /dev/null || { echo "Failed to excract ruby tests tar."; exit 1; }
    source /root/novarc
    if [ ! -f ~/.ssh/id_rsa ]; then
           [ -d ~/.ssh ] || mkdir ~/.ssh
           ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N "" || \
                   echo "Failed to create private key."

    fi
    if [[ "#{mode}" == "libvirt" ]]; then
        # When using libvirt we use an AMI style image which require keypairs
        export KEYPAIR="/root/test.pem"
        export KEYNAME="test"
        dpkg -l euca2ools &> /dev/null || apt-get install -q -y euca2ools &> /dev/null
        [ -f "$KEYPAIR" ] || euca-add-keypair "$KEYNAME" > "$KEYPAIR"
        chmod 600 /root/test.pem
        echo "export KEYPAIR='$KEYPAIR'" > test.env
        echo "export KEYNAME='$KEYNAME'" >> test.env
        echo "export IMAGE_NAME='ami-tty'" >> test.env
    elif [[ "#{mode}" == "xen" ]]; then
        echo "export SSH_TIMEOUT='60'" > test.env
        echo "export PING_TIMEOUT='60'" >> test.env
        echo "export SERVER_BUILD_TIMEOUT='420'" >> test.env
        echo "export TEST_SNAPSHOT_IMAGE='true'" >> test.env
        echo "export TEST_REBUILD_INSTANCE='true'" >> test.env
        echo "export TEST_RESIZE_INSTANCE='true'" >> test.env
    else
        echo "Invalid mode specified."
    fi
    source test.env
    if [ -n "#{xunit_output}" ]; then
        ./run_tests.rb --xml-report=TEST-ruby.xml
    else
        ./run_tests.rb
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

    desc "Run stacktester tests."
    task :stacktester do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        server_name = "nova1" if server_name.nil?
        git_url=ENV['GIT_URL']
        git_url = "git://github.com/rackspace-titan/stacktester.git" if git_url.nil?
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
scp /tmp/ruby-tests.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
    dpkg -l git &> /dev/null || apt-get -y -q install git &> /dev/null
    dpkg -l python-unittest2 &> /dev/null || apt-get -y -q install python-unittest2 &> /dev/null
    dpkg -l python-paramiko &> /dev/null || apt-get -y -q install python-paramiko &> /dev/null
    [ -d "/root/stacktester" ] || git clone #{git_url}
    if [ ! -f "/usr/local/bin/stacktester" ]; then
        cd stacktester
        ./setup.py develop
    fi
    [ -f /root/novarc ] && source /root/novarc
    [ -f /root/openstackrc ] && source /root/openstackrc
    #FIXME: novaclient doesn't work with keystone yet but the EC2 API does.
    dpkg -l euca2ools &> /dev/null || apt-get install -q -y euca2ools &> /dev/null
    #IMG_ID=$(nova image-list | grep ACTIVE | tail -n 1 | sed -e "s|\\| \\([0-9]*\\)  .*|\\1|")
    IMG_ID=$(euca-describe-images | wc -l)
    if grep v2.0 /root/novarc &> /dev/null; then
      AUTH_BASE_PATH="v2.0"
    else
      AUTH_BASE_PATH="v1.0"
    fi
    cat > /etc/stacktester.cfg <<EOF_CAT
[nova]
host=127.0.0.1
port=8774
user=admin
auth_base_path=$AUTH_BASE_PATH
api_key=$NOVA_API_KEY
ssh_timeout=300
service_name=nova

[environment]
image_ref=$IMG_ID
image_ref_alt=$IMG_ID
flavor_ref=1
flavor_ref_alt=2
multi_node=false
EOF_CAT

    stacktester --config=/etc/stacktester.cfg --verbose

EOF_SERVER_NAME
BASH_EOF
    }
        retval=$?
        puts out
        fail "Test task failed!" if not retval.success?
    end

    desc "Build xen plugins rpm."
    task :build_rpms => :tarball do
        gw_ip = ServerGroup.fetch(:source => "cache").vpn_gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        nova_revision = get_revision(src_dir)
        raise "Failed to get nova revision." if nova_revision.empty?

        shh %{
            ssh #{SSH_OPTS} root@#{gw_ip} bash <<'BASH_EOF'
            set -e
            DEBIAN_FRONTEND=noninteractive apt-get -y -q install rpm createrepo > /dev/null
            mkdir -p /root/openstack-rpms
            BUILD_TMP=$(mktemp -d)
            cd "$BUILD_TMP"
            mkdir nova && cd nova
            tar xzf /tmp/nova.tar.gz &> /dev/null || { echo "Failed to extract nova source tar."; exit 1; }
            cd plugins/xenserver/xenapi/contrib
            chown -R root:root .
            perl -i -pe 's/^(Release:\s+).*/${1}#{nova_revision}/' rpmbuild/SPECS/openstack-xen-plugins.spec
            ./build-rpm.sh &> /dev/null
            cp rpmbuild/RPMS/noarch/*.rpm /root/openstack-rpms
            rm -rf "$BUILD_TMP"
BASH_EOF
        } do |ok, res|
            fail "Building rpms failed! \n #{res}" unless ok
        end
    end

    desc "Build packages from a local nova source directory."
    task :build_packages do
        if ENV['RPM_PACKAGER_URL'].nil? then
            Rake::Task["nova:build_ubuntu_packages"].invoke
        else
            Rake::Task["nova:build_fedora_packages"].invoke
        end
    end

    task :build_fedora_packages do
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-nova.git")
        packager_branch= ENV.fetch("RPM_PACKAGER_BRANCH", "master")
        src_url = ENV["SOURCE_URL"]
        src_branch = ENV.fetch("SOURCE_BRANCH", "master")
        raise "Please specify a SOURCE_URL." if src_url.nil?

        puts "Building nova packages using: #{packager_url}:#{packager_branch} #{src_url}:#{src_branch}"

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

yum install -y git fedpkg python-setuptools

BUILD_LOG=$(mktemp)

test -e openstack-nova && rm -rf openstack-nova
test -e nova_source && rm -rf nova_source

git clone #{src_url} nova_source || { echo "Unable to clone repos : #{src_url}"; exit 1; }
cd nova_source
[ #{src_branch} != "master" ] && { git checkout -t -b #{src_branch} origin/#{src_branch} || { echo "Unable to checkout branch :  #{src_branch}"; exit 1; } }
revision=$(date +%s)_$(git log --format=%h -n 1)
python setup.py sdist

cd 
git clone #{packager_url} openstack-nova || { echo "Unable to clone repos : #{packager_url}"; exit 1; }
cd openstack-nova
[ #{packager_branch} != "master" ] && { git checkout -t -b #{packager_branch} origin/#{packager_branch} || { echo "Unable to checkout branch :  #{packager_branch}"; exit 1; } }
cp ~/nova_source/dist/*.tar.gz .
sed -i.bk -e "s/\\(Release:.*\\.\\).*/\\1$revision/g" openstack-nova.spec
sed -i.bk -e "s/Source0:.*/Source0:      $(ls *.tar.gz)/g" openstack-nova.spec
md5sum *.tar.gz > sources 

# tmp workaround
sed -i.bk openstack-nova.spec -e 's/.*dnsmasq-utils.*//g'
sed -i.bk -e "s/%patch0002.*//g" openstack-nova.spec

# install dependencies
fedpkg srpm
yum-builddep -y *.src.rpm

# build rpm's
fedpkg local >> $BUILD_LOG || { echo "Failed to build nova packages."; cat $BUILD_LOG; exit 1; }
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
            deb_packager_url="lp:~openstack-ubuntu-packagers/nova/ubuntu"
        end

        nova_revision = get_revision(src_dir)
        raise "Failed to get nova revision." if nova_revision.empty?

        puts "Building nova packages using: #{deb_packager_url}"

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"


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

    desc "Tail nova logs."
    task :tail_logs do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?
        line_count=ENV['LINE_COUNT']
        line_count = 50 if line_count.nil?

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
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

    task :tarball do
        gw_ip = ServerGroup.fetch(:source => "cache").vpn_gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        nova_revision = get_revision(src_dir)
        raise "Failed to get nova revision." if nova_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f nova/flags.py ] \
                || { echo "Please specify a valid nova project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".nova-venv" ] && rm -Rf .nova-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/nova.tar.gz . 2> /dev/null || { echo "Failed to create nova source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/nova.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, res|
            fail "Unable to create nova tarball! \n #{res}" unless ok
        end
    end

end
