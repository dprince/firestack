include ChefVPCToolkit::CloudServersVPC

desc "Ruby tests for the v1.1 API."
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
		test_resize_server: true
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
