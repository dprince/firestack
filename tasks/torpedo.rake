desc "Install and run Torpedo: Fast Openstack tests"
task :torpedo do

	server_name=ENV['SERVER_NAME']
	server_name = "nova1" if server_name.nil?
	mode=ENV['MODE'] # set to 'xen' or 'libvirt'
	mode = "libvirt" if mode.nil?

	server_build_timeout=ENV['TORPEDO_SERVER_BUILD_TIMEOUT'] || '180'
	ssh_timeout=ENV['TORPEDO_SSH_TIMEOUT'] || '60'
	ping_timeout=ENV['TORPEDO_PING_TIMEOUT'] || '60'
	use_keypairs=ENV['TORPEDO_USE_KEYPAIRS'] || 'true'
	image_name=ENV['TORPEDO_IMAGE_NAME'] || '' #defaults to 1st in list
	test_create_image=ENV['TORPEDO_TEST_CREATE_IMAGE'] || 'false'
	test_rebuild_server=ENV['TORPEDO_TEST_REBUILD_SERVER'] || 'false'
	test_soft_reboot_server=ENV['TORPEDO_TEST_SOFT_REBOOT_SERVER'] || 'false'
	test_hard_reboot_server=ENV['TORPEDO_TEST_HARD_REBOOT_SERVER'] || 'false'
	test_admin_password=ENV['TORPEDO_TEST_ADMIN_PASSWORD'] || 'false'
	test_resize_server=ENV['TORPEDO_TEST_RESIZE_SERVER'] || 'false'
	test_revert_resize_server=ENV['TORPEDO_TEST_REVERT_RESIZE_SERVER'] || 'false'
	test_hostid_on_resize=ENV['TORPEDO_TEST_HOSTID_ON_RESIZE'] || 'false'
	flavor_ref=ENV['TORPEDO_FLAVOR_REF'] || '' #defaults to 2 (m1.small)
	sleep_after_image_create=ENV['TORPEDO_SLEEP_AFTER_IMAGE_CREATE'] || '10'

	remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON_PKG}

if [ -f /bin/rpm ]; then
	if [ -f /etc/fedora-release ]; then
		install_package rubygems
	fi
	install_package rubygem-json
	if ruby -v | grep 1\.9\. &> /dev/null; then
		gem install --no-rdoc --no-ri test-unit
	fi
fi
if ! gem list | grep torpedo &> /dev/null; then
	gem install --no-rdoc --no-ri torpedo
	# link it into /bin (some distros don't do this...)
	[ ! -f /usr/bin/torpedo ] && ln -sf /var/lib/gems/1.8/gems/torpedo-*/bin/torpedo /usr/bin/torpedo
fi
if [ -f /root/openstackrc ]; then
  source /root/openstackrc
else
  configure_noauth
  source ~/novarc
fi

if [ ! -f ~/.ssh/id_rsa ]; then
	   [ -d ~/.ssh ] || mkdir ~/.ssh
	   ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N "" || \
			   echo "Failed to create private key."
fi

cat > ~/.torpedo.conf <<-EOF_CAT
	server_build_timeout: #{server_build_timeout}
	ssh_timeout: #{ssh_timeout}
	ping_timeout: #{ping_timeout}
	image_name: #{image_name}
	test_rebuild_server: #{test_rebuild_server}
	test_create_image: #{test_create_image}
	test_resize_server: #{test_resize_server}
	test_revert_resize_server: #{test_revert_resize_server}
	test_hostid_on_resize: #{test_hostid_on_resize}
	test_soft_reboot_server: #{test_soft_reboot_server}
	test_hard_reboot_server: #{test_hard_reboot_server}
	test_admin_password: #{test_admin_password}
	flavor_ref: #{flavor_ref}
	sleep_after_image_create: #{sleep_after_image_create}
EOF_CAT

if [[ "#{use_keypairs}" == "true" ]]; then
	export KEYPAIR="/root/test.pem"
	export KEYNAME="test"
	[ -f "$KEYPAIR" ] || nova keypair-add "$KEYNAME" > "$KEYPAIR"
	chmod 600 "$KEYPAIR"

	cat >> ~/.torpedo.conf <<-EOF_CAT
		keypair: $KEYPAIR
		keyname: $KEYNAME
	EOF_CAT
fi

torpedo fire

EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Torpedo failed!" unless ok
        end

end
