namespace :ceilometer do

    desc "Build Ceilometer packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_ceilometer"].invoke
    end

    desc "Build Python Ceilometer packages."
    task :build_python_ceilometerclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_ceilometerclient"].invoke
    end

    desc "Configure Ceilometer."
    task :configure do

    end

end
