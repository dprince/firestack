require File.dirname(__FILE__) + '/helper'
require 'tempfile'

class TestServers < Test::Unit::TestCase

  SSH_TIMEOUT=30
  PING_TIMEOUT=60
  ACTIVE_TIMEOUT=60

  def setup
    @cs=Helper::get_connection
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
          if system("ssh -i /root/test.pem root@#{ip_addr} /bin/true > /dev/null 2>&1") then
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

    server = create_server(:name => "test1", :imageId => 3, :flavorId => 1)
    assert_not_nil(server.adminPass)
    assert_not_nil(server.hostId)
    #assert_equal(1, server.flavorId)
    assert_equal("3", server.imageId)
    assert_equal('test1', server.name)
    server = @cs.server(server.id)

    begin
      timeout(ACTIVE_TIMEOUT) do
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
    server = create_server(:name => "test1", :imageId => 3, :flavorId => 1, :metadata => metadata)
    assert_not_nil(server.adminPass)
    #assert_equal(1, server.flavorId)
    assert_equal("3", server.imageId)
    assert_equal('test1', server.name)
    assert_not_nil(server.hostId)
    metadata.each_pair do |key, value|
      assert_equal(value, server.metadata[key])
    end

  end

  def test_create_server_with_personality

    tmp_file=Tempfile.new "server_tests"
    tmp_file.write("test")
    tmp_file.flush

    personalities={tmp_file.path => "/root/test.txt"}
    server = create_server(:name => "test1", :imageId => 3, :flavorId => 1, :personality => personalities)
    assert_not_nil(server.adminPass)
    #assert_equal(1, server.flavorId)
    assert_equal("3", server.imageId)
    assert_equal('test1', server.name)
    assert_not_nil(server.hostId)

  end

end
