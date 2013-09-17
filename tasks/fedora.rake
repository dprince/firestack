namespace :fedora do

    FEDORA_GIT_BASE="git://github.com/redhat-openstack"

    #generic package builder to build RPMs for all Openstack projects
    task :build_packages => :distro_name do

        project=ENV['PROJECT_NAME']
        raise "Please specify a PROJECT_NAME." if project.nil?

        packager_url=ENV['RPM_PACKAGER_URL'] || ENV['PACKAGER_URL']
        raise "Please specify a PACKAGER_URL." if packager_url.nil?

        packager_branch=ENV['RPM_PACKAGER_BRANCH'] || ENV['PACKAGER_BRANCH']
        if packager_branch.nil? then
          packager_branch='master'
        end

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
#{CACHE_COMMON}
install_package git rpm-build python-setuptools yum-utils make gcc

BUILD_LOG=$(mktemp)
SRC_DIR="#{project}_source"

CACHEURL="#{cacheurl}"
if [ -n "$CACHEURL" ] ; then
    download_cached_rpm "#{ENV['DISTRO_NAME']}" "#{project}" "#{src_url}" "#{src_branch}" "#{git_revision}" "#{packager_url}" "#{packager_branch}" 
    test $? -eq 0 && { echo "Retrieved rpm's from cache" ; exit 0 ; }
fi

test -e rpm_#{project} && rm -rf rpm_#{project}
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

# prep our rpmbuild tree
mkdir -p ~/rpmbuild/SPECS
mkdir -p ~/rpmbuild/SOURCES
rm -Rf ~/rpmbuild/RPMS/*
rm -Rf ~/rpmbuild/SRPMS/*

if [ -f setup.py ]; then
  SKIP_GENERATE_AUTHORS=1 SKIP_WRITE_GIT_CHANGELOG=1 python setup.py sdist &> $BUILD_LOG || { echo "Failed to run sdist."; cat $BUILD_LOG; exit 1; }
  # determine version from tarball name
  VERSION=$(ls dist/* | sed -e "s|.*$PROJECT_NAME-\\(.*\\)\\.tar.gz|\\1|")
  echo "Tarball version: $VERSION"
  cd dist
  SOURCE_FILE=$(ls *.tar.gz)
elif [ -f Rakefile ]; then
  install_package rubygems
  gem build *.gemspec
  # determine version from tarball name
  VERSION=$(ls *.gem | sed -e "s|.*$PROJECT_NAME-\\(.*\\)\\.gem|\\1|")
  echo "Gem version: $VERSION"
  SOURCE_FILE=$(ls *.gem)
fi
if [ -z "${SOURCE_FILE}" ]; then
   echo "Source not found, can not continue"
   exit 1
fi
cp $SOURCE_FILE ~/rpmbuild/SOURCES/
md5sum $SOURCE_FILE > sources
mv sources ~/rpmbuild/SOURCES/

cd 
git_clone_with_retry "#{packager_url}" "rpm_#{project}" || { echo "Unable to clone repos : #{packager_url}"; exit 1; }
cd rpm_#{project}
[ "#{packager_branch}" != "master" ] && { git checkout -t -b #{packager_branch} origin/#{packager_branch} || { echo "Unable to checkout branch :  #{packager_branch}"; exit 1; } }
GIT_REVISION_INSTALLER="$(git rev-parse --short HEAD)"
SPEC_FILE_NAME=$(ls *.spec | head -n 1)
RPM_BASE_NAME=${SPEC_FILE_NAME:0:-5}
PACKAGE_REVISION="${GIT_COMMITS_PROJECT}.${GIT_REVISION:0:7}_${GIT_REVISION_INSTALLER:0:7}"
sed -i.bk -e "s/Release:.*/Release:0.1.$PACKAGE_REVISION/g" "$SPEC_FILE_NAME"
sed -i.bk -e "s/Source0:.*/Source0:      $SOURCE_FILE/g" "$SPEC_FILE_NAME"
[ -z "#{build_docs}" ] && sed -i -e 's/%global with_doc .*/%global with_doc 0/g' "$SPEC_FILE_NAME"
cp $SPEC_FILE_NAME ~/rpmbuild/SPECS/
cp * ~/rpmbuild/SOURCES/

# custom version
sed -i.bk "$SPEC_FILE_NAME" -e "s/^Version:.*/Version:          $VERSION/g"

