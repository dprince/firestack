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

#git clone w/ retry
BASH_COMMON=%{
function fail {
    local MSG=$1
    echo "FAILURE_MSG=$MSG"
    exit 1
}

GIT_CACHE_DIR=/root/.git_repo_cache

function git_clone_with_retry {
    rpm -q git &> /dev/null || yum install -q -y git
    local URL=${1:?"Please specify a URL."}
    local DIR=${2:?"Please specify a DIR."}
    local CACHE_DIR="$GIT_CACHE_DIR/$(echo \"$DIR\" | md5sum | cut -f 1 -d ' ')"
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

}
