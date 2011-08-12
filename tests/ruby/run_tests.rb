#!/usr/bin/ruby
require 'fileutils'

MODE=ARGV[0]
if MODE.nil? || MODE.empty? then
  puts "./run_tests.rb <MODE>\nPlease specify a valid MODE (xen/libvirt)"
  exit 1
end

pkey="#{ENV['HOME']}/.ssh/id_rsa"
if not File.exists?(pkey) then
  FileUtils.mkdir_p(File.dirname(pkey)) if not File.exists?(File.dirname(pkey))
  if not system(%{ssh-keygen -q -t rsa -f #{pkey}}) then
    puts "Failed to create ssh key." and exit 1
  end
end

env={}
if MODE == "xen" then
  puts "Configuring env for XenServer."
  #XENSERVER ENV OPTS
  env={
    :ssh_timeout => 60, :ping_timeout => 60,
    :server_build_timeout => 60, :test_snapshot_image => "true"
  }
else
  #LIBVIRT ENV OPTS
  puts "Configuring env for Libvirt."
  keypair="/root/test.pem"
  env={
    :keypair => keypair
  }
  if not File.exists?(keypair) then
    if not system(%{
    which euca-add-keypair || apt-get install -q -y euca2ools &> /dev/null
    euca-add-keypair test > #{keypair} || { rm -f #{keypair}; exit 1; }
    chmod 600 #{keypair}
    }) then
      puts "Failed to create keypair." and exit 1
    end
  end

end
env.each_pair { |k,v| ENV[k.to_s.upcase] = v }

require 'rubygems'
require 'test-unit-ext'
require 'test_flavors'
require 'test_limits'
require 'test_images'
require 'test_servers'