# clean any pre-existing RPMS dir (from previous build caching)
rm -Rf RPMS
rm -Rf SRPMS

#build source RPM
rpmbuild -bs $SPEC_FILE_NAME &>> $BUILD_LOG || { echo "Failed to build srpm."; cat $BUILD_LOG; exit 1; }

# install dependency projects
yum-builddep --nogpgcheck -y ~/rpmbuild/SRPMS/${RPM_BASE_NAME}-${VERSION}-*.src.rpm &>> $BUILD_LOG || { echo "Failed to yum-builddep."; cat $BUILD_LOG; exit 1; }

# build rpm's
rpmbuild -bb --nocheck $SPEC_FILE_NAME &>> $BUILD_LOG || { echo "Failed to build srpm."; cat $BUILD_LOG; exit 1; }

mkdir -p ~/rpms
find ~/rpmbuild -name "*rpm" -exec cp {} ~/rpms \\;
# keep a backup of RPMs within this project build dir for caching (if enabled)
mv ~/rpmbuild/RPMS .
mv ~/rpmbuild/SRPMS .

if ls ~/rpms/${RPM_BASE_NAME}*.noarch.rpm &> /dev/null || ls ~/rpms/${RPM_BASE_NAME}*.$(uname -m).rpm &> /dev/null; then
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

    task :fill_cache => 'cache:fill_cache'

    #desc "Configure the server group to use a set of mirrors."
    task :configure_package_mirrors do

        # Fedora mirror URLs
        fedora_updates_url=ENV['FEDORA_UPDATES_MIRROR']
        fedora_release_url=ENV['FEDORA_RELEASE_MIRROR']

        if fedora_updates_url or fedora_release_url then
          sg=ServerGroup.get()
          puts "Configuring RPM mirrors..."
          results = remote_multi_exec sg.server_names, %{
if [ -n "#{fedora_updates_url}" ]; then
cat > /etc/yum.repos.d/fedora-updates.repo <<-"EOF_YUM_UPDATES"
[updates]
name=Fedora $releasever - $basearch - Updates
failovermethod=priority
baseurl=#{fedora_updates_url}
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$basearch
EOF_YUM_UPDATES
fi

if [ -n "#{fedora_release_url}" ]; then
cat > /etc/yum.repos.d/fedora.repo <<-"EOF_YUM_RELEASE"
[fedora]
name=Fedora $releasever - $basearch
failovermethod=priority
baseurl=#{fedora_release_url}
enabled=1
metadata_expire=7d
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$basearch
EOF_YUM_RELEASE
fi
          }
          err_msg = ""
          results.each_pair do |hostname, data|
              ok = data[0]
              out = data[1]
              err_msg += "Errors configuring Yum mirror on #{hostname}. \n #{out}\n" unless ok
          end
          fail err_msg unless err_msg == ""
        end

    end

    # alias to :create_package_repo for compat
    task :create_rpm_repo => :create_package_repo

    #desc "Create a local RPM repo using built packages."
    task :create_package_repo do

        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        puts "Creating RPM repo on #{server_name}..."
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}
install_package httpd createrepo

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
        puts "Creating yum client repo config files..."
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

    #desc "Configure instances to use a remote RPM repo."
    task :configure_rpm_repo do

        # Default to using the upstream packages built by SmokeStack:
        #  http://repos.fedorapeople.org/repos/openstack/openstack-trunk/README
        repo_file_url=ENV['REPO_FILE_URL'] || "http://repos.fedorapeople.org/repos/openstack/openstack-trunk/redhat-openstack-trunk.repo"

        sg=ServerGroup.get()
        puts "Creating yum repo config files..."
        results = remote_multi_exec sg.server_names, %{
#{BASH_COMMON_PKG}
install_package yum-priorities
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

    task :build_nova do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-nova.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/nova.git"
        end
        ENV["PROJECT_NAME"] = "nova"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_novaclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-novaclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-novaclient.git"
        end
        ENV["PROJECT_NAME"] = "python-novaclient"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_glance do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-glance.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/glance.git"
        end
        ENV["PROJECT_NAME"] = "glance"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_glanceclient do

        # Now build python-glanceclient
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-glanceclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-glanceclient.git"
        end
        ENV["PROJECT_NAME"] = "python-glanceclient"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_keystone do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-keystone.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/keystone.git"
        end
        ENV["PROJECT_NAME"] = "keystone"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_keystoneclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-keystoneclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-keystoneclient.git"
        end
        ENV["PROJECT_NAME"] = "python-keystoneclient"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_swift do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-swift.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/swift.git"
        end
        ENV["PROJECT_NAME"] = "swift"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_oslo_config do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-oslo-config.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/oslo.config.git"
        end
        ENV['SOURCE_URL'] = 'git://github.com/openstack/oslo.config.git'
        ENV["PROJECT_NAME"] = "oslo.config"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_oslo_sphinx do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-oslo-sphinx.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/oslo.sphinx.git"
        end
        ENV['SOURCE_URL'] = 'git://github.com/openstack/oslo.sphinx.git'
        ENV["PROJECT_NAME"] = "oslo.sphinx"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_oslo_messaging do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-oslo-messaging.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/oslo.messaging.git"
        end
        ENV['SOURCE_URL'] = 'git://github.com/openstack/oslo.messaging.git'
        ENV["PROJECT_NAME"] = "oslo.messaging"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_swiftclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-swiftclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-swiftclient.git"
        end
        ENV["PROJECT_NAME"] = "python-swiftclient"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_cinder do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-cinder.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/cinder.git"
        end
        ENV["PROJECT_NAME"] = "cinder"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_cinderclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-cinderclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-cinderclient.git"
        end
        ENV["PROJECT_NAME"] = "python-cinderclient"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_neutron do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-neutron.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/neutron.git"
        end
        ENV["PROJECT_NAME"] = "neutron"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_quantumclient do
        puts "Use build_python_neutronclient instead."
    end

    task :build_python_neutronclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-neutronclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-neutronclient.git"
        end
        ENV["PROJECT_NAME"] = "python-neutronclient"
        Rake::Task["fedora:build_packages"].execute
    end

    # Warlock is a fairly new Glance requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_warlock do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-warlock.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/bcwaldon/warlock.git"
        end
        ENV["PROJECT_NAME"] = "warlock"
        ENV["SOURCE_URL"] = "git://github.com/bcwaldon/warlock.git"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_jsonpatch do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-jsonpatch.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/stefankoegl/python-json-patch.git"
        end
        ENV["PROJECT_NAME"] = "jsonpatch"
        ENV["SOURCE_URL"] = "git://github.com/stefankoegl/python-json-patch.git"
        ENV["SOURCE_BRANCH"] = "v0.12"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_jsonpointer do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-jsonpointer.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/stefankoegl/python-json-pointer.git"
        end
        ENV["PROJECT_NAME"] = "jsonpointer"
        ENV["SOURCE_URL"] = "git://github.com/stefankoegl/python-json-pointer.git"
        ENV["SOURCE_BRANCH"] = "v0.6"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_jsonschema do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-jsonschema.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/Julian/jsonschema.git"
        end
        ENV["PROJECT_NAME"] = "jsonschema"
        ENV["SOURCE_URL"] = "git://github.com/Julian/jsonschema.git"
        ENV["SOURCE_BRANCH"] = "v0.8.0"
        Rake::Task["fedora:build_packages"].execute

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
        Rake::Task["fedora:build_packages"].execute

    end

    # Stevedore is a fairly new Nova requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_stevedore do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/python-stevedore.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dreamhost/stevedore.git"
        end
        ENV["PROJECT_NAME"] = "stevedore"
        ENV["SOURCE_URL"] = "git://github.com/dreamhost/stevedore.git"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_cliff do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-cliff.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dreamhost/cliff.git"
        end
        ENV["PROJECT_NAME"] = "cliff"
        ENV["SOURCE_BRANCH"] = "1.3"
        ENV["SOURCE_URL"] = "git://github.com/dreamhost/cliff.git"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_pbr do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-pbr.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack-dev/pbr.git"
        end
        ENV["RPM_PACKAGER_BRANCH"] = "testing" #FIXME testing
        ENV["PROJECT_NAME"] = "pbr"
        ENV["SOURCE_URL"] = "git://github.com/openstack-dev/pbr.git"
        Rake::Task["fedora:build_packages"].execute

    end

    task :build_python_dogpile_cache do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/python-dogpile-cache.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        ENV["RPM_PACKAGER_BRANCH"] = "master"
        if ENV["GIT_MASTER"].nil?
            #ENV["GIT_MASTER"] = "https://bitbucket.org/zzzeek/dogpile.cache.git"
            ENV["GIT_MASTER"] = "git://github.com/dprince/dogpile.cache.git"
        end
        ENV["PROJECT_NAME"] = "dogpile.cache"
        #ENV["SOURCE_URL"] = "https://bitbucket.org/zzzeek/dogpile.cache.git"
        ENV["SOURCE_URL"] = "git://github.com/dprince/dogpile.cache.git"
        Rake::Task["fedora:build_packages"].execute

    end

    task  :build_ceilometer do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-ceilometer.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/ceilometer.git"
        end
        ENV["PROJECT_NAME"] = "ceilometer"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_ceilometerclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-ceilometerclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-ceilometerclient.git"
        end
        ENV["PROJECT_NAME"] = "python-ceilometerclient"
        Rake::Task["fedora:build_packages"].execute
    end

    task  :build_heat do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-heat.git")
        packager_branch= ENV.fetch("RPM_PACKAGER_BRANCH", "master")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        ENV["RPM_PACKAGER_BRANCH"] = packager_branch if ENV["RPM_PACKAGER_BRANCH"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/heat.git"
        end
        ENV["PROJECT_NAME"] = "heat"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_python_heatclient do
        packager_url= ENV.fetch("RPM_PACKAGER_URL", "#{FEDORA_GIT_BASE}/openstack-python-heatclient.git")
               packager_branch= ENV.fetch("RPM_PACKAGER_BRANCH", "master")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        ENV["RPM_PACKAGER_BRANCH"] = packager_branch if ENV["RPM_PACKAGER_BRANCH"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-heatclient.git"
        end
        ENV["PROJECT_NAME"] = "python-heatclient"
        Rake::Task["fedora:build_packages"].execute
    end

    task :build_misc do

        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        saved_env = ENV.to_hash
        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_pbr"].execute

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
yum install -y -q $(ls ~/rpms/python-pbr*.noarch.rpm | tail -n 1)
EOF_SERVER_NAME
}

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_oslo_sphinx"].execute

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
yum install -y -q $(ls ~/rpms/python-oslo-sphinx*.noarch.rpm | tail -n 1)
EOF_SERVER_NAME
}

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_dogpile_cache"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_stevedore"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_prettytable"].execute

        # Latest glanceclient requires the following for Warlock:
        # jsonpointer, jsonpatch, jsonschema (updated from 0.2)
        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_jsonschema"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_jsonpointer"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_jsonpatch"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_python_warlock"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_oslo_config"].execute

        ENV.clear
        ENV.update(saved_env)
        Rake::Task["fedora:build_oslo_messaging"].execute

    end

    task :build_fog do

      saved_env = ENV.to_hash

      ENV["RPM_PACKAGER_URL"] = "git://github.com/dprince/rubygem-excon.git"
      ENV["GIT_MASTER"] = "git://github.com/geemus/excon.git"
      ENV["PROJECT_NAME"] = "excon"
      # Nail it at 0.25.1
      ENV["REVISION"] = "93b3fd27833b66b5bcc82bf62f92bc0e8aa42c58"
      ENV["SOURCE_URL"] = "git://github.com/geemus/excon.git"
      Rake::Task["fedora:build_packages"].execute

      ENV.clear
      ENV.update(saved_env)

      ENV["RPM_PACKAGER_URL"] = "git://github.com/dprince/rubygem-fog.git"
      ENV["GIT_MASTER"] = "git://github.com/fog/fog.git"
      ENV["PROJECT_NAME"] = "fog"
      # Nail it right before unicode requirement
      ENV["REVISION"] = "95b353ff7ff223895b61a3f02bcac5f4a67130de"
      ENV["SOURCE_URL"] = "git://github.com/fog/fog.git"
      Rake::Task["fedora:build_packages"].execute

    end

    task :build_torpedo => :distro_name do

      packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://github.com/dprince/rubygem-torpedo.git")
      ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
      if ENV["GIT_MASTER"].nil?
        ENV["GIT_MASTER"] = "git://github.com/dprince/torpedo.git"
      end
      ENV["PROJECT_NAME"] = "torpedo"
      ENV["SOURCE_URL"] = "git://github.com/dprince/torpedo.git"
      Rake::Task["fedora:build_packages"].execute
    end

end
