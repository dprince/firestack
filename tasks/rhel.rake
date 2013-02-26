namespace :rhel do

    #generic package builder to build RPMs for all Openstack projects
    task :build_packages do

        project=ENV['PROJECT_NAME']
        raise "Please specify a PROJECT_NAME." if project.nil?

        packager_url=ENV['RPM_PACKAGER_URL']
        raise "Please specify a RPM_PACKAGER_URL." if packager_url.nil?

        packager_branch= ENV.fetch("RPM_PACKAGER_BRANCH", "master")

        git_master=ENV['GIT_MASTER']
        raise "Please specify a GIT_MASTER." if git_master.nil?

        #branch that will be merged if 'MERGE_MASTER' is specified
        merge_master_branch = ENV.fetch("GIT_MERGE_MASTER_BRANCH", "master")

        merge_master = ENV.fetch("MERGE_MASTER", "")
        git_revision = ENV.fetch("REVISION", "")
        src_url = ENV["SOURCE_URL"]
        src_branch = ENV.fetch("SOURCE_BRANCH", "master")
        build_docs = ENV.fetch("BUILD_DOCS", "")
        raise "Please specify a SOURCE_URL." if src_url.nil?
        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?
        cacheurl=ENV["CACHEURL"]

        puts "Building #{project} packages using: #{packager_url}:#{packager_branch} #{src_url}:#{src_branch}"

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}

