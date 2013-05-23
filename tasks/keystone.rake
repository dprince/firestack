namespace :keystone do

    desc "Build Keystone packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_keystone"].invoke
    end

    desc "Build Python Keystoneclient packages."
    task :build_python_keystoneclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_keystoneclient"].invoke
    end

    task :tarball do
        gw_ip = ServerGroup.get.gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        keystone_revision = get_revision(src_dir)
        raise "Failed to get keystone revision." if keystone_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f keystone/__init__.py ] \
                || { echo "Please specify a valid keystone project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".keystone-venv" ] && rm -Rf .keystone-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/keystone.tar.gz . 2> /dev/null || { echo "Failed to create keystone source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/keystone.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, out|
            fail "Unable to create keystone tarball! \n #{out}" unless ok
        end
    end

    desc "Configure Keystone tenants, services, etc."
    task :configure do

        server_name=ENV['SERVER_NAME']

        #API server hosts to be used as public endpoints
        nova_host=ENV['NOVA_HOST'] || 'localhost'
        glance_host=ENV['GLANCE_HOST'] || 'localhost'
        keystone_host=ENV['KEYSTONE_HOST'] || 'localhost'
        swift_host=ENV['SWIFT_HOST'] || 'localhost'
        cinder_host=ENV['CINDER_HOST'] || 'localhost'
        quantum_host=ENV['QUANTUM_HOST'] || 'localhost'

        server_name = "nova1" if server_name.nil?
        keystone_data_file = File.join(File.dirname(__FILE__), '..', 'scripts','keystone_data.sh')
        script = IO.read(keystone_data_file)
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

NOVA_HOST=#{nova_host}
GLANCE_HOST=#{glance_host}
KEYSTONE_HOST=#{keystone_host}
SWIFT_HOST=#{swift_host}
CINDER_HOST=#{cinder_host}
QUANTUM_HOST=#{quantum_host}

SERVICE_TOKEN=ADMIN
SERVICE_ENDPOINT=http://localhost:35357/v2.0
AUTH_ENDPOINT=http://localhost:5000/v2.0
#{script}
EOF_SERVER_NAME
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            fail "Keystone configuration failed! \n #{out}" unless ok
        end

    end

end
