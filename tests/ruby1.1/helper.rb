require 'rubygems'
require 'test/unit'
gem 'openstack-compute', '=1.1.0'
require 'openstack/compute'

SSH_TIMEOUT=(ENV['SSH_TIMEOUT'] || 30).to_i
PING_TIMEOUT=(ENV['PING_TIMEOUT'] || 60).to_i
SERVER_BUILD_TIMEOUT=(ENV['SERVER_BUILD_TIMEOUT'] || 60).to_i
SSH_PRIVATE_KEY=ENV['SSH_PRIVATE_KEY'] || ENV['HOME'] + "/.ssh/id_rsa"
SSH_PUBLIC_KEY=ENV['SSH_PUBLIC_KEY'] || ENV['HOME'] + "/.ssh/id_rsa.pub"
TEST_SNAPSHOT_IMAGE=ENV['TEST_SNAPSHOT_IMAGE'] || "false"
KEYPAIR=ENV['KEYPAIR']
KEYNAME=ENV['KEYNAME']

USERNAME=ENV['NOVA_USERNAME']
API_KEY=ENV['NOVA_API_KEY']
API_URL=ENV['NOVA_URL']

module Helper

  def self.get_connection

    OpenStack::Compute::Connection.new(:username => USERNAME, :api_key => API_KEY, :api_url => API_URL)

  end

  def self.get_last_image_id(conn)

    image_id = ENV['IMAGE_ID']
    #take the last image if IMAGE_ID isn't set
    if image_id.nil? or image_id.empty? then
      images = conn.images.sort{|x,y| x[:id] <=> y[:id]}
      image_id = images.last[:id].to_s
    end
    image_id

  end

end
