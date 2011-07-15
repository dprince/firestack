require File.dirname(__FILE__) + '/helper'
require 'tempfile'

class TestServers < Test::Unit::TestCase

  def setup
    @cs=Helper::get_connection

    @image_id = ENV['IMAGE_ID']
    #take the last image if IMAGE_ID isn't set
    if @image_id.nil? or @image_id.empty? then
      images = @cs.images.sort{|x,y| x[:id] <=> y[:id]}
      @image_id = images.last[:id].to_s
    end

    @servers = []
  end

  def teardown
    @servers.each do |server|
      assert_equal(true, server.delete!)
    end
  end

  def ssh_test(ip_addr)
    begin
      Timeout::timeout(SSH_TIMEOUT) do

        while(1) do
          ssh_identity=SSH_PRIVATE_KEY
          if KEYPAIR and not KEYPAIR.empty? then
              ssh_identity=ENV['KEYPAIR']
          end
          if system("ssh -o StrictHostKeyChecking=no -i #{ssh_identity} root@#{ip_addr} /bin/true > /dev/null 2>&1") then
            return true
          end
        end

      end
    rescue Timeout::Error => te
      fail("Timeout trying to ssh to server: #{ip_addr}")
    end

    return false

  end

  def ping_test(ip_addr)
    begin
      Timeout::timeout(PING_TIMEOUT) do

        while(1) do
          if system("ping -c 1 #{ip_addr} > /dev/null 2>&1") then
            return true
          end
        end

      end
    rescue Timeout::Error => te
      fail("Timeout pinging server: #{ip_addr}")
    end

    return false

  end

  def create_server(server_opts)
    server = @cs.create_server(server_opts)
    @servers << server
    server
  end

  def test_create_server

    # test data file to file inject into the server
    tmp_file=Tempfile.new "server_tests"
    tmp_file.write("yo")
    tmp_file.flush

    # NOTE: When using AMI style images we rely on keypairs for SSH access
    personalities={SSH_PUBLIC_KEY => "/root/.ssh/authorized_keys", tmp_file.path => "/tmp/foo/bar"}
    server = create_server(:name => "test1", :imageId => @image_id, :flavorId => 2, :personality => personalities)

    assert_not_nil(server.adminPass)
    assert_not_nil(server.hostId)
    #assert_equal(2, server.flavorId)
    assert_equal(@image_id, server.imageId.to_s)
    assert_equal('test1', server.name)
    server = @cs.server(server.id)

    begin
      timeout(SERVER_BUILD_TIMEOUT) do
        until server.status == 'ACTIVE' do
          server = @cs.server(server.id)
          sleep 1
        end
      end
    rescue Timeout::Error => te
      fail('Timeout creating server.')
    end

    ping_test(server.addresses[:private][0])
    ssh_test(server.addresses[:private][0])

  end

  def test_create_server_with_metadata

    metadata={ "key1" => "value1", "key2" => "value2" }
    server = create_server(:name => "test1", :imageId => @image_id, :flavorId => 1, :metadata => metadata)
    assert_not_nil(server.adminPass)
    #assert_equal(1, server.flavorId)
    assert_equal(@image_id, server.imageId.to_s)
    assert_equal('test1', server.name)
    assert_not_nil(server.hostId)
    metadata.each_pair do |key, value|
      assert_equal(value, server.metadata[key])
    end

  end

end
