namespace :torpedo do

  desc "Install and run Torpedo: Fast Openstack tests."
  task :fire do

    server_name=ENV['SERVER_NAME']
    server_name = "nova1" if server_name.nil?
    mode=ENV['MODE'] # set to 'xen' or 'libvirt'
    mode = "libvirt" if mode.nil?
    
    server_build_timeout=ENV['TORPEDO_SERVER_BUILD_TIMEOUT'] || '180'
    ssh_timeout=ENV['TORPEDO_SSH_TIMEOUT'] || '60'
    ping_timeout=ENV['TORPEDO_PING_TIMEOUT'] || '60'
    use_keypairs=ENV['TORPEDO_USE_KEYPAIRS'] || 'true'
    image_name=ENV['TORPEDO_IMAGE_NAME'] || '' #defaults to 1st in list
    test_create_image=ENV['TORPEDO_TEST_CREATE_IMAGE'] || 'false'
    test_rebuild_server=ENV['TORPEDO_TEST_REBUILD_SERVER'] || 'false'
    test_soft_reboot_server=ENV['TORPEDO_TEST_SOFT_REBOOT_SERVER'] || 'false'
    test_hard_reboot_server=ENV['TORPEDO_TEST_HARD_REBOOT_SERVER'] || 'false'
    test_admin_password=ENV['TORPEDO_TEST_ADMIN_PASSWORD'] || 'false'
    test_resize_server=ENV['TORPEDO_TEST_RESIZE_SERVER'] || 'false'
    test_revert_resize_server=ENV['TORPEDO_TEST_REVERT_RESIZE_SERVER'] || 'false'
    volumes_enabled=ENV['TORPEDO_VOLUMES_ENABLED'] || 'false'
    test_hostid_on_resize=ENV['TORPEDO_TEST_HOSTID_ON_RESIZE'] || 'false'
    flavor_ref=ENV['TORPEDO_FLAVOR_REF'] || '' #defaults to 2 (m1.small)
    sleep_after_image_create=ENV['TORPEDO_SLEEP_AFTER_IMAGE_CREATE'] || '10'
    
    remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
#{BASH_COMMON_PKG}

install_package rubygem-torpedo

if [ -f /root/openstackrc ]; then
  source /root/openstackrc
else
  configure_noauth
  source ~/novarc
fi

if [ ! -f ~/.ssh/id_rsa ]; then
  [ -d ~/.ssh ] || mkdir ~/.ssh
  ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N "" || \
  echo "Failed to create private key."
fi

#enable iptables ping/ssh in default security group
if ! nova secgroup-list-rules default | grep -c icmp &> /dev/null; then
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
fi

cat > ~/.torpedo.conf <<-EOF_CAT
server_build_timeout: #{server_build_timeout}
ssh_timeout: #{ssh_timeout}
ping_timeout: #{ping_timeout}
image_name: #{image_name}
test_rebuild_server: #{test_rebuild_server}
test_create_image: #{test_create_image}
test_resize_server: #{test_resize_server}
test_revert_resize_server: #{test_revert_resize_server}
test_hostid_on_resize: #{test_hostid_on_resize}
test_soft_reboot_server: #{test_soft_reboot_server}
test_hard_reboot_server: #{test_hard_reboot_server}
test_admin_password: #{test_admin_password}
flavor_ref: #{flavor_ref}
sleep_after_image_create: #{sleep_after_image_create}
keypairs: #{use_keypairs}
volumes:
  enabled: #{volumes_enabled}
EOF_CAT

torpedo fire

EOF_SERVER_NAME
    } do |ok, out|
      puts out
      fail "Torpedo failed!" unless ok
    end

  end

  desc "Build torpedo packages"
  task :build_packages => :distro_name do
    Rake::Task["#{ENV['DISTRO_NAME']}:build_torpedo"].execute
  end

end

task :torpedo do
  Rake::Task['torpedo:fire'].invoke
end
