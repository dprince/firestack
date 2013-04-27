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

        module_cmds = ""
        config["modules"].each do |mod|
            name = mod["name"]
            url = mod["url"]
            git_master = mod["git_master"]
            revision = mod["revision"]
            merge_master = mod["merge_master"] == "true" ? "true" : ""
            module_cmds += "checkout_module '#{name}' '#{git_master}' '#{url}' '#{revision}' '#{merge_master}'\n"
        end

        scp("#{KYTOON_PROJECT}/config/puppet-configs", "")

puts "Downloading puppet modules..."
        remote_exec %{
rm -rf puppet-modules
echo Getting Puppet modules from #{source_url}
git_clone_with_retry "#{source_url}" puppet-modules
cd ~/puppet-modules/modules
git checkout -q #{source_branch} || { echo "Failed to checkout #{source_branch}."; exit 1; }

function checkout_module {
  local PROJ_NAME=$1
  local GIT_MASTER=$2
  local SRC_URL=$3
  local SRC_BRANCH=$4
  local GIT_REVISION=$5
  local MERGE_MASTER=$6
  
  cd ~/puppet-modules/modules
  # remove any existing modules w/ this name
  rm -Rf "$PROJ_NAME"

  git_clone_with_retry "$GIT_MASTER" "$PROJ_NAME"
  cd "$PROJ_NAME"
  git fetch "$SRC_URL" "$SRC_BRANCH" || fail "Failed to git fetch branch $SRC_BRANCH."
  git checkout -q FETCH_HEAD || fail "Failed to git checkout FETCH_HEAD."
  if [ -n "$GIT_REVISION" ]; then
          git checkout $GIT_REVISION || \
                  fail "Failed to checkout revision $GIT_REVISION."
  else
          GIT_REVISION=$(git rev-parse --short HEAD)
          [ -z "$GIT_REVISION" ] && \
                  fail "Failed to obtain $PROJ_NAME revision from git."
  fi
  
  echo "${PROJ_NAME^^}_CONFIG_MODULE_REVISION=$GIT_REVISION"

  if [ -n "$MERGE_MASTER" ]; then
    git merge "$GIT_MASTER" || fail "Failed to merge $GIT_MASTER."
  fi

}

#{module_cmds}
cd ~
#run commands to scp modules and manifests here
#{node_cmds}
        } do |ok, out|
            if ok
              puts out
            else
              fail "Puppet errors occurred! \n #{out}"
            end
        end

puts "Running puppet apply on hostnames: " + hostnames.to_s

        results = remote_multi_exec hostnames, %{
# NOTE: we upgrade systemd due to a potential issue w/ the MySQL init scripts
rpm -q puppet &> /dev/null || yum -q -y install puppet yum-plugin-priorities systemd
ln -sf /root/puppet-modules/modules /etc/puppet/modules
puppet apply --verbose --detailed-exitcodes manifest.pp &> /var/log/puppet/puppet.log
RETVAL=$?
if [ "$RETVAL" -eq 1 -o "$RETVAL" -gt 2 ]; then
    cat /var/log/puppet/puppet.log; exit 1;
else
    exit 0;
fi
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Puppet errors on #{hostname}! \n #{out}\n"
        end
        fail err_msg unless err_msg == ""
         
    end
end

#desc "Rebuild and Re-run puppet the specified server."
task :repuppet => [ "server:rebuild", "group:poll" ] do
    remote_exec "rm .ssh/known_hosts"
    Rake::Task['puppet:install'].invoke
end
