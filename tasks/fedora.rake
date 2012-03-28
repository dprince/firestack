include ChefVPCToolkit::CloudServersVPC

namespace :fedora do

    #generic package builder to build RPMs for all Openstack projects
    task :build_packages do
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip

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

        cacheurl=ENV["CACHEURL"]

        puts "Building #{project} packages using: #{packager_url}:#{packager_branch} #{src_url}:#{src_branch}"

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

rpm -q fedpkg &> /dev/null || yum install -q -y git fedpkg python-setuptools

BUILD_LOG=$(mktemp)
SRC_DIR="#{project}_source"

#{BASH_COMMON}

CACHEURL="#{cacheurl}"
if [ -n $CACHEURL ] ; then
    download_cached_rpm #{project} "#{src_url}" "#{src_branch}" "#{git_revision}" "#{packager_url}" "#{packager_branch}" 
    test $? -eq 0 && { echo "Retrieved rpm's from cache" ; exit 0 ; }
fi

test -e openstack-#{project} && rm -rf openstack-#{project}
test -e $SRC_DIR && rm -rf $SRC_DIR


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
echo "#{project.upcase}_REVISION=$GIT_REVISION"

if [ -n "#{merge_master}" ]; then
	git merge #{merge_master_branch} || fail "Failed to merge #{merge_master_branch}."
fi

#custom version
sed -e "s|version *=.*|version='9999.9',|" -i setup.py

python setup.py sdist &> $BUILD_LOG || { echo "Failed to run sdist."; cat $BUILD_LOG; exit 1; }

cd 
git_clone_with_retry "#{packager_url}" "openstack-#{project}" || { echo "Unable to clone repos : #{packager_url}"; exit 1; }
cd openstack-#{project}
SPEC_FILE_NAME=$(ls *.spec | head -n 1)
RPM_BASE_NAME=${SPEC_FILE_NAME:0:-5}
[ #{packager_branch} != "master" ] && { git checkout -t -b #{packager_branch} origin/#{packager_branch} || { echo "Unable to checkout branch :  #{packager_branch}"; exit 1; } }
cp ~/$SRC_DIR/dist/*.tar.gz .
PACKAGE_REVISION=$(git rev-parse --short HEAD)_${GIT_REVISION:0:7} # GIT_REVISION may have been a full hash
sed -i.bk -e "s/\\(Release:.*\\.\\).*/\\1$PACKAGE_REVISION/g" "$SPEC_FILE_NAME"
sed -i.bk -e "s/Source0:.*/Source0:      $(ls *.tar.gz)/g" "$SPEC_FILE_NAME"
[ -z "#{build_docs}" ] && sed -i -e 's/%global with_doc .*/%global with_doc 0/g' "$SPEC_FILE_NAME"
md5sum *.tar.gz > sources 

# tmp workaround
sed -i.bk "$SPEC_FILE_NAME" -e 's/.*dnsmasq-utils.*//g'

# custom version
sed -i.bk "$SPEC_FILE_NAME" -e 's/^Version:.*/Version:          9999.9/g'

# Rip out patches
sed -i.bk "$SPEC_FILE_NAME" -e 's|^%patch.*||g'

# install dependency projects
fedpkg --dist master srpm &> $BUILD_LOG || { echo "Failed to build srpm."; cat $BUILD_LOG; exit 1; }
yum-builddep -y *.src.rpm &> $BUILD_LOG || { echo "Failed to yum-builddep."; cat $BUILD_LOG; exit 1; }

# build rpm's
fedpkg --dist master local &> $BUILD_LOG || { echo "Failed to build #{project} packages."; cat $BUILD_LOG; exit 1; }
mkdir -p ~/rpms
find . -name "*rpm" -exec cp {} ~/rpms \\;

if ls ~/rpms/${RPM_BASE_NAME}*.noarch.rpm &> /dev/null; then
  exit 0
else
  echo "Failed to build RPM: $RPM_BASE_NAME"
  exit 1
fi

BASH_EOF
RETVAL=$?
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Failed to build packages for #{project}!"
        end
    end

    # uploader to rpm cache
    task :fill_cache do
        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip

        cacheurl=ENV["CACHEURL"]
        raise "Please specify a CACHEURL" if cacheurl.nil?

        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

ls -d *_source || { echo "No RPMS to upload"; exit 0; }

for SRCDIR in $(ls -d *_source) ; do
    PROJECT=$(echo $SRCDIR | cut -d _ -f 1)
    echo Checking $PROJECT

    cd ~/$SRCDIR
    SRCUUID=$(git log -n 1 --pretty=format:%H)
    # If we're not at the head of master then we wont be caching
    [ $SRCUUID != $(cat .git/refs/heads/master) ] && continue

    cd ~/openstack-$PROJECT
    SPECUUID=$(git log -n 1 --pretty=format:%H)
    # If we're not at the head of master then we wont be caching
    [ $SPECUUID != $(cat .git/refs/heads/master) ] && continue

    URL=#{cacheurl}/rpmcache/$SPECUUID/$SRCUUID
    echo Cache : $SPECUUID $SRCUUID

    FILESWEHAVE=$(curl $URL 2> /dev/null)
    for file in $(find . -name "*rpm") ; do
        if [[ ! "$FILESWEHAVE" == *$(echo $file | sed -e 's/.*\\///g')* ]] ; then
            echo POSTING $file to $SPECUUID $SRCUUID
            curl -X POST $URL -Ffile=@$file 2> /dev/null || { echo ERROR POSTING FILE ; exit 1 ; }
        fi
    done
done

BASH_EOF
RETVAL=$?
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Cache of packages failed!"
        end
    end
end
