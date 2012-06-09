include ChefVPCToolkit::CloudServersVPC

desc "Test to make sure the Chef environment works."
task :chef_test do

    remote_exec %{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
COUNT=0
for NAME in $(knife node list); do
  COUNT=$(( $COUNT + 1 ))
done
[ $COUNT -gt 0 ] || { echo "fail"; exit 1; }
knife client list | grep -c " chef-admin" > /dev/null
BASH_EOF
    } do |ok, out|
        fail "Chef Client/Server setup is invalid!" unless ok
    end

end