# Test if the rpms we require are in the cache allready
# If present this function downloads them to ~/rpms
function download_cached_rpm {
    # disable caching for now
    return 1

    rpm -q git &> /dev/null || yum install -q -y git
    local PROJECT="$1"
    local SRC_URL="$2"
    local SRC_BRANCH="$3"
    local SRC_REVISION="$4"
    local PKG_URL="$5"
    local PKG_BRANCH="$6"

    SRCUUID=$SRC_REVISION
    if [ -z $SRCUUID ] ; then
        SRCUUID=$(git ls-remote "$SRC_URL" "$SRC_BRANCH" | cut -f 1)
        if [ -z $SRCUUID ] ; then
            echo "Invalid source URL:BRANCH $SRC_URL:$SRC_BRANCH"
            return 1
        fi
    fi
    PKGUUID=$(git ls-remote "$PKG_URL" "$PKG_BRANCH" | cut -f 1)
    if [ -z $PKGUUID ] ; then
        echo "Invalid package URL:BRANCH $PKG_URL:$PKG_BRANCH"
        return 1
    fi

    echo "Checking cache For $PKGUUID $SRCUUID"
    FILESFROMCACHE=$(curl $CACHEURL/rpmcache/$PKGUUID/$SRCUUID 2> /dev/null) \
      || { echo "No files in RPM cache."; return 1; }

    mkdir -p "${PROJECT}_cached_rpms"
    for file in $FILESFROMCACHE ; do
        HADFILE=1
        filename="${PROJECT}_cached_rpms/$(echo $file | sed -e 's/.*\\///g')"
        echo Downloading $file -\\> $filename
        curl $CACHEURL/$file 2> /dev/null > "$filename" || HADERROR=1
    done

    if [ -z "$HADERROR" -a -n "$HADFILE" ] ; then
        mkdir -p rpms
        cp "${PROJECT}_cached_rpms"/* rpms
        echo "$(echo $PROJECT | tr [:lower:] [:upper:])_REVISION=${SRCUUID:0:7}"
        return 0
    fi
    return 1
}

rpm -q rpm-build &> /dev/null || yum install -q -y git rpm-build python-setuptools

BUILD_LOG=$(mktemp)
SRC_DIR="#{project}_source"

CACHEURL=""
if [ -n "$CACHEURL" ] ; then
    download_cached_rpm #{project} "#{src_url}" "#{src_branch}" "#{git_revision}" "#{packager_url}" "#{packager_branch}" 
    test $? -eq 0 && { echo "Retrieved rpm's from cache" ; exit 0 ; }
fi

test -e openstack-#{project} && rm -rf openstack-#{project}
test -e $SRC_DIR && rm -rf $SRC_DIR

# if no .gitconfig exists create one (we may need it when merging below)
if [ ! -f ~/.gitconfig ]; then
cat > ~/.gitconfig <<-EOF_GIT_CONFIG_CAT
[user]
        name = OpenStack
        email = devnull@openstack.org
EOF_GIT_CONFIG_CAT
fi

git_clone_with_retry "#{git_master}" "$SRC_DIR"
cd "$SRC_DIR"
git fetch "#{src_url}" "#{src_branch}" || fail "Failed to git fetch branch #{src_branch}."
git checkout -q FETCH_HEAD || fail "Failed to git checkout FETCH_HEAD."
GIT_REVISION=#{git_revision}
if [ -n "$GIT_REVISION" ]; then
	git checkout $GIT_REVISION || \
		fail "Failed to checkout revision $GIT_REVISION."
else
	GIT_REVISION=$(git rev-parse --short HEAD)
	[ -z "$GIT_REVISION" ] && \
		fail "Failed to obtain #{project} revision from git."
fi
GIT_COMMITS_PROJECT="$(git log --pretty=format:'' | wc -l)"

echo "#{project.upcase}_REVISION=$GIT_REVISION"

if [ -n "#{merge_master}" ]; then
	git merge #{merge_master_branch} || fail "Failed to merge #{merge_master_branch}."
fi

PROJECT_NAME="#{project}"

SKIP_GENERATE_AUTHORS=1 SKIP_WRITE_GIT_CHANGELOG=1 python setup.py sdist &> $BUILD_LOG || { echo "Failed to run sdist."; cat $BUILD_LOG; exit 1; }

# determine version from tarball name
VERSION=$(ls dist/* | sed -e "s|.*$PROJECT_NAME-\\(.*\\)\\.tar.gz|\\1|")
echo "Tarball version: $VERSION"

cd 
git_clone_with_retry "#{packager_url}" "openstack-#{project}" || { echo "Unable to clone repos : #{packager_url}"; exit 1; }
cd openstack-#{project}
GIT_REVISION_INSTALLER="$(git rev-parse --short HEAD)"
SPEC_FILE_NAME=$(ls *.spec | head -n 1)
RPM_BASE_NAME=${SPEC_FILE_NAME:0:${#SPEC_FILE_NAME}-5}

[ #{packager_branch} != "master" ] && { git checkout -t -b #{packager_branch} origin/#{packager_branch} || { echo "Unable to checkout branch :  #{packager_branch}"; exit 1; } }
cp ~/$SRC_DIR/dist/*.tar.gz .
PACKAGE_REVISION="${GIT_COMMITS_PROJECT}.${GIT_REVISION:0:7}_${GIT_REVISION_INSTALLER:0:7}"
sed -i.bk -e "s/Release:.*/Release:0.1.$PACKAGE_REVISION/g" "$SPEC_FILE_NAME"
sed -i.bk -e "s/Source0:.*/Source0:      $(ls *.tar.gz)/g" "$SPEC_FILE_NAME"
sed -i.bk -e "s/%setup .*/%setup -q -n $PROJECT_NAME-$VERSION/g" "$SPEC_FILE_NAME"
[ -z "#{build_docs}" ] && sed -i -e 's/%global with_doc .*/%global with_doc 0/g' "$SPEC_FILE_NAME"
md5sum *.tar.gz > sources 

# custom version
sed -i.bk "$SPEC_FILE_NAME" -e "s/^Version:.*/Version:          $VERSION/g"

# Rip out patches
#sed -i.bk "$SPEC_FILE_NAME" -e 's|^%patch.*||g'

test -d ~/rpmbuild/SPECS || mkdir -p ~/rpmbuild/SPECS
cp $SPEC_FILE_NAME ~/rpmbuild/SPECS/
test -d ~/rpmbuild/SOURCES || mkdir -p ~/rpmbuild/SOURCES
cp * ~/rpmbuild/SOURCES/

# install dependency projects
rpmbuild -bs $SPEC_FILE_NAME &> $BUILD_LOG || { echo "Failed to build srpm."; cat $BUILD_LOG; exit 1; }
yum-builddep --nogpgcheck -y ~/rpmbuild/SRPMS/${RPM_BASE_NAME}-${VERSION}-*.src.rpm &> $BUILD_LOG || { echo "Failed to yum-builddep."; cat $BUILD_LOG; exit 1; }

# build rpm's
rpmbuild -bb $SPEC_FILE_NAME &> $BUILD_LOG || { echo "Failed to build #{project} packages."; cat $BUILD_LOG; exit 1; }
mkdir -p ~/rpms
find ~/rpmbuild -name "*rpm" -exec cp {} ~/rpms \\;

if ls ~/rpms/${RPM_BASE_NAME}*.noarch.rpm &> /dev/null; then
  rm $BUILD_LOG
  exit 0
else
  echo "Failed to build RPM: $RPM_BASE_NAME"
  cat $BUILD_LOG
  rm $BUILD_LOG
  exit 1
fi
EOF_SERVER_NAME
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            puts out
            fail "Failed to build packages for #{project}!" unless ok
        end

    end

    # uploader to rpm cache
    task :fill_cache do

        cacheurl=ENV["CACHEURL"]
        raise "Please specify a CACHEURL" if cacheurl.nil?
        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}
