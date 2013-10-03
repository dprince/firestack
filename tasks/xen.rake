require "base64"

include Kytoon::Util

namespace :xen do

    desc "Install plugins into the XenServer dom0."
    task :install_plugins do

        source_url=ENV['SOURCE_URL']
        raise "Please specify a SOURCE_URL." if source_url.nil?
        source_branch=ENV['SOURCE_BRANCH']
        source_branch="master" if source_branch.nil?

        git_master=ENV['GIT_MASTER']
        git_master="git://github.com/openstack/nova.git" if git_master.nil?
        git_revision = ENV.fetch("REVISION", "")
        merge_master = ENV.fetch("MERGE_MASTER", "")
        merge_master_branch = ENV.fetch("GIT_MERGE_MASTER_BRANCH", "master")

        puts "Installing Xen plugins..."
        remote_exec %{
MY_TMP=$(mktemp -d)
rm -Rf nova_source

git_clone_with_retry "#{git_master}" nova_source
cd nova_source
git fetch "#{source_url}" "#{source_branch}" || fail "Failed to git fetch branch #{source_branch}."
git checkout -q FETCH_HEAD || fail "Failed to git checkout FETCH_HEAD."
GIT_REVISION=#{git_revision}
if [ -n "$GIT_REVISION" ]; then
        git checkout $GIT_REVISION || \
                fail "Failed to checkout revision $GIT_REVISION."
fi

if [ -n "#{merge_master}" ]; then

  # if no .gitconfig exists create one (we may need it when merging below)
  if [ ! -f ~/.gitconfig ]; then
cat > ~/.gitconfig <<-EOF_GIT_CONFIG_CAT
[user]
        name = OpenStack
        email = devnull@openstack.org
EOF_GIT_CONFIG_CAT
  fi

        git merge #{merge_master_branch} || fail "Failed to merge #{merge_master_branch}."
fi

[ -f nova/config.py ] || { echo "Please specify a top level nova project dir."; exit 1; }
cd plugins/xenserver/xenapi
tar czf $MY_TMP/plugins.tar.gz ./etc 2> /dev/null || { echo "Failed to create plugins source tar."; exit 1; }
cd /
tar xf $MY_TMP/plugins.tar.gz 2> /dev/null || { echo "Failed to extract plugins tar."; exit 1; }
chmod a+x /etc/xapi.d/plugins/*
sed -i -e "s/enabled=0/enabled=1/" /etc/yum.repos.d/CentOS-Base.repo
rpm -q parted &> /dev/null || yum install -y -q parted
        } do |ok, out|
            fail "Failed to install plugins. \n #{out}" unless ok
        end

    end

end
