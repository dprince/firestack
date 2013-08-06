namespace :opensuse do

    #generic package builder to build RPMs for all Openstack projects
    task :build_packages do

        project=ENV['PROJECT_NAME']
        raise "Please specify a PROJECT_NAME." if project.nil?

        obs_username = ENV['OBS_USERNAME']
        raise "Please specify a OBS_USERNAME." if obs_username.nil?
        obs_password = ENV['OBS_PASSWORD']
        raise "Please specify a OBS_PASSWORD." if obs_password.nil?

        obs_package = ENV['OBS_PACKAGE']
        raise "Please specify a OBS_PACKAGE." if obs_package.nil?

        obs_apiurl = ENV.fetch("OBS_APIURL", "https://api.opensuse.org")
        obs_project = ENV.fetch("OBS_PROJECT", "Cloud:OpenStack:Master")
        obs_target = ENV.fetch("OBS_TARGET", "openSUSE_12.2")
        obs_use_git_tarballs = ENV.fetch("OBS_USE_GIT_TARBALLS", "")

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

        puts "Building #{project} packages using: #{obs_apiurl}/source/#{obs_project}/#{obs_package} #{src_url}:#{src_branch}"

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}

FIRESTACK_EMAIL=devnull@devstack.org
BUILD_LOG=$(mktemp)
mkdir -p sources
mkdir -p sources-rpms
SRC_DIR="${HOME}/sources/#{project}"
PKG_DIR="${HOME}/sources-rpms/#{project}"
OSC_CACHE_DIR=/root/.osc_repo_cache

