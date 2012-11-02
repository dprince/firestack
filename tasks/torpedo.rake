desc "Install and run Torpedo: Fast Openstack tests"
task :torpedo do

	server_name=ENV['SERVER_NAME']
	server_name = "nova1" if server_name.nil?
	mode=ENV['MODE'] # set to 'xen' or 'libvirt'
	mode = "libvirt" if mode.nil?
	xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output

	remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

if [ -f /bin/rpm ]; then
	rpm -q rubygems &> /dev/null || yum install -y rubygems &> /dev/null
	rpm -q rubygem-json &> /dev/null || yum install -y rubygem-json &> /dev/null
	if ruby -v | grep 1\.9\. &> /dev/null; then
		gem install --no-rdoc --no-ri test-unit
	fi
fi
if ! gem list | grep torpedo &> /dev/null; then
	gem install --no-rdoc --no-ri torpedo
	# Ubuntu fails to link it into /bin
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
if [[ "#{mode}" == "libvirt" ]]; then
	# When using libvirt we use an AMI style image which require keypairs
	export KEYPAIR="/root/test.pem"
	export KEYNAME="test"
	if [ -f /bin/rpm ]; then
		rpm -q euca2ools &> /dev/null || yum install -y euca2ools &> /dev/null
	else
		dpkg -l euca2ools &> /dev/null || apt-get install -q -y euca2ools &> /dev/null
	fi
	[ -f "$KEYPAIR" ] || euca-add-keypair "$KEYNAME" > "$KEYPAIR"
	chmod 600 /root/test.pem
	cat > ~/.torpedo.conf <<-EOF_CAT
		server_build_timeout: 180
		ssh_timeout: 60
		ping_timeout: 60
		keypair: $KEYPAIR
		keyname: $KEYNAME
		image_name: ami-tty
		test_rebuild_server: true
		test_create_image: false
		test_resize_server: false
		flavor_ref: 1
		sleep_after_image_create: 10
	EOF_CAT
elif [[ "#{mode}" == "xen" ]]; then
	cat > ~/.torpedo.conf <<-EOF_CAT
		ssh_timeout: 60
		ping_timeout: 60
		server_build_timeout: 420
		test_create_image: true
		test_rebuild_server: true
		test_resize_server: true
		test_admin_password: true
		test_soft_reboot_server: true
		test_hard_reboot_server: true
		sleep_after_image_create: 10
	EOF_CAT
else
	echo "Invalid mode specified."
fi
if [ -n "#{xunit_output}" ]; then
	torpedo fire --xml-report=torpedo.xml
else
	torpedo fire
fi
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Torpedo failed!" unless ok
        end

end
