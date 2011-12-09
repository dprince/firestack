include ChefVPCToolkit::CloudServersVPC

desc "Test to make sure the Chef environment works."
task :chef_test do

	sg=ServerGroup.fetch(:source => "cache")
	gw_ip=sg.vpn_gateway_ip
	out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
knife client list | grep -c " chef-admin"
BASH_EOF
	}
	retval=$?
	puts out
	if not retval.success?
		fail "Chef Client/Server setup is invalid!"
	end

end
