namespace :rpm do

    # Generic package builder to rebuild a SRPM URL
    task :build_package_url => :distro_name do

        source_package_url=ENV['SOURCE_PACKAGE_URL']
        raise "Please specify a SOURCE_PACKAGE_URL." if source_package_url.nil?

        server_name=ENV['SERVER_NAME']
        server_name = "localhost" if server_name.nil?

        # optional... but if specified will push/pull to/from RPM cache
        cacheurl=ENV["CACHEURL"]
        cache_user=ENV["CACHE_USER"]
        cache_password=ENV["CACHE_PASSWORD"]

        puts "Building source package for: #{source_package_url}"

        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON}
install_package git rpm-build python-setuptools yum-utils make gcc curl

set -e

BUILD_LOG=$(mktemp)

RPM_NAME=$(basename #{source_package_url})
PKGUUID=$(echo "#{source_package_url}" | sha1sum | cut -f 1 -d ' ') 
SRCUUID="0000000000000000000000000000000000000000"
BASE_CACHE_URL="#{cacheurl}/pkgcache/pkgcache/#{ENV['DISTRO_NAME']}/$PKGUUID/$SRCUUID"

mkdir -p ~/rpms

if [ -n "#{cacheurl}" ]; then
    echo "Checking cache For $PKGUUID $SRCUUID"
    FILESFROMCACHE=$(curl -k $BASE_CACHE_URL 2> /dev/null)
    if [ "$?" -eq 0 ]; then
      cd ~/rpms
      HADFILE=0
      for file in $FILESFROMCACHE ; do
        HADFILE=1
        filename=$(echo $file | sed -e 's/.*\\///g')
        echo Downloading $file -\\> $filename
        curl -k #{cacheurl}/pkgcache/$file 2> /dev/null > "$filename" || HADERROR=1
      done
      [ $HADFILE -eq 1 ] && exit 0
    else
      echo "No files in RPM cache."
    fi
fi

# prep our rpmbuild tree
mkdir -p ~/rpmbuild/SPECS
mkdir -p ~/rpmbuild/SOURCES
mkdir -p ~/rpmbuild/SRPMS
rm -Rf ~/rpmbuild/RPMS/*
rm -Rf ~/rpmbuild/SRPMS/*

cd ~/rpmbuild/SRPMS/

curl -O -q #{source_package_url}

yum-builddep --nogpgcheck -y $RPM_NAME &>> $BUILD_LOG || { echo "Failed to yum-builddep."; cat $BUILD_LOG; exit 1; }

#build source RPM
rpmbuild --rebuild $RPM_NAME &>> $BUILD_LOG || { echo "Failed to build rpm."; cat $BUILD_LOG; exit 1; }

echo "RPMS built:"
ls ~/rpmbuild/**/*.rpm
RETVAL=$?

if [ -n "#{cacheurl}" -a -n "#{cache_user}" -a -n "#{cache_password}" ]; then

    echo SRPM Cache : $PKGUUID $SRCUUID

    FILESWEHAVE=$(curl -k $BASE_CACHE_URL 2> /dev/null)
    for file in ~/rpmbuild/**/*.rpm ; do
        if [[ ! "$FILESWEHAVE" == *$(echo $file | sed -e 's/.*\\///g')* ]] ; then
            echo POSTING $file to $PKGUUID $SRCUUID
            curl -k -u "#{cache_user}:#{cache_password}" -X POST $BASE_CACHE_URL -Ffile=@$file 2> /dev/null || { echo ERROR POSTING FILE ; exit 1 ; }
        fi
    done

fi

find ~/rpmbuild -name "*rpm" -exec cp {} ~/rpms \\;

if [ $RETVAL -eq 1 ]; then
  echo "Failed to build RPM: $RPM_NAME"
  cat $BUILD_LOG
fi
rm $BUILD_LOG
exit $RETVAL

EOF_SERVER_NAME
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            puts out
            fail "Failed to build packages for: #{source_package_url}" unless ok
        end

    end

end