ls -d *_source || { echo "No RPMS to upload"; exit 0; }

for SRCDIR in $(ls -d *_source) ; do
    PROJECT=$(echo $SRCDIR | cut -d _ -f 1)
    echo Checking $PROJECT

    cd ~/$SRCDIR
    SRCUUID=$(git log -n 1 --pretty=format:%H)
    # If we're not at the head of master then we wont be caching
    [ $SRCUUID != $(cat .git/refs/heads/master) ] && continue

    cd ~/openstack-$PROJECT
    PKGUUID=$(git log -n 1 --pretty=format:%H)
    # If we're not at the head of master then we wont be caching
    [ $PKGUUID != $(cat .git/refs/heads/master) ] && continue

    URL=#{cacheurl}/rpmcache/$PKGUUID/$SRCUUID
    echo Cache : $PKGUUID $SRCUUID

    FILESWEHAVE=$(curl $URL 2> /dev/null)
    for file in $(find . -name "*rpm") ; do
        if [[ ! "$FILESWEHAVE" == *$(echo $file | sed -e 's/.*\\///g')* ]] ; then
            echo POSTING $file to $PKGUUID $SRCUUID
            curl -X POST $URL -Ffile=@$file 2> /dev/null || { echo ERROR POSTING FILE ; exit 1 ; }
        fi
    done
done
EOF_SERVER_NAME
        } do |ok, out|
            fail "Cache of packages failed!" unless ok
        end
    end

    desc "Create a local RPM repo using built packages."
    task :create_rpm_repo do

        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        puts "Creating RPM repo on #{server_name}..."
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}
yum -q -y install httpd

