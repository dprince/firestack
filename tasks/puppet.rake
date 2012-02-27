
namespace :puppet do
    desc "Install Puppet server and clients"
    task :install do

        sg=ServerGroup.fetch(:source => "cache")

        gw_ip=sg.vpn_gateway_ip

        source_url=ENV['SOURCE_URL']
        raise "Please specify a SOURCE_URL." if source_url.nil?
        source_branch=ENV['SOURCE_BRANCH']
        source_branch = "master" if source_branch.nil?

        puppetclients = ""
        #FIXME: we need a config file to drive this...
        # For now run puppet on all servers in the group except login
        sg.servers.each do |client|
            puppetclients +=  client.name + " " if not client.name == "login"
        end

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
#{BASH_COMMON}
yum -q -y install httpd

mkdir -p /var/www/html/repos/
rm -rf /var/www/html/repos/*
find ~/rpms -name "*rpm" -exec cp {} /var/www/html/repos/ \\;

rm -rf puppet-modules
echo Getting Puppet modules from #{source_url}
git_clone_with_retry "#{source_url}" puppet-modules
pushd puppet-modules
git checkout #{source_branch}
popd

createrepo /var/www/html/repos
/etc/init.d/httpd restart

for client in #{puppetclients}; do 
    scp -r puppet-modules $client:
    echo Running puppet client on : $client
    ssh $client bash <<- "SSH_EOF"
yum -q -y install puppet yum-plugin-priorities
echo -e "[puppetserverrepos]\\nname=puppet server repository\\nbaseurl=http://login/repos\\nenabled=1\\ngpgcheck=0\\npriority=1" > /etc/yum.repos.d/puppetserverrepos.repo

mkdir -p /etc/puppet/modules
cp -R ~/puppet-modules/modules/* /etc/puppet/modules/
puppet apply --verbose ~/puppet-modules/manifests/fedora_keystone.pp | tee /var/log/puppet.out 2>&1
exit ${PIPESTATUS[0]} # exit with the exit code of puppet not tee
SSH_EOF

RETVAL=$? # return value from puppet agent
test \\( $RETVAL -ne 0  -a $RETVAL -ne 2 \\) && exit $RETVAL

done

echo COMPLETE

BASH_EOF
}
        retval=$?
        puts out
        if not retval.success?
            fail "Puppet errors occurred!"
        end
    end
end

#FIXME: Need to update the puppet:install task to support a single server
desc "Rebuild and Re-run puppet the specified server."
task :repuppet => [ "server:rebuild", "group:poll", "puppet:install" ]
