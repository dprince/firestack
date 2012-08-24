require 'yaml'

namespace :puppet do
    desc "Install and configure packages on clients with puppet."
    task :install do

        source_url=ENV['SOURCE_URL']
        raise "Please specify a SOURCE_URL." if source_url.nil?
        source_branch=ENV['SOURCE_BRANCH']
        source_branch="master" if source_branch.nil?

        puppet_config=ENV['PUPPET_CONFIG']
        puppet_config="default" if puppet_config.nil?

        #specify if you only want to run puppet on a single server
        server_name=ENV['SERVER_NAME']

        config=YAML.load_file("#{KYTOON_PROJECT}/config/puppet-configs/#{puppet_config}/config.yml")
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

        scp("#{KYTOON_PROJECT}/config/puppet-configs", "")

puts "Downloading puppet modules..."
        remote_exec %{
rm -rf puppet-modules
echo Getting Puppet modules from #{source_url}
git_clone_with_retry "#{source_url}" puppet-modules
pushd puppet-modules
git checkout -q #{source_branch} || { echo "Failed to checkout #{source_branch}."; exit 1; }
popd

#run commands to scp modules and manifests here
#{node_cmds}
        } do |ok, out|
            fail "Puppet errors occurred! \n #{out}" unless ok
        end

puts "Running puppet apply on hostnames: " + hostnames.to_s

        results = remote_multi_exec hostnames, %{
# NOTE: we upgrade systemd due to a potential issue w/ the MySQL init scripts
rpm -q puppet &> /dev/null || yum -q -y install puppet yum-plugin-priorities systemd
ln -sf /root/puppet-modules/modules /etc/puppet/modules
puppet apply --verbose manifest.pp &> /var/log/puppet/puppet.log || { cat /var/log/puppet/puppet.log; exit 1; }
#FIXME remove nova-iptables.lock if it exists. (puppet restarts nova-network twice too quickly which sometimes causes it to create a lockfile which isn't deleted)
rm -f /var/lib/nova/tmp/nova-iptables.lock
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

#desc "Rebuild and Re-run puppet the specified server."
task :repuppet => [ "server:rebuild", "group:poll" ] do
    remote_exec "rm .ssh/known_hosts"
    Rake::Task['puppet:install'].invoke
end
