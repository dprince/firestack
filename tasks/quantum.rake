namespace :quantum do

    task :build_fedora_packages do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-quantum.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/quantum.git"
        end
        ENV["PROJECT_NAME"] = "quantum"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :build_python_quantumclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/python-quantumclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-quantumclient.git"
        end
        ENV["PROJECT_NAME"] = "python-quantumclient"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :tarball do
        gw_ip = ServerGroup.get.gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        quantum_revision = get_revision(src_dir)
        raise "Failed to get quantum revision." if quantum_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f quantum/__init__.py ] \
                || { echo "Please specify a valid quantum project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".quantum-venv" ] && rm -Rf .quantum-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/quantum.tar.gz . 2> /dev/null || { echo "Failed to create quantum source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/quantum.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, out|
            fail "Unable to create quantum tarball! \n #{out}" unless ok
        end
    end

    desc "Build Quantum packages."
    task :build_packages do
        Rake::Task["quantum:build_fedora_packages"].invoke
    end

end
