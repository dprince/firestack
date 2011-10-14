require 'rubygems'
require 'test/unit'
gem 'openstack-compute', '=1.1.1'
require 'openstack/compute'

SSH_TIMEOUT=(ENV['SSH_TIMEOUT'] || 30).to_i
PING_TIMEOUT=(ENV['PING_TIMEOUT'] || 60).to_i
SERVER_BUILD_TIMEOUT=(ENV['SERVER_BUILD_TIMEOUT'] || 60).to_i
SSH_PRIVATE_KEY=ENV['SSH_PRIVATE_KEY'] || ENV['HOME'] + "/.ssh/id_rsa"
SSH_PUBLIC_KEY=ENV['SSH_PUBLIC_KEY'] || ENV['HOME'] + "/.ssh/id_rsa.pub"
TEST_SNAPSHOT_IMAGE=ENV['TEST_SNAPSHOT_IMAGE'] || "false"
TEST_REBUILD_INSTANCE=ENV['TEST_REBUILD_INSTANCE'] || "false"
TEST_RESIZE_INSTANCE=ENV['TEST_RESIZE_INSTANCE'] || "false"
KEYPAIR=ENV['KEYPAIR']
KEYNAME=ENV['KEYNAME']

USERNAME=ENV['NOVA_USERNAME']
API_KEY=ENV['NOVA_API_KEY']
API_URL=ENV['NOVA_URL']

module Helper

  def self.get_connection

    OpenStack::Compute::Connection.new(:username => USERNAME, :api_key => API_KEY, :auth_url => API_URL)

  end

  def self.get_last_image_ref(conn)

    image_ref = ENV['IMAGE_REF']
    #take the last image if IMAGE_REF isn't set
    if image_ref.nil? or image_ref.empty? then
      images = conn.images.sort{|x,y| x[:id] <=> y[:id]}
      image_ref = images.last[:id].to_s
    end
    image_ref

  end

end
