
namespace :puppet do
    desc "Install Puppet server and clients"
    task :install do

        sg=ServerGroup.fetch(:source => "cache")

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

        remote_exec %{
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
# NOTE: we upgrade systemd due to a potential issue w/ the MySQL init scripts
yum -q -y install puppet yum-plugin-priorities systemd
echo -e "[puppetserverrepos]\\nname=puppet server repository\\nbaseurl=http://login/repos\\nenabled=1\\ngpgcheck=0\\npriority=1" > /etc/yum.repos.d/puppetserverrepos.repo

ln -sf /root/puppet-modules/modules /etc/puppet/modules
puppet apply --verbose ~/puppet-modules/manifests/fedora_keystone_qpid_postgresql.pp &> /var/log/puppet/puppet.log || { cat /var/log/puppet/puppet.log; exit 1; }
SSH_EOF

done
        } do |ok, out|
            fail "Puppet errors occurred! \n #{out}" unless ok
        end
    end
end

#FIXME: Need to update the puppet:install task to support a single server
desc "Rebuild and Re-run puppet the specified server."
task :repuppet => [ "server:rebuild", "group:poll" ] do
    remote_exec "rm .ssh/known_hosts"
    Rake::Task['puppet:install'].invoke
end
