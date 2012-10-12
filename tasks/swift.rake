namespace :swift do

    desc "Build Swift packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_swift"].invoke
    end

    desc "Build Python Swiftclient packages."
    task :build_python_swiftclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_swiftclient"].invoke
    end

end
