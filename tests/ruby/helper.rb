require 'rubygems'
require 'test/unit'
require 'openstack/compute'

USERNAME=ENV['NOVA_USERNAME']
API_KEY=ENV['NOVA_API_KEY']
API_URL=ENV['NOVA_URL']

module Helper

  def self.get_connection

    OpenStack::Compute::Connection.new(:username => USERNAME, :api_key => API_KEY, :api_url => API_URL)

  end

end
