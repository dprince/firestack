desc "Install and run Tempest."
task :tempest do

server_name=ENV['SERVER_NAME']
server_name = "nova1" if server_name.nil?
git_url=ENV['TEMPEST_GIT_URL']
git_url = "git://github.com/openstack/tempest.git" if git_url.nil?
image_name=ENV.fetch('TEMPEST_IMAGE_NAME', "ami-tty")

build_timeout=ENV['TEMPEST_BUILD_TIMEOUT'] || '600'
ssh_timeout=ENV['TEMPEST_SSH_TIMEOUT'] || '300'

# control Tempest tests we run
# NOTE: by default just 'compute' tests are enabled
test_compute=ENV['TEMPEST_TEST_COMPUTE'] || 'true'
test_image=ENV['TEMPEST_TEST_IMAGE'] || 'false'
test_identity=ENV['TEMPEST_TEST_IDENTITY'] || 'false'
test_network=ENV['TEMPEST_TEST_NETWORK'] || 'false'
test_object_storage=ENV['TEMPEST_TEST_OBJECT_STORAGE'] || 'false'
test_volume=ENV['TEMPEST_TEST_VOLUME'] || 'false'
test_boto=ENV['TEMPEST_TEST_BOTO'] || 'false'

puts "Running Tempest tests for:"
puts "  -compute" if test_compute == 'true'
puts "  -image" if test_image == 'true'
puts "  -identity" if test_identity == 'true'
puts "  -network" if test_network == 'true'
puts "  -object_storage" if test_object_storage == 'true'
puts "  -volume" if test_volume == 'true'
puts "  -boto(ec2)" if test_boto == 'true'
puts "--"

test_smoke=ENV['TEMPEST_SMOKE'] || 'false'

remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON_PKG}

install_package python-unittest2 python-paramiko euca2ools python-nose
install_git

NOSE_ARGS=""

[[ "#{test_compute}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e compute"
[[ "#{test_image}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e image"
[[ "#{test_identity}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e identity"
[[ "#{test_network}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e network"
[[ "#{test_object_storage}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e object_storage"
[[ "#{test_volume}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e volume"
[[ "#{test_boto}" != "true" ]] && NOSE_ARGS="$NOSE_ARGS -e boto"

[[ "#{test_smoke}" == "true" ]] && NOSE_ARGS="$NOSE_ARGS -a type=smoke"

[ -d "/root/tempest" ] || git clone #{git_url} "tempest"
if [ -f /root/openstackrc ]; then
  source /root/openstackrc
else
  configure_noauth
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
username=user1
password=DDEEFF445566
tenant_name=user1

alt_username=user2
alt_password=GGHHII778899
alt_tenant_name=user2

image_ref=$IMG_ID
image_ref_alt=$IMG_ID
flavor_ref=1
flavor_ref_alt=2

build_interval=10
build_timeout=#{build_timeout}
catalog_type=compute

create_image_enabled=true
resize_available=true
authentication=keystone_v2
ssh_timeout=#{ssh_timeout}

[image]
username=admin
password=AABBCC112233
tenant_name=admin

[compute-admin]
username=admin
password=AABBCC112233
tenant_name=admin

[identity-admin]
username=admin
password=AABBCC112233
tenant_name=admin
EOF_CAT

cd /root/tempest
nosetests tempest $NOSE_ARGS

EOF_SERVER_NAME
} do |ok, out|
    puts out
    fail "Tempest failed!" unless ok
end

end

