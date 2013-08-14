namespace :heat do

    desc "Build Heat packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_heat"].invoke
    end

    desc "Build Python Heat packages."
    task :build_python_heatclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_heatclient"].invoke
    end

    desc "Configure Heat."
    task :configure do

    end

end
