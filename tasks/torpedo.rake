include ChefVPCToolkit::CloudServersVPC

desc "Ruby tests for the v1.1 API."
task :torpedo do

	sg=ServerGroup.fetch(:source => "cache")
	gw_ip=sg.vpn_gateway_ip
	server_name=ENV['SERVER_NAME']
	# default to nova1 if SERVER_NAME is unset
	server_name = "nova1" if server_name.nil?
	mode=ENV['MODE'] # set to 'xen' or 'libvirt'
	mode = "libvirt" if mode.nil?
	xunit_output=ENV['XUNIT_OUTPUT'] # set if you want Xunit style output

	out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
if ! gem list | grep torpedo &> /dev/null; then
	gem install --no-rdoc --no-ri torpedo
	ln -sf /var/lib/gems/1.8/gems/torpedo-*/bin/torpedo /usr/bin/torpedo
fi
[ -f /root/novarc ] && source /root/novarc
if [ -f /root/openstackrc ]; then
	if ! grep EC2_SECRET_KEY /root/openstackrc &> /dev/null; then
		echo "export EC2_SECRET_KEY=\"admin\"" >> /root/openstackrc
	fi
	source /root/openstackrc
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
	dpkg -l euca2ools &> /dev/null || apt-get install -q -y euca2ools &> /dev/null
	[ -f "$KEYPAIR" ] || euca-add-keypair "$KEYNAME" > "$KEYPAIR"
	chmod 600 /root/test.pem
	cat > ~/.torpedo.conf <<-EOF_CAT
		server_build_timeout: 120
		keypair: $KEYPAIR
		keyname: $KEYNAME
		image_name: ami-tty
		test_rebuild_server: true
		flavor_ref: 1
	EOF_CAT
elif [[ "#{mode}" == "xen" ]]; then
	cat > ~/.torpedo.conf <<-EOF_CAT
		ssh_timeout: 60
		ping_timeout: 60
		server_build_timeout: 420
		test_create_image: true
		test_rebuild_server: true
		test_resize_server: true
		test_admin_password: false
		test_soft_reboot_server: true
		test_hard_reboot_server: true
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
BASH_EOF
	}
	retval=$?
	puts out
	if not retval.success?
		fail "Test task failed!"
	end

end
