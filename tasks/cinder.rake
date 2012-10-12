namespace :cinder do

    task :build_fedora_packages do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-cinder.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/cinder.git"
        end
        ENV["PROJECT_NAME"] = "cinder"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :build_python_cinderclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/python-cinderclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-cinderclient.git"
        end
        ENV["PROJECT_NAME"] = "python-cinderclient"
        Rake::Task["fedora:build_packages"].invoke
    end

    task :tarball do
        gw_ip = ServerGroup.get.gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        cinder_revision = get_revision(src_dir)
        raise "Failed to get cinder revision." if cinder_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f cinder/__init__.py ] \
                || { echo "Please specify a valid cinder project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".cinder-venv" ] && rm -Rf .cinder-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/cinder.tar.gz . 2> /dev/null || { echo "Failed to create cinder source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/cinder.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, out|
            fail "Unable to create cinder tarball! \n #{out}" unless ok
        end
    end

    desc "Build Cinder packages."
    task :build_packages do
        Rake::Task["cinder:build_fedora_packages"].invoke
    end

end
