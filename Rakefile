CHEF_VPC_PROJECT = "#{File.dirname(__FILE__)}" unless defined?(CHEF_VPC_PROJECT)

require 'rubygems'

version_file=(File.join(CHEF_VPC_PROJECT, 'config', 'TOOLKIT_VERSION'))
toolkit_version=nil
if ENV['CHEF_VPC_TOOLKIT_VERSION'] then
  toolkit_version=ENV['CHEF_VPC_TOOLKIT_VERSION']
elsif File.exists?(version_file)
  toolkit_version=IO.read(version_file)
end

puts "Chef VPC Toolkit Version: #{toolkit_version}"

gem 'chef-vpc-toolkit', "= #{toolkit_version}" if toolkit_version

require 'chef-vpc-toolkit'

include ChefVPCToolkit

Dir[File.join("#{ChefVPCToolkit::Version::CHEF_VPC_TOOLKIT_ROOT}/rake", '*.rake')].each do  |rakefile|
    import(rakefile)
end

if File.exist?(File.join(CHEF_VPC_PROJECT, 'tasks')) then
  Dir[File.join(File.dirname("__FILE__"), 'tasks', '*.rake')].each do  |rakefile|
    import(rakefile)
  end
end
