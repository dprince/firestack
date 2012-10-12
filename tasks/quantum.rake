namespace :quantum do

    desc "Build Quantum packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_quantum"].invoke
    end

    desc "Build Python Quantumclient packages."
    task :build_python_quantumclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_quantumclient"].invoke
    end

end
