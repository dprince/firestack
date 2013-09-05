namespace :keystone do

    desc "Build Keystone packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_keystone"].invoke
    end

    desc "Build Python Keystoneclient packages."
    task :build_python_keystoneclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_keystoneclient"].invoke
    end

    task :tarball do
        gw_ip = ServerGroup.get.gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        keystone_revision = get_revision(src_dir)
        raise "Failed to get keystone revision." if keystone_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f keystone/__init__.py ] \
                || { echo "Please specify a valid keystone project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".keystone-venv" ] && rm -Rf .keystone-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/keystone.tar.gz . 2> /dev/null || { echo "Failed to create keystone source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/keystone.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, out|
            fail "Unable to create keystone tarball! \n #{out}" unless ok
        end
    end

    desc "Configure Keystone tenants, services, etc."
    task :configure do

        server_name=ENV['SERVER_NAME']

        #API server hosts to be used as public endpoints
        nova_host=ENV['NOVA_HOST'] || 'localhost'
        glance_host=ENV['GLANCE_HOST'] || 'localhost'
        keystone_host=ENV['KEYSTONE_HOST'] || 'localhost'
        swift_host=ENV['SWIFT_HOST'] || 'localhost'
        cinder_host=ENV['CINDER_HOST'] || 'localhost'
        neutron_host=ENV['NEUTRON_HOST'] || 'localhost'
        ceilometer_host=ENV['CEILOMETER_HOST'] || 'localhost'

        server_name = "nova1" if server_name.nil?
        keystone_users_script = File.join(File.dirname(__FILE__), '..', 'scripts','keystone_users.bash')
        users_script = IO.read(keystone_users_script)
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

cat >/root/keystone.pp <<-"EOF_CAT"

class { 'mysql::server':
  config_hash => {
    'bind_address' => '0.0.0.0',
    'default_engine' => 'INNODB',
  }
}

class { 'mysql::ruby':
  package_provider => 'yum',
  package_name => 'ruby-mysql',
}

$keystone_db_host     = 'localhost'
$keystone_db_name     = 'keystone'
$keystone_db_user = 'keystone'
$keystone_db_password = 'password'

class { 'keystone::db::mysql':
  password      => $keystone_db_password,
  dbname        => $keystone_db_name,
  user          => $keystone_db_user,
  host          => $keystone_db_host
}

class { 'openstack::keystone':
  db_host                     => $keystone_db_host,
  db_password                 => $keystone_db_password,
  db_name                     => $keystone_db_name,
  db_user                     => $keystone_db_user,
  admin_token                 => 'ADMIN',
  admin_email                 => 'root@localhost',
  admin_password              => 'AABBCC112233',
  swift                       => true,
  ceilometer                  => true,
  glance_user_password        => 'SERVICE_PASSWORD',
  nova_user_password          => 'SERVICE_PASSWORD',
  cinder_user_password        => 'SERVICE_PASSWORD',
  neutron_user_password       => 'SERVICE_PASSWORD',
  swift_user_password         => 'SERVICE_PASSWORD',
  ceilometer_user_password    => 'SERVICE_PASSWORD',
  nova_public_address         => '#{nova_host}',
  public_address              => '#{keystone_host}',
  glance_public_address       => '#{glance_host}',
  cinder_public_address       => '#{cinder_host}',
  neutron_public_address      => '#{neutron_host}',
  swift_public_address        => '#{swift_host}',
  ceilometer_public_address   => '#{ceilometer_host}',
}

keystone_role { ['sysadmin', 'netadmin']:
  ensure => present,
}

keystone_tenant { 'user1':
  ensure      => present,
  enabled     => 'True',
  description => 'Tenant for User1',
}
keystone_user { 'user1':
  ensure   => present,
  password => 'DDEEFF445566',
  email    => 'user1@localhost',
  tenant   => 'user1',
}
keystone_user_role { "user1@user1":
  ensure  => present,
  roles   => ['Member', 'sysadmin', 'netadmin'],
}

keystone_tenant { 'user2':
  ensure      => present,
  enabled     => 'True',
  description => 'Tenant for User2',
}
keystone_user { 'user2':
  ensure   => present,
  password => 'GGHHII778899',
  email    => 'user2@localhost',
  tenant   => 'user2',
}
keystone_user_role { "user2@user2":
  ensure  => present,
  roles   => ['Member', 'sysadmin', 'netadmin'],
}

EOF_CAT


#{PUPPET_INSTALL_SCRIPT}

puppet apply --verbose --detailed-exitcodes keystone.pp &> /var/log/puppet/keystone.log
RETVAL=$?
if [ "$RETVAL" -eq 1 -o "$RETVAL" -gt 2 ]; then
    cat /var/log/puppet/keystone.log; exit 1;
    exit 1;
fi

SERVICE_TOKEN=ADMIN
SERVICE_ENDPOINT=http://localhost:35357/v2.0
AUTH_ENDPOINT=http://localhost:5000/v2.0
#{users_script}

EOF_SERVER_NAME
RETVAL=$?
exit $RETVAL
        } do |ok, out|
            fail "Keystone configuration failed! \n #{out}" unless ok
        end

    end

end
