include ChefVPCToolkit::CloudServersVPC

desc "Run tempest."
task :tempest do

server_name=ENV['SERVER_NAME']
server_name = "nova1" if server_name.nil?
git_url=ENV['GIT_URL']
git_url = "git://github.com/openstack/tempest.git" if git_url.nil?
image_name=ENV.fetch('IMAGE_NAME', "ami-tty")
remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

for PKG in git python-unittest2 python-paramiko euca2ools python-nose; do
if [ -e /bin/rpm ]; then
  rpm -qi $PKG &> /dev/null || yum -y -q install $PKG &> /dev/null
else
  dpkg -l $PKG &> /dev/null || apt-get install -q -y $PKG &> /dev/null
fi
done

[ -d "/root/tempest" ] || git clone #{git_url} "tempest"
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

IMG_ID=$(nova image-list | grep #{image_name} | tail -n 1 | sed -e "s|\\| \\([^ ]*\\) .*|\\1|")
[ -z "$IMG_ID" ] && { echo "Failed to set image ID."; exit 1; }
cat > /root/tempest/etc/tempest.conf <<EOF_CAT
[identity]
use_ssl=False
host=127.0.0.1
port=5000
api_version=v2.0
path=tokens
strategy=keystone

[compute]
username=admin
password=AABBCC112233
tenant_name=admin

alt_username=demo
alt_password=DDEEFF445566
alt_tenant_name=demo

image_ref=$IMG_ID
image_ref_alt=$IMG_ID
flavor_ref=1
flavor_ref_alt=2

build_interval=10
build_timeout=600
catalog_type=compute

create_image_enabled=true
resize_available=true
authentication=keystone_v2
ssh_timeout=300

[image]
username=admin
password=AABBCC112233
tenant_name=admin

[compute-admin]
# This section contains configuration options for an administrative
# user of the Compute API. These options are used in tests that stress
# the admin-only parts of the Compute API

username=admin
password=AABBCC112233
tenant_name=admin

EOF_CAT

cd /root/tempest
nosetests tempest -a type=smoke

EOF_SERVER_NAME
} do |ok, out|
    puts out
    fail "Tempest failed!" unless ok
end

end

