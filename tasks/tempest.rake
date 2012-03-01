include ChefVPCToolkit::CloudServersVPC

desc "Run tempest."
task :tempest do

sg=ServerGroup.fetch(:source => "cache")
gw_ip=sg.vpn_gateway_ip
server_name=ENV['SERVER_NAME']
server_name = "nova1" if server_name.nil?
git_url=ENV['GIT_URL']
git_url = "git://github.com/openstack/tempest.git" if git_url.nil?
image_name=ENV.fetch('IMAGE_NAME', "ami-tty")
out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

for PKG in git python-unittest2 python-paramiko euca2ools python-nose; do
if [ -e /bin/rpm ]; then
  rpm -qi $PKG &> /dev/null || yum -y -q install $PKG &> /dev/null
else
  dpkg -l $PKG &> /dev/null || apt-get install -q -y $PKG &> /dev/null
fi
done

[ -d "/root/tempest" ] || git clone #{git_url} "tempest"
[ -f /root/novarc ] && source /root/novarc
[ -f /root/openstackrc ] && source /root/openstackrc

#Disable rate limiting middleware
sed -e 's| ratelimit||g' -i /etc/nova/api-paste.ini
if [ -e /bin/rpm ]; then
  service openstack-nova-api stop &> /dev/null
  service openstack-nova-api start
else
  service nova-api stop &> /dev/null
  service nova-api start
fi
sleep 2

IMG_ID=$(nova image-list | grep #{image_name} | tail -n 1 | sed -e "s|\\| \\([^ ]*\\) .*|\\1|")
[ -z "$IMG_ID" ] && { echo "Failed to set image ID."; exit 1; }
cat > /root/tempest/etc/tempest.conf <<EOF_CAT
[nova]
host=127.0.0.1
port=5000
apiVer=v2.0
path=tokens
user=admin
api_key=AABBCC112233
tenant_name=admin
ssh_timeout=300
build_interval=10
build_timeout=600
catalog_type=compute

[environment]
image_ref=$IMG_ID
image_ref_alt=$IMG_ID
flavor_ref=1
flavor_ref_alt=2
create_image_enabled=true
resize_available=false
authentication=keystone_v2
EOF_CAT

cd /root/tempest
nosetests tempest -a type=smoke

EOF_SERVER_NAME
BASH_EOF
}
retval=$?
puts out
fail "Tempest failed!" if not retval.success?
end

