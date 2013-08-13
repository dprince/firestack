KYTOON_PROJECT = "#{File.dirname(__FILE__)}" unless defined?(KYTOON_PROJECT)
SSH_OPTS="-o StrictHostKeyChecking=no"

require 'rubygems'

#version_file=(File.join(KYTOON_PROJECT, 'config', 'TOOLKIT_VERSION'))
#toolkit_version=nil
#if ENV['KYTOON_VERSION'] then
  #toolkit_version=ENV['KYTOON_VERSION']
#elsif File.exists?(version_file)
  #toolkit_version=IO.read(version_file)
#end
#gem 'kytoon', "~>#{toolkit_version}" if toolkit_version

require 'kytoon'

include Kytoon

require 'tempfile'
require 'fileutils'
def mktempdir(prefix="firestack")
    tmp_file=Tempfile.new(prefix)
    path=tmp_file.path
    tmp_file.close(true)
    FileUtils.mkdir_p path
    return path
end

def shh(script)
    out=%x{#{script}}
    retval=$?
    if block_given? then
        yield retval.success?, out
    else
        return [retval.success?, out]
    end
end

def remote_exec(script_text)
    sg=ServerGroup.get
    gw_ip=sg.gateway_ip

    out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"REMOTE_EXEC_EOF"
#{BASH_COMMON}
#{script_text}
REMOTE_EXEC_EOF
    }
    retval=$?
    if block_given? then
        yield retval.success?, out
    else
        return [retval.success?, out]
    end
end

def remote_multi_exec(hosts, script_text)

    sg=ServerGroup.get
    gw_ip=sg.gateway_ip

    results = {}
    threads = []

    hosts.each do |host|
        t = Thread.new do
            out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"REMOTE_EXEC_EOF"
ssh #{host} bash <<-"EOF_HOST"
#{BASH_COMMON}
#{script_text}
EOF_HOST
REMOTE_EXEC_EOF
            }
            retval=$?
            results.store host, [retval.success?, out]
        end
        threads << t
    end

    threads.each {|t| t.join}

    return results

end

def scp(src_dir, dest)

    gw_ip = ServerGroup.get.gateway_ip

    shh %{
        scp -r #{SSH_OPTS} #{src_dir} root@#{gw_ip}:#{dest}
    } do |ok, out|
        fail "Failed to scp #{src_dir}! \n #{out}" unless ok
    end

end

def get_revision(source_dir)
    %x{
        cd #{source_dir}
        if [ -d ".git" ]; then
          git log --oneline | wc -l
        else
          bzr revno --tree
        fi
    }.strip
end

Dir[File.join("#{Kytoon::Version::KYTOON_ROOT}/rake", '*.rake')].each do  |rakefile|
    import(rakefile)
end

if File.exist?(File.join(KYTOON_PROJECT, 'tasks')) then
  Dir[File.join(File.dirname("__FILE__"), 'tasks', '*.rake')].each do  |rakefile|
    import(rakefile)
  end
end

#functions to help install packages
BASH_COMMON_PKG=%{
function is_package_installed {
    local PKG=$1
    if [ -f /etc/fedora-release -o /etc/SuSE-release ]; then
        rpm -q ${PKG} &> /dev/null
        return $?
    elif [ -f /usr/bin/dpkg ]; then
        dpkg -l ${PKG} &> /dev/null
        return $?
    else
        return 1
    fi
}

function install_package {
    local PKGS=
    for PKG in $*; do
        is_package_installed "${PKG}" || PKGS="${PKGS} ${PKG}"
    done
    if [ -n "${PKGS}" ]; then
        if [ -f /etc/fedora-release ]; then
            yum -y -q install ${PKGS}
        elif [ -f /etc/redhat-release ]; then
            yum -y -q install ${PKGS}
        elif [ -f /etc/SuSE-release ]; then
            zypper -q --non-interactive install ${PKGS}
        elif [ -f /usr/bin/dpkg ]; then
            apt-get -y -q install ${PKGS} &> /dev/null
        fi
    fi
}

function install_git {
    if [ -f /etc/fedora-release ]; then
        install_package git
    else
        install_package git-core
    fi
}
}

#git clone w/ retry

firestack_debug=ENV.fetch("FIRESTACK_DEBUG", "")

BASH_COMMON=%{

if [ -n "#{firestack_debug}" ]; then
    set -x
fi

#{BASH_COMMON_PKG}

function fail {
    local MSG=$1
    echo "FAILURE_MSG=$MSG"
    exit 1
}

GIT_CACHE_DIR=/root/.git_repo_cache

function git_clone_with_retry {
    local URL=${1:?"Please specify a URL."}
    local DIR=${2:?"Please specify a DIR."}
    local URLSHA=$(echo \"$URL\" | sha1sum | cut -f 1 -d ' ')
    local SHORT_REPO_NAME=${URL/#*\\//}
    local CACHE_DIR="${GIT_CACHE_DIR}/${SHORT_REPO_NAME}-${URLSHA}"
    install_git
    [ -d "$GIT_CACHE_DIR" ] || mkdir -p "$GIT_CACHE_DIR"
    if [ -d "$CACHE_DIR" ]; then
        echo "Using git repository cache..."
        pushd "$CACHE_DIR" > /dev/null
        git pull &> /dev/null
        popd > /dev/null
        cp -a "$CACHE_DIR" "$DIR"
    else
        local COUNT=1
        echo "Git cloning: $URL"
        until GIT_ASKPASS=echo git clone "$URL" "$DIR"; do
            [ "$COUNT" -eq "4" ] && fail "Failed to clone: $URL"
            sleep $(( $COUNT * 5 ))
            COUNT=$(( $COUNT + 1 ))
        done
        cp -a "$DIR" "$CACHE_DIR"
    fi
}


function configure_noauth {

  cat > ~/novarc <<-EOF_CAT
NOVARC=$(readlink -f "${BASH_SOURCE:-${0}}" 2>/dev/null) ||
    NOVARC=$(python -c 'import os,sys; print os.path.abspath(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE:-${0}}")
NOVA_KEY_DIR=${NOVARC%/*}
export EC2_ACCESS_KEY="admin:admin"
export EC2_SECRET_KEY="91f4dacb-1aea-4428-97e1-f0ed631801f0"
export EC2_URL="http://127.0.0.1:8773/services/Cloud"
export S3_URL="http://127.0.0.1:3333"
export EC2_USER_ID=42 # nova does not use user id, but bundling requires it
#export EC2_PRIVATE_KEY=${NOVA_KEY_DIR}/pk.pem
#export EC2_CERT=${NOVA_KEY_DIR}/cert.pem
#export NOVA_CERT=${NOVA_KEY_DIR}/cacert.pem
export EUCALYPTUS_CERT=${NOVA_CERT} # euca-bundle-image seems to require this set
#alias ec2-bundle-image="ec2-bundle-image --cert ${EC2_CERT} --privatekey ${EC2_PRIVATE_KEY} --user 42 --ec2cert ${NOVA_CERT}"
#alias ec2-upload-bundle="ec2-upload-bundle -a ${EC2_ACCESS_KEY} -s ${EC2_SECRET_KEY} --url ${S3_URL} --ec2cert ${NOVA_CERT}"
export NOVA_API_KEY="admin"
export NOVA_USERNAME="admin"
export NOVA_PROJECT_ID="admin"
export NOVA_URL="http://127.0.0.1:8774/v1.1/"
export NOVA_VERSION="1.1"
EOF_CAT

}

}
