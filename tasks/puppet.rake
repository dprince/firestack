
namespace :puppet do
    desc "Install Puppet server and clients"
    task :install do

        sg=ServerGroup.fetch(:source => "cache")

        gw_ip=sg.vpn_gateway_ip

        puppet_url=ENV['PUPPETMODULES_URL']
        raise "Please specify a PUPPETMODULES_URL." if puppet_url.nil?

        puppetclients = ""
        #FIXME: we need a config file to drive this...
        # For now run puppet on all servers in the group except login
        sg.servers.each do |client|
            puppetclients +=  client.name + " " if not client.name == "login"
        end

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
yum -q -y install httpd

mkdir -p /var/www/html/repos/
rm -rf /var/www/html/repos/*
find ~/rpms -name "*rpm" -exec cp {} /var/www/html/repos/ \\;

rm -rf puppet-modules
echo Getting Puppet modules from #{puppet_url}
git clone --recurse #{puppet_url} puppet-modules

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
puppet apply --verbose ~/puppet-modules/manifests/fedora.pp
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
