namespace :cinder do

    desc "Build Cinder packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_cinder"].invoke
    end

    desc "Build Python Cinderclient packages."
    task :build_python_cinderclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_cinderclient"].invoke
    end

end
