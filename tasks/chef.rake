include ChefVPCToolkit::CloudServersVPC

desc "Test to make sure the Chef environment works."
task :chef_test do

	sg=ServerGroup.fetch(:source => "cache")
	gw_ip=sg.vpn_gateway_ip
	out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
COUNT=0
for NAME in $(knife node list); do
  COUNT=$(( $COUNT + 1 ))
done
[ $COUNT -gt 0 ] || { echo "fail"; exit 1; }
knife client list | grep -c " chef-admin" > /dev/null
BASH_EOF
	}
	retval=$?
	puts out
	if not retval.success?
		fail "Chef Client/Server setup is invalid!"
	end

end
