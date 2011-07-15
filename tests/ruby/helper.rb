require 'rubygems'
require 'test/unit'
require 'openstack/compute'

SSH_TIMEOUT=(ENV['SSH_TIMEOUT'] || 30).to_i
PING_TIMEOUT=(ENV['PING_TIMEOUT'] || 60).to_i
SERVER_BUILD_TIMEOUT=(ENV['SERVER_BUILD_TIMEOUT'] || 60).to_i
SSH_PRIVATE_KEY=ENV['SSH_PRIVATE_KEY'] || ENV['HOME'] + "/.ssh/id_rsa"
SSH_PUBLIC_KEY=ENV['SSH_PUBLIC_KEY'] || ENV['HOME'] + "/.ssh/id_rsa.pub"
KEYPAIR=ENV['KEYPAIR']

USERNAME=ENV['NOVA_USERNAME']
API_KEY=ENV['NOVA_API_KEY']
API_URL=ENV['NOVA_URL']

module Helper

  def self.get_connection

    OpenStack::Compute::Connection.new(:username => USERNAME, :api_key => API_KEY, :api_url => API_URL)

  end

end
