namespace :swift do
    task :build_fedora_packages do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/openstack-swift.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/swift.git"
        end
        ENV["PROJECT_NAME"] = "swift"
        Rake::Task["fedora:build_packages"].invoke
    end

    desc "Build Swift packages."
    task :build_packages do
        Rake::Task["swift:build_fedora_packages"].invoke
    end

    task :build_python_swiftclient do

        packager_url= ENV.fetch("RPM_PACKAGER_URL", "git://pkgs.fedoraproject.org/python-swiftclient.git")
        ENV["RPM_PACKAGER_URL"] = packager_url if ENV["RPM_PACKAGER_URL"].nil?
        if ENV["GIT_MASTER"].nil?
            ENV["GIT_MASTER"] = "git://github.com/openstack/python-swiftclient.git"
        end
        ENV["PROJECT_NAME"] = "python-swiftclient"
        Rake::Task["fedora:build_packages"].invoke

    end

end