function osc_clone_with_retry {
    local APIURL=${1:?"Please specify a APIURL."}
    local PRJ=${2:?"Please specify a PRJ."}
    local PKG=${3:?"Please specify a PKG."}
    local DIR=${4:?"Please specify a DIR."}
    local URLSHA=$(echo \"$APIURL\" | sha1sum | cut -f 1 -d ' ')
    local APIURL_CACHE_DIR="${OSC_CACHE_DIR}/${URLSHA}"
    local PKG_CACHE_DIR="${APIURL_CACHE_DIR}/${PRJ}/${PKG}"
    [ -d "$APIURL_CACHE_DIR" ] || mkdir -p "$APIURL_CACHE_DIR"
    if [ -d "$PKG_CACHE_DIR" ]; then
        echo "Using osc cache..."
        pushd "$PKG_CACHE_DIR" > /dev/null
        osc update &> /dev/null
        popd > /dev/null
        cp -a "$PKG_CACHE_DIR" "$DIR"
    else
        local COUNT=1
        local ECHO_URL="$APIURL/source/$PRJ/$PKG"
        echo "Checking out from: $ECHO_URL"
        pushd "$APIURL_CACHE_DIR" > /dev/null
        until osc checkout "$PRJ" "$PKG" &> /dev/null; do
            [ "$COUNT" -eq "4" ] && fail "Failed to checkout: $ECHO_URL"
            sleep $(( $COUNT * 5 ))
            COUNT=$(( $COUNT + 1 ))
        done
        popd > /dev/null
        cp -a "$PKG_CACHE_DIR" "$DIR"
    fi
}

# Test if the rpms we require are in the cache already
# If present this function downloads them to ~/rpms
function download_cached_rpm {
    local PROJECT="$1"
    local SRC_URL="$2"
    local SRC_BRANCH="$3"
    local SRC_REVISION="$4"
    local OBS_PROJECT="$5"
    local OBS_PACKAGE="$6"

    SRCUUID=$SRC_REVISION
    if [ -z $SRCUUID ] ; then
        SRCUUID=$(git ls-remote "$SRC_URL" "$SRC_BRANCH" | cut -f 1)
        if [ -z $SRCUUID ] ; then
            echo "Invalid source URL:BRANCH $SRC_URL:$SRC_BRANCH"
            return 1
        fi
    fi
    PKGUUID=$(osc api "/source/$OBS_PROJECT/$OBS_PACKAGE" | head -n 1 .osc/_files | sed 's/.*srcmd5="//g;s/".*//g')
    if [ -z $PKGUUID ] ; then
        echo "Invalid package $OBS_PROJECT/$OBS_PACKAGE"
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


### Get rpm from cache if we already have it

install_package git-core
install_package osc

# overwrite ~/.oscrc to have the correct apiurl/username/password
cat > ~/.oscrc <<-EOF_OSCRC_CAT
[general]
apiurl = #{obs_apiurl}
[#{obs_apiurl}]
user = #{obs_username}
pass = #{obs_password}
trusted_prj = openSUSE:Factory openSUSE:12.2 Cloud:OpenStack:Essex Cloud:OpenStack:Folsom
EOF_OSCRC_CAT

CACHEURL="#{cacheurl}"
if [ -n "$CACHEURL" ] ; then
    download_cached_rpm #{project} "#{src_url}" "#{src_branch}" "#{git_revision}" "#{obs_project}" "#{obs_package}"
    test $? -eq 0 && { echo "Retrieved rpms from cache" ; exit 0 ; }
fi


### Fetch upstream & rpm sources

test -e $SRC_DIR && rm -rf $SRC_DIR
test -e $PKG_DIR && rm -rf $PKG_DIR

git_clone_with_retry "#{git_master}" "$SRC_DIR"
osc_clone_with_retry "#{obs_apiurl}" "#{obs_project}" "#{obs_package}" "${PKG_DIR}" || { echo "Unable to checkout #{obs_project}/#{obs_package}"; exit 1; }


### Create tarball from git

install_package python-distribute

# if no .gitconfig exists create one (we may need it when merging below)
if [ ! -f ~/.gitconfig ]; then
cat > ~/.gitconfig <<-EOF_GIT_CONFIG_CAT
[user]
        name = OpenStack
        email = ${FIRESTACK_EMAIL}
EOF_GIT_CONFIG_CAT
fi

cd "${SRC_DIR}"

git fetch "#{src_url}" "#{src_branch}" &> /dev/null || fail "Failed to git fetch branch #{src_branch}."
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
GIT_DATE=$(git log -n1 --pretty=format:"%ct")

echo "#{project.upcase}_REVISION=$GIT_REVISION"

if [ -n "#{merge_master}" ]; then
	git merge #{merge_master_branch} || fail "Failed to merge #{merge_master_branch}."
fi

PROJECT_NAME="#{project}"

SKIP_GENERATE_AUTHORS=1 python setup.py sdist &> $BUILD_LOG || { echo "Failed to run sdist."; cat $BUILD_LOG; exit 1; }

# determine version from tarball name
VERSION=$(ls dist/* | sed -e "s|.*$PROJECT_NAME-\\(.*\\)\\.tar.gz|\\1|")
TARBALL="$SRC_DIR/$(ls dist/*.tar.gz)"
echo "Tarball version: $VERSION"


### Prepare packaging bits

cd "${PKG_DIR}"

OSC_REVISION=$(head -n 1 .osc/_files | sed 's/.*srcmd5="//g;s/".*//g')
OSC_MTIME=$(grep 'mtime="' .osc/_files | sed 's/.*mtime="//g;s/".*//g' | sort | tail -n 1)
SPEC_FILE_NAME="#{obs_package}.spec"
CHANGES_FILE_NAME="#{obs_package}.changes"
RPM_BASE_NAME=${SPEC_FILE_NAME:0:-5}

if [ "x#{obs_use_git_tarballs}" == "x1" ]; then
    # FIXME: Temporary until obs-service-git_tarballs package is available on all supported distros
    rm -rf obs-service-git_tarballs
    pushd "${HOME}" > /dev/null
    git_clone_with_retry "https://github.com/openSUSE/obs-service-git_tarballs.git" "obs-service-git_tarballs"
    popd

    ~/obs-service-git_tarballs/git_tarballs --url "$TARBALL" --package "#{obs_package}" --email ${FIRESTACK_EMAIL}

    # git_tarballs uses now() as timestamp in version, let's use the last git commit date
    sed -i -e "s/^\\(Version:.*\\+git\\.\\)[0-9]*\\(\\..*\\)$/\\1${GIT_DATE}\\2/g" "$SPEC_FILE_NAME"
else
    cp "$TARBALL" .
    SOURCE=$(basename "$TARBALL")
    # Make osc happy about new tarball
    osc addremove &> /dev/null

    sed -i -e "s/Source0\\?:.*/Source0:        ${SOURCE}/g" "$SPEC_FILE_NAME"
    sed -i -e "s/^Version:.*/Version:        ${VERSION}+git.${GIT_DATE}.${GIT_REVISION:0:7}/g" "$SPEC_FILE_NAME"
    # Fixup different %setup as much as we can
    sed -i -e "s/^\\(%setup.*\\)%{version}\\(.*\\)$/\\1${VERSION}\\2/g" "$SPEC_FILE_NAME"
    sed -i -e "s/^%setup -q$/%setup -q -n %{name}-${VERSION}/g" "$SPEC_FILE_NAME"
    sed -i -e "s/^%setup$/%setup -q -n %{name}-${VERSION}/g" "$SPEC_FILE_NAME"
fi

PACKAGE_REVISION="${OSC_MTIME}.${OSC_REVISION:0:7}"
sed -i -e "s/^Release:.*/Release:        0.$PACKAGE_REVISION/g" "$SPEC_FILE_NAME"

# TODO-vuntz: this is not how we build docs on openSUSE
[ -z "#{build_docs}" ] && sed -i -e 's/%global with_doc .*/%global with_doc 0/g' "$SPEC_FILE_NAME"

# Rip out patches
sed -i "$SPEC_FILE_NAME" -e 's|^%patch.*||g'

cat > "$CHANGES_FILE_NAME".tmp <<-EOF_CHANGES_CAT
--------------------------------------------------------------------
`TZ=UTC LC_ALL=C date` - ${FIRESTACK_EMAIL}

- Firestack automatic packaging of $VERSION (${GIT_REVISION:0:7}).

EOF_CHANGES_CAT
cat "$CHANGES_FILE_NAME" >> "$CHANGES_FILE_NAME".tmp
mv "$CHANGES_FILE_NAME".tmp "$CHANGES_FILE_NAME"

# build rpm's
export OSC_BUILD_ROOT="/var/tmp/build-root-#{obs_target}"
osc build "$SPEC_FILE_NAME" "#{obs_target}" &> $BUILD_LOG || { echo "Failed to build #{project} packages."; cat $BUILD_LOG; exit 1; }
mkdir -p ~/rpms
find "${OSC_BUILD_ROOT}/home/abuild/rpmbuild/"{RPMS,SRPMS} -name "*rpm" -exec cp {} ~/rpms \\;

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
ls -d sources/* || { echo "No RPMS to upload"; exit 0; }

for SRCDIR in $(ls -d sources/*) ; do
    PROJECT=$(basename $SRCDIR)
    echo Checking $PROJECT

    cd ~/$SRCDIR
    SRCUUID=$(git log -n 1 --pretty=format:%H)
    # If we're not at the head of master then we wont be caching
    [ $SRCUUID != $(cat .git/refs/heads/master) ] && continue

    cd ~/sources-rpms/$PROJECT
    PKGUUID=$(head -n 1 .osc/_files | sed 's/.*srcmd5="//g;s/".*//g')

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

    #desc "Configure the server group to use a set of mirrors."
    task :configure_package_mirrors do
	# the way the openSUSE infrastructure is setup, closest mirror is
	# always chosen. This is good enough.
    end

    # alias to :create_package_repo for compat
    task :create_rpm_repo => :create_package_repo

    desc "Create a local RPM repo using built packages."
    task :create_package_repo do

        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        puts "Creating RPM repo on #{server_name}..."
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}

install_package apache2
install_package createrepo

mkdir -p /srv/www/htdocs/repos/
rm -rf /srv/www/htdocs/repos/*
find ~/rpms -name "*rpm" -exec cp -a {} /srv/www/htdocs/repos/ \\;

createrepo /srv/www/htdocs/repos

# Allow indexing in what we publish with www
sed -i -e "s/Options None/Options +Indexes/g" /etc/apache2/default-server.conf

/sbin/service apache2 restart

EOF_SERVER_NAME
        } do |ok, out|
            fail "Failed to create RPM repo!" unless ok
        end

        sg=ServerGroup.get()
        puts "Creating RPM client repo config files..."
        results = remote_multi_exec sg.server_names, %{
echo -e "[firestack]\\nname=OpenStack (Firestack)\\nbaseurl=http://#{server_name}/repos\\nenabled=1\\nautorefresh=1\\ngpgcheck=0\\npriority=1" > /etc/zypp/repos.d/firestack.repo
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Errors creating RPM repo config file on #{hostname}. \n #{out}\n" unless ok
        end
        fail err_msg unless err_msg == ""

    end

    #desc "Configure instances to use a remote RPM repo."
    task :configure_rpm_repo do

        # Default to using the upstream packages built by SmokeStack:
        #  http://repos.fedorapeople.org/repos/openstack/openstack-trunk/README
        #TODO-vuntz
        repo_file_url=ENV['REPO_FILE_URL'] || "http://repos.fedorapeople.org/repos/openstack/openstack-trunk/fedora-openstack-trunk.repo"

        sg=ServerGroup.get()
        puts "Creating RPM repo config files..."
        results = remote_multi_exec sg.server_names, %{
cd /etc/zypp/repos.d
wget #{repo_file_url}
        }

        err_msg = ""
        results.each_pair do |hostname, data|
            ok = data[0]
            out = data[1]
            err_msg += "Errors creating RPM repo config file on #{hostname}. \n #{out}\n" unless ok
        end
        fail err_msg unless err_msg == ""

    end

    task :build_nova do
        ENV["OBS_PACKAGE"] = "openstack-nova" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/nova.git"
        end
        ENV["PROJECT_NAME"] = "nova"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_novaclient do
        ENV["OBS_PACKAGE"] = "python-novaclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-novaclient.git"
        end
        ENV["PROJECT_NAME"] = "python-novaclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_glance do
        ENV["OBS_PACKAGE"] = "openstack-glance" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/glance.git"
        end
        ENV["PROJECT_NAME"] = "glance"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_glanceclient do
        ENV["OBS_PACKAGE"] = "python-glanceclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-glanceclient.git"
        end
        ENV["PROJECT_NAME"] = "python-glanceclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_keystone do
        ENV["OBS_PACKAGE"] = "openstack-keystone" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/keystone.git"
        end
        ENV["PROJECT_NAME"] = "keystone"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_keystoneclient do
        ENV["OBS_PACKAGE"] = "python-keystoneclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-keystoneclient.git"
        end
        ENV["PROJECT_NAME"] = "python-keystoneclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_swift do
        ENV["OBS_PACKAGE"] = "openstack-swift" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/swift.git"
        end
        ENV["PROJECT_NAME"] = "swift"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_swiftclient do
        ENV["OBS_PACKAGE"] = "python-swiftclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-swiftclient.git"
        end
        ENV["PROJECT_NAME"] = "python-swiftclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_cinder do
        ENV["OBS_PACKAGE"] = "openstack-cinder" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/cinder.git"
        end
        ENV["PROJECT_NAME"] = "cinder"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_cinderclient do
        ENV["OBS_PACKAGE"] = "python-cinderclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-cinderclient.git"
        end
        ENV["PROJECT_NAME"] = "python-cinderclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_neutron do
        ENV["OBS_PACKAGE"] = "openstack-neutron" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/neutron.git"
        end
        ENV["PROJECT_NAME"] = "neutron"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_python_neutronclient do
        ENV["OBS_PACKAGE"] = "python-neutronclient" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "1"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-neutronclient.git"
        end
        ENV["PROJECT_NAME"] = "python-neutronclient"
        Rake::Task["opensuse:build_packages"].execute
    end

    # Warlock is a fairly new Glance requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_warlock do
        ENV["OBS_PROJECT"] = "devel:languages:python" if ENV["OBS_PROJECT"].nil?
        ENV["OBS_PACKAGE"] = "python-warlock" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "0"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/bcwaldon/warlock.git"
        end
        ENV["PROJECT_NAME"] = "warlock"
        ENV["SOURCE_URL"] = "git://github.com/bcwaldon/warlock.git"
        Rake::Task["opensuse:build_packages"].execute
    end

    # openSUSE 12.2 includes python-prettytable 0.5
    # Most openstack projects require > 0.6 so we build our own here.
    task :build_python_prettytable do
        ENV["OBS_PROJECT"] = "devel:languages:python" if ENV["OBS_PROJECT"].nil?
        ENV["OBS_PACKAGE"] = "python-prettytable" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "0"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dprince/python-prettytable.git"
        end
        ENV["PROJECT_NAME"] = "prettytable"
        ENV["SOURCE_BRANCH"] = "0.6"
        ENV["SOURCE_URL"] = "git://github.com/dprince/python-prettytable.git"
        Rake::Task["opensuse:build_packages"].execute
    end

    # Stevedore is a fairly new Nova requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_stevedore do
        ENV["OBS_PROJECT"] = "devel:languages:python" if ENV["OBS_PROJECT"].nil?
        ENV["OBS_PACKAGE"] = "python-stevedore" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "0"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/dreamhost/stevedore.git"
        end
        ENV["PROJECT_NAME"] = "stevedore"
        ENV["SOURCE_URL"] = "git://github.com/dreamhost/stevedore.git"
        Rake::Task["opensuse:build_packages"].execute
    end

    # Extras is a fairly new OpenStack common requirement so we provide a
    # builder in FireStack for now until stable releases of distros pick it up
    task :build_python_extras do
        ENV["OBS_PROJECT"] = "devel:languages:python" if ENV["OBS_PROJECT"].nil?
        ENV["OBS_PACKAGE"] = "python-extras" if ENV["OBS_PACKAGE"].nil?
        ENV["OBS_USE_GIT_TARBALLS"] = "0"
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/testing-cabal/extras.git"
        end
        ENV["PROJECT_NAME"] = "extras"
        ENV["SOURCE_URL"] = "git://github.com/testing-cabal/extras.git"
        Rake::Task["opensuse:build_packages"].execute
    end

    task :build_misc do

        saved_env = ENV.to_hash

        Rake::Task["opensuse:build_python_stevedore"].execute

        #ENV.clear
        #ENV.update(saved_env)
        #
        #Rake::Task["opensuse:build_python_extras"].execute

        ENV.clear
        ENV.update(saved_env)

        Rake::Task["opensuse:build_python_prettytable"].execute
    end

end
