desc "Install and run Fog tests for OpenStack"
task :fog do

	server_name=ENV['SERVER_NAME']
	server_name = "nova1" if server_name.nil?

        image_name=ENV.fetch('FOG_IMAGE_NAME', "ami-tty")
        flavor_ref=ENV.fetch('FOG_FLAVOR_REF', "1")
        passwd_check_enabled=ENV.fetch('FOG_PASSWORD_CHECK', "false")

        # By default we just run the compute tests
        shindo_tests=ENV.fetch('FOG_SHINDO_TESTS', "tests/openstack/requests/compute")

	remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}

if [ -f /bin/rpm ]; then
  for NAME in rubygems rubygem-builder rubygem-formatador rubygem-multi_json rubygem-nokogiri rubygem-shindo; do
    rpm -q $NAME &> /dev/null || yum install -y $NAME &> /dev/null
  done
fi

#install most recent excon (we want EXCON_DEBUG=1 support)
if ! gem list | grep excon &> /dev/null; then
  gem install --no-rdoc --no-ri excon
fi

if [ -f /root/openstackrc ]; then
  source /root/openstackrc
else
  configure_noauth
  source ~/novarc
fi

IMG_ID=$(nova image-list | grep #{image_name} | tail -n 1 | sed -e "s|\\| \\([^ ]*\\) .*|\\1|")

if [ ! -d fog ]; then
  git_clone_with_retry "git://github.com/fog/fog" "fog"
fi

cd fog

cat > tests/.fog <<-EOF_CAT
:default:
  :openstack_api_key: $OS_PASSWORD
  :openstack_username: $OS_USERNAME
  :openstack_tenant: $OS_TENANT_NAME
  :openstack_auth_url: ${OS_AUTH_URL}/tokens
EOF_CAT

echo "OPENSTACK_IMAGE_REF=$IMG_ID OPENSTACK_FLAVOR_REF=#{flavor_ref} OPENSTACK_SET_PASSWORD_ENABLED=#{passwd_check_enabled} shindont #{shindo_tests}" > run.sh
bash run.sh

EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Fog tests failed!" unless ok
        end

end
