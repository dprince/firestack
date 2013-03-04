namespace :oslo do

    desc "Build Oslo Config packages."
    task :build_config => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_oslo_config"].invoke
    end

end
