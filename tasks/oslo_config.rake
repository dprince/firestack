namespace :oslo_config do

    desc "Build Oslo-config packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_oslo_config"].invoke
    end

end