mkdir -p /var/www/html/repos/
rm -rf /var/www/html/repos/*
find ~/rpms -name "*rpm" -exec cp {} /var/www/html/repos/ \\;

createrepo /var/www/html/repos
if [ -f /etc/init.d/httpd ]; then
  /etc/init.d/httpd restart
else
  systemctl restart httpd.service
fi

EOF_SERVER_NAME
        } do |ok, out|
            fail "Failed to create RPM repo!" unless ok
        end

        sg=ServerGroup.get()
        puts "Creating yum repo config files..."
        results = remote_multi_exec sg.server_names, %{
echo -e "[openstack]\\nname=OpenStack RPM repo\\nbaseurl=http://#{server_name}/repos\\nenabled=1\\ngpgcheck=0\\npriority=1" > /etc/yum.repos.d/openstack.repo
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Errors creating Yum conf on #{hostname}. \n #{out}\n" unless ok
        end
        fail err_msg unless err_msg == ""

    end

    desc "Configure instances to use a remote RPM repo."
    task :configure_rpm_repo do

        # Default to using the upstream packages built by SmokeStack:
        #  http://repos.fedorapeople.org/repos/openstack/openstack-trunk/README
        repo_file_url=ENV['REPO_FILE_URL'] || "http://repos.fedorapeople.org/repos/openstack/openstack-trunk/fedora-openstack-trunk.repo"

        sg=ServerGroup.get()
        puts "Creating yum repo config files..."
        results = remote_multi_exec sg.server_names, %{
rpm -q yum-priorities &> /dev/null || yum -y -q install yum-priorities
cd /etc/yum.repos.d
wget #{repo_file_url}
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Errors creating Yum conf on #{hostname}. \n #{out}\n" unless ok
        end
        fail err_msg unless err_msg == ""

    end

    task :provision_vm do
        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        puts "Installing basic packages on #{server_name}..."
        remote_exec %{
bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}
cat > /etc/yum.repos.d/rhel.repo  <<-"EOF_RHEL_REPO"
[rhel]
name=Red Hat Enterprise Linux \$releasever - \$basearch - Base
baseurl=http://download.eng.blr.redhat.com/pub/rhel/rel-eng/RHEL6.4-20130123.0/6.4/Server/x86_64/os/
enabled=1
gpgcheck=0

[rhel-optional]
name=Red Hat Enterprise Linux \$releasever - \$basearch - Optional
baseurl=http://download.eng.blr.redhat.com/pub/rhel/rel-eng/RHEL6.4-20130123.0/6.4/Server/optional/x86_64/os/
enabled=1
gpgcheck=0

EOF_RHEL_REPO

cat > /etc/yum.repos.d/epel.repo  <<-"EOF_EPEL_REPO"
[epel]
name=Extra Packages for Enterprise Linux 6 - $basearch
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch
failovermethod=priority
enabled=1
gpgcheck=0

EOF_EPEL_REPO

rpm -q openssh-clients &> /dev/null || yum -q -y install openssh-clients
rpm -q yum-utils &> /dev/null || yum -q -y install yum-utils
rpm -q make &> /dev/null || yum -q -y install make

EOF_SERVER_NAME
        } do |ok, out|
            fail "Failed to install basic packages!" unless ok
        end
    end 

    task :build_nova do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/rhel-openstack/openstack-nova.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/nova.git"
        end
        ENV["PROJECT_NAME"] = "nova"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_python_novaclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-novaclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-novaclient.git"
        end
        ENV["PROJECT_NAME"] = "python-novaclient"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_glance do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-glance.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/glance.git"
        end
        ENV["PROJECT_NAME"] = "glance"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_python_glanceclient do

        # Now build python-glanceclient
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-glanceclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-glanceclient.git"
        end
        ENV["PROJECT_NAME"] = "python-glanceclient"
        Rake::Task["rhel:build_packages"].execute

    end

    task :build_keystone do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/rhel-openstack/openstack-keystone.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/keystone.git"
        end
        ENV["PROJECT_NAME"] = "keystone"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_python_keystoneclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-keystoneclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-keystoneclient.git"
        end
        ENV["PROJECT_NAME"] = "python-keystoneclient"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_swift do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-swift.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/swift.git"
        end
        ENV["PROJECT_NAME"] = "swift"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_python_swiftclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-swiftclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-swiftclient.git"
        end
        ENV["PROJECT_NAME"] = "python-swiftclient"
        Rake::Task["rhel:build_packages"].execute

    end

    task :build_cinder do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-cinder.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/cinder.git"
        end
        ENV["PROJECT_NAME"] = "cinder"
        Rake::Task["rhel:build_packages"].execute

    end

    task :build_python_cinderclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-cinderclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-cinderclient.git"
        end
        ENV["PROJECT_NAME"] = "python-cinderclient"
        Rake::Task["rhel:build_packages"].execute

    end

    task :build_quantum do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-quantum.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/quantum.git"
        end
        ENV["PROJECT_NAME"] = "quantum"
        Rake::Task["rhel:build_packages"].execute
    end

    task :build_python_quantumclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/openstack-python-quantumclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-quantumclient.git"
        end
        ENV["PROJECT_NAME"] = "python-quantumclient"
        Rake::Task["rhel:build_packages"].execute
    end

    # Warlock is a fairly new Glance requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_warlock do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/python-warlock.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/bcwaldon/warlock.git"
        end
        ENV["PROJECT_NAME"] = "warlock"
        ENV["SOURCE_URL"] = "git://github.com/bcwaldon/warlock.git"
        Rake::Task["rhel:build_packages"].execute

    end

    # Fedora 17 includes python-prettytable 0.5
    # Most openstack projects require > 0.6 so we build our own here.
    task :build_python_prettytable do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/fedora-python-prettytable.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dprince/python-prettytable.git"
        end
        ENV["PROJECT_NAME"] = "prettytable"
        ENV["SOURCE_BRANCH"] = "0.6"
        ENV["SOURCE_URL"] = "git://github.com/dprince/python-prettytable.git"
        Rake::Task["rhel:build_packages"].execute

    end

    # Stevedore is a fairly new Nova requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_stevedore do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/fedora-openstack/python-stevedore.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dreamhost/stevedore.git"
        end
        ENV["PROJECT_NAME"] = "stevedore"
        ENV["SOURCE_URL"] = "git://github.com/dreamhost/stevedore.git"
        Rake::Task["rhel:build_packages"].execute

    end

    task :build_misc do

        # Rake::Task["rhel:build_python_stevedore"].execute

        ENV["PROJECT_NAME"] = "prettytable"
        ENV["SOURCE_BRANCH"] = "0.6"
        ENV["SOURCE_URL"] = "git://github.com/dprince/python-prettytable.git"
        ENV["RPM_PACKAGER_URL"] = "git://github.com/dprince/fedora-python-prettytable.git"
        ENV["GIT_MASTER"] = "git://github.com/dprince/python-prettytable.git"
        Rake::Task["rhel:build_python_prettytable"].execute

    end

end
