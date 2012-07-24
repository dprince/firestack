namespace :nova do

    desc "Install local Nova source code into the group."
    task :install_source => :tarball do

        src_dir=ENV['SOURCE_DIR']
        raise "Please specify a SOURCE_DIR." if src_dir.nil?
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        remote_exec %{
scp /tmp/nova.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/lib/python2.7/site-packages
rm -Rf nova
tar xf /tmp/nova.tar.gz 2> /dev/null || { echo "Failed to extract nova source tar."; exit 1; }
service openstack-nova-api restart
service openstack-nova-compute restart
service openstack-nova-network restart
service openstack-nova-scheduler restart
service openstack-nova-cert restart
service openstack-nova-objectstore restart
EOF_SERVER_NAME
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            puts out
            fail "Install source failed!" unless ok
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
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output
        no_volume_tests=ENV['NO_VOLUME'] # set if you want disable Volume tests
        remote_exec %{
echo rm -rf /tmp/smoketests | ssh #{server_name} 

rpm -i rpms/openstack-nova*.src.rpm
cd /root/rpmbuild/SOURCES/
tar -xzf nova*.tar.gz
scp -r /root/rpmbuild/SOURCES/*/smoketests  #{server_name}:/tmp

ssh #{server_name} bash <<-"EOF_SERVER_NAME"

yum install -q -y python-pip python-nose python-paramiko python-nova-adminclient

if [ -n "#{xunit_output}" ]; then
pip-python install nosexunit > /dev/null
export NOSE_WITH_NOSEXUNIT=true
fi

if [ -f /root/openstackrc ]; then
  source /root/openstackrc
else
  #assume noauth is being used if no openstackrc is present
  cat > ~/novarc <<-EOF_CAT
NOVARC=$(readlink -f "${BASH_SOURCE:-${0}}" 2>/dev/null) ||
    NOVARC=$(python -c 'import os,sys; print os.path.abspath(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE:-${0}}")
NOVA_KEY_DIR=${NOVARC%/*}
export EC2_ACCESS_KEY="admin:admin"
export EC2_SECRET_KEY="91f4dacb-1aea-4428-97e1-f0ed631801f0"
export EC2_URL="http://127.0.0.1:8773/services/Cloud"
export S3_URL="http://127.0.0.1:3333"
export EC2_USER_ID=42 # nova does not use user id, but bundling requires it
#export EC2_PRIVATE_KEY=${NOVA_KEY_DIR}/pk.pem
#export EC2_CERT=${NOVA_KEY_DIR}/cert.pem
#export NOVA_CERT=${NOVA_KEY_DIR}/cacert.pem
export EUCALYPTUS_CERT=${NOVA_CERT} # euca-bundle-image seems to require this set
#alias ec2-bundle-image="ec2-bundle-image --cert ${EC2_CERT} --privatekey ${EC2_PRIVATE_KEY} --user 42 --ec2cert ${NOVA_CERT}"
#alias ec2-upload-bundle="ec2-upload-bundle -a ${EC2_ACCESS_KEY} -s ${EC2_SECRET_KEY} --url ${S3_URL} --ec2cert ${NOVA_CERT}"
export NOVA_API_KEY="admin"
export NOVA_USERNAME="admin"
export NOVA_PROJECT_ID="admin"
export NOVA_URL="http://127.0.0.1:8774/v1.1/"
export NOVA_VERSION="1.1"
EOF_CAT
  source ~/novarc
fi

[ -f "$HOME/cacert.pem" ] || nova x509-get-root-cert "$HOME/cacert.pem"
[ -f "$HOME/pk.pem" ] || nova x509-create-cert "$HOME/pk.pem" "$HOME/cert.pem"

cd /tmp/smoketests

#DISABLE_VOLUME_TESTS
if [ -n "#{no_volume_tests}" ]; then
  if grep -c "VolumeTests" test_sysadmin.py &> /dev/null; then
    sed -e '/class Volume/q' test_sysadmin.py \
     | sed -e 's/^class VolumeTests.*//g' > tmp_test_sysadmin.py
    mv tmp_test_sysadmin.py test_sysadmin.py
  fi
fi

IMG_ID=$(euca-describe-images | grep ami | tail -n 1 | cut -f 2)
export PYTHONPATH=/tmp
python run_tests.py --test_image=$IMG_ID

EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Test task failed!" unless ok
        end

    end

    task :smoke_tests_ubuntu do

        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output
        remote_exec %{
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
[ -f /root/openstackrc ] && source /root/openstackrc
IMG_ID=$(euca-describe-images | grep ami | tail -n 1 | cut -f 2)
python run_tests.py --test_image=$IMG_ID

EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Test task failed!" unless ok
        end

    end

    #Used only for XenServer
    #desc "Build xen plugins rpm."
    task :build_xen_rpms => :tarball do
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        nova_revision = get_revision(src_dir)
        raise "Failed to get nova revision." if nova_revision.empty?

        remote_exec %{
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
        } do |ok, out|
            puts out
            fail "Building rpms failed!" unless ok
        end
    end

    desc "Build Nova packages."
    task :build_packages do
        if ENV['RPM_PACKAGER_URL'].nil? then
            Rake::Task["nova:build_ubuntu_packages"].invoke
        else
            Rake::Task["nova:build_fedora_packages"].invoke
        end
    end

    task :build_fedora_packages do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-nova.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/nova.git"
        end
        ENV["PROJECT_NAME"] = "nova"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :build_python_novaclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/python-novaclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-novaclient.git"
        end
        ENV["PROJECT_NAME"] = "python-novaclient"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :build_ubuntu_packages => :tarball do

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

    desc "Tail nova logs."
    task :tail_logs do

        server_name=ENV['SERVER_NAME']
        raise "Please specify a SERVER_NAME." if server_name.nil?
        line_count=ENV['LINE_COUNT']
        line_count = 50 if line_count.nil?

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
tail -n #{line_count} /var/log/nova/*
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Tail logs failed!" unless ok
        end

    end

    task :tarball do
        gw_ip = ServerGroup.get(:source => "cache").vpn_gateway_ip
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
