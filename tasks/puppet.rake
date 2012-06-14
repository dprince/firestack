require 'yaml'

namespace :puppet do
    desc "Install Puppet server and clients"
    task :install do

        source_url=ENV['SOURCE_URL']
        raise "Please specify a SOURCE_URL." if source_url.nil?
        source_branch=ENV['SOURCE_BRANCH']
        source_branch="master" if source_branch.nil?

        puppet_config=ENV['PUPPET_CONFIG']
        puppet_config="default" if puppet_config.nil?

        #specify if you only want to run puppet on a single server
        server_name=ENV['SERVER_NAME']

        config=YAML.load_file("#{CHEF_VPC_PROJECT}/config/puppet-configs/#{puppet_config}/config.yml")
        node_cmds = ""
        hostnames = []
        config["nodes"].each do |node|
            hostname = node["name"]
            manifest = node["manifest"]
            if server_name.nil? or server_name == hostname
                hostnames << hostname
                node_cmds += "scp -r puppet-modules #{hostname}: && scp puppet-configs/#{puppet_config}/#{manifest} #{hostname}:manifest.pp\n"
            end
        end

        scp("#{CHEF_VPC_PROJECT}/config/puppet-configs", "")

puts "Downloading puppet modules..."
        remote_exec %{
yum -q -y install httpd

mkdir -p /var/www/html/repos/
rm -rf /var/www/html/repos/*
find ~/rpms -name "*rpm" -exec cp {} /var/www/html/repos/ \\;

rm -rf puppet-modules
echo Getting Puppet modules from #{source_url}
git_clone_with_retry "#{source_url}" puppet-modules
pushd puppet-modules
git checkout -q #{source_branch} || { echo "Failed to checkout #{source_branch}."; exit 1; }
popd

createrepo /var/www/html/repos
if [ -f /etc/init.d/httpd ]; then
  /etc/init.d/httpd restart
else
  systemctl restart httpd.service
fi

#run commands to scp modules and manifests here
#{node_cmds}

        } do |ok, out|
            fail "Puppet errors occurred! \n #{out}" unless ok
        end

puts "Running puppet apply on hostnames: " + hostnames.to_s

        results = remote_multi_exec hostnames, %{
# NOTE: we upgrade systemd due to a potential issue w/ the MySQL init scripts
rpm -q puppet &> /dev/null || yum -q -y install puppet yum-plugin-priorities systemd
echo -e "[puppetserverrepos]\\nname=puppet server repository\\nbaseurl=http://login/repos\\nenabled=1\\ngpgcheck=0\\npriority=1" > /etc/yum.repos.d/puppetserverrepos.repo
ln -sf /root/puppet-modules/modules /etc/puppet/modules
puppet apply --verbose manifest.pp &> /var/log/puppet/puppet.log || { cat /var/log/puppet/puppet.log; exit 1; }
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Puppet errors on #{hostname}! \n #{out}\n" unless ok
        end
        fail err_msg unless err_msg == ""
         
    end
end

desc "Rebuild and Re-run puppet the specified server."
task :repuppet => [ "server:rebuild", "group:poll" ] do
    remote_exec "rm .ssh/known_hosts"
    Rake::Task['puppet:install'].invoke
end
