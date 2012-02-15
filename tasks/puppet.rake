
namespace :puppet do
    desc "Install Puppet server and clients"
    task :install do

        sg=ServerGroup.fetch(:source => "cache")

        gw_ip=sg.vpn_gateway_ip

        puppet_url=ENV['PUPPETMODULES_URL']
        raise "Please specify a puppet url." if puppet_url.nil?

        puppetclients = ""
        for i in 1..(sg.servers.size - 1)
            puppetclients +=  sg.servers[i].name + " "
        end

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

yum -y install httpd yum-plugin-priorities

mkdir -p /var/www/html/repos/
rm -rf /var/www/html/repos/*
find ~/rpms -name "*rpm" -exec cp {} /var/www/html/repos/ \\;

rm -rf puppetlabs-openstack
echo Getting Puppet modules from #{puppet_url}
git clone --recurse #{puppet_url}

createrepo /var/www/html/repos
/etc/init.d/httpd restart

for client in #{puppetclients}; do 
    scp -r puppetlabs-openstack $client:
    echo Running puppet client on : $client
    ssh $client bash <<- "SSH_EOF"
echo -e "[puppetserverrepos]\\nname=puppet server repository\\nbaseurl=http://login/repos\\nenabled=1\\ngpgcheck=0\\npriority=1" > /etc/yum.repos.d/puppetserverrepos.repo
yum -y install puppet

mkdir -p /etc/puppet/modules
cp -R ~/puppetlabs-openstack/modules/* /etc/puppet/modules/
puppet apply --verbose ~/puppetlabs-openstack/manifests/fedora.pp
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
            fail "Puppet Client/Server setup is invalid!"
        end
    end
end
