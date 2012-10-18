namespace :nova do

    #desc "Install local Nova source code into the group."
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
    task :smoke_tests => :distro_name do
        Rake::Task["nova:smoke_tests_#{ENV['DISTRO_NAME']}"].invoke
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

#patch volume tests to wait a bit longer for instances to recognize volumes
patch --quiet test_sysadmin.py <<"EOF_PATCH"
@@ -250,7 +250,7 @@ class VolumeTests(base.UserSmokeTestCase):
         self.assertTrue(volume.status.startswith('in-use'))
 
         # Give instance time to recognize volume.
-        time.sleep(5)
+        time.sleep(10)
 
     def test_003_can_mount_volume(self):
         ip = self.data['instance'].private_ip_address
EOF_PATCH

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
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_nova"].invoke
    end

    desc "Build Python Novaclient packages."
    task :build_python_novaclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_novaclient"].invoke
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
        gw_ip = ServerGroup.get.gateway_ip
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
