$db_driver     = 'mysql'
$db_host     = '127.0.0.1'
$db_name     = 'nova'
$db_user = 'nova'
$db_password = 'password'

$glance_api_servers = 'localhost:9292'
$glance_host        = 'localhost'
$glance_port        = '9292'

$nova_network = '192.168.0.0/24'
$network_size = '256'
$floating_network = '172.20.0.0/24'

$qpid_password = 'p@ssw0rd'
$qpid_user = 'nova_qpid'
$qpid_realm = 'OPENSTACK'

$glance_db_host     = 'localhost'
$glance_db_name     = 'glance'
$glance_db_user = 'glance'
$glance_db_password = 'password'
$glance_sql_connection = "mysql://${glance_db_user}:${glance_db_password}@${glance_db_host}/${glance_db_name}"

$keystone_db_host     = 'localhost'
$keystone_db_name     = 'keystone'
$keystone_db_user = 'keystone'
$keystone_db_password = 'password'
$keystone_sql_connection = "mysql://${keystone_db_user}:${keystone_db_password}@${keystone_db_host}/${keystone_db_name}"

$cinder_db_driver     = 'mysql'
$cinder_db_host     = '127.0.0.1'
$cinder_db_name     = 'cinder'
$cinder_db_user = 'cinder'
$cinder_db_password = 'password'
$cinder_sql_connection = "mysql://${cinder_db_user}:${cinder_db_password}@${cinder_db_host}/${cinder_db_name}"

$heat_db_driver     = 'mysql'
$heat_db_host     = '127.0.0.1'
$heat_db_name     = 'heat'
$heat_db_user = 'heat'
$heat_db_password = 'password'
$heat_sql_connection = "mysql://${heat_db_user}:${heat_db_password}@${heat_db_host}/${heat_db_name}"


class { 'nova::qpid':
  user => $qpid_user,
  password => $qpid_password,
  realm => $qpid_realm,
}

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

class { 'keystone::db::mysql':
  password      => $keystone_db_password,
  dbname        => $keystone_db_name,
  user          => $keystone_db_user,
  host          => $keystone_db_host
}

class { 'keystone':
  admin_token => 'ADMIN',
  sql_connection => $keystone_sql_connection
}

class { 'nova::db::mysql':
  password => $db_password,
  allowed_hosts => ['%', $hostname],
}

class { 'nova':
  sql_connection => "${db_driver}://${db_user}:${db_password}@${db_host}/${db_name}",
  image_service => 'nova.image.glance.GlanceImageService',
  glance_api_servers => $glance_api_servers,
  rpc_backend => 'nova.openstack.common.rpc.impl_qpid',
  qpid_username => $qpid_user,
  qpid_password => $qpid_password
}

class {"nova::compute::libvirt":
  libvirt_type => 'qemu'
}

class { "nova::api":
  enabled => true,
  admin_user          => 'nova',
  admin_tenant_name   => 'services',
  admin_password      => 'SERVICE_PASSWORD',
  auth_host           => '127.0.0.1',
  auth_port           => '35357',
  auth_protocol       => 'http',
  volume_api_class => 'nova.volume.cinder.API',
  enabled_apis => 'ec2,osapi_compute,metadata'
}

$flat_network_bridge_ip  = '11.0.0.1'
$flat_network_bridge_netmask  = '255.255.255.0'

nova_config {
  'conductor/use_local': value => true;
  'DEFAULT/glance_host': value => $glance_host;
  'DEFAULT/glance_port': value => $glance_port;
  'DEFAULT/flat_network_bridge_ip': value => $flat_network_bridge_ip;
  'DEFAULT/flat_network_bridge_netmask': value => $flat_network_bridge_netmask;
  'DEFAULT/scheduler_default_filters': value => 'AvailabilityZoneFilter,ComputeFilter';
  'DEFAULT/allow_resize_to_same_host': value => true;
  'DEFAULT/libvirt_wait_soft_reboot_seconds': value => 15;
  'DEFAULT/libvirt_cpu_mode': value => 'none';
  'DEFAULT/notify_on_state_change': value => 'vm_and_task_state';
}

class { "nova::objectstore": enabled => true }

class { "nova::cert": enabled => true }

class { "nova::network":
  create_networks => false,
  fixed_range => $nova_network,
  enabled => true
}

class { "nova::scheduler": enabled => true }

nova::manage::network { "net-${nova_network}":
  label        => 'public',
  network      => $nova_network,
  network_size => $network_size
}

nova::manage::floating { "floating-${floating_network}":
  network       => $floating_network
}

class { 'nova::compute': enabled => true }

class { 'cinder::db::mysql':
  password => $cinder_db_password,
  allowed_hosts => ['%', $hostname],
}

class { "cinder::api":
  keystone_user => 'cinder',
  keystone_tenant => 'services',
  keystone_password => 'SERVICE_PASSWORD',
  keystone_auth_host => '127.0.0.1'
}

class { 'cinder':
  rpc_backend => 'cinder.openstack.common.rpc.impl_qpid',
  qpid_username => $qpid_user,
  qpid_password => $qpid_password,
  sql_connection => $cinder_sql_connection
}

class { "cinder::quota": }

class { 'cinder::scheduler':
  scheduler_driver => 'cinder.scheduler.chance.ChanceScheduler',
}

class { 'cinder::volume':
  require => Class['qpid::server']
}
class { 'cinder::volume::iscsi':
  iscsi_ip_address => '127.0.0.1',
}
class { 'cinder::setup_test_volume':
  size => '3G',
}

# Swift All In One
$swift_local_net_ip='0.0.0.0'

$swift_shared_secret='changeme'

class { 'ssh::server::install': }

class { 'memcached':
  listen_ip => $swift_local_net_ip,
}

class { 'swift':
  swift_hash_suffix => $swift_shared_secret,
  package_ensure => latest,
}

class { 'swift::storage':
  storage_local_net_ip => $swift_local_net_ip
}

swift::storage::loopback { '2':
  require => Class['swift'],
  seek => '250000',
}

swift::storage::node { '2':
  mnt_base_dir         => '/srv/node',
  weight               => 1,
  manage_ring          => true,
  zone                 => '2',
  storage_local_net_ip => $swift_local_net_ip,
  require              => Swift::Storage::Loopback[2] ,
}

class { 'swift::ringbuilder':
  part_power     => '18',
  replicas       => '1',
  min_part_hours => 1,
  require        => Class['swift'],
}

class { 'swift::proxy':
  proxy_local_net_ip => $swift_local_net_ip,
  pipeline           => ['healthcheck', 'cache', 'ratelimit', 'authtoken', 'keystone', 'proxy-server'],
  account_autocreate => true,
  require            => Class['swift::ringbuilder'],
}

class { 'swift::proxy::authtoken':
  admin_user          => 'swift',
  admin_tenant_name   => 'services',
  admin_password      => 'SERVICE_PASSWORD',
  auth_host           => '127.0.0.1',
  auth_port           => '35357',
  auth_protocol       => 'http',
  delay_auth_decision => false,
  admin_token         => false
}

class { 'swift::proxy::keystone':
  operator_roles => ['admin']
}

class { ['swift::proxy::healthcheck', 'swift::proxy::cache', 'swift::proxy::ratelimit']: }

class { 'glance::db::mysql':
  password      => $glance_db_password,
  dbname        => $glance_db_name,
  user          => $glance_db_user,
  host          => $glance_db_host,
}

class { 'glance::backend::swift':
  swift_store_auth_version => '2',
  swift_store_auth_address => 'http://127.0.0.1:5000/v2.0/',
  swift_store_user => 'admin:admin',
  swift_store_key => 'AABBCC112233',
  swift_store_create_container_on_put => 'True'
}

class { 'glance::registry':
  auth_type         => 'keystone',
  keystone_tenant   => 'services',
  keystone_user     => 'glance',
  keystone_password => 'SERVICE_PASSWORD',
  sql_connection => $glance_sql_connection,
}

class { 'glance::api':
  auth_type         => 'keystone',
  keystone_tenant   => 'services',
  keystone_user     => 'glance',
  keystone_password => 'SERVICE_PASSWORD',
  sql_connection => $glance_sql_connection,
}

# ceilometer
class { 'ceilometer':
  metering_secret => 'secret',
  rpc_backend => 'ceilometer.openstack.common.rpc.impl_qpid',
  qpid_username => $qpid_user,
  qpid_password => $qpid_password,
}

class { 'ceilometer::db::mysql':
  password => 'ceilometer',
}

class { 'ceilometer::db': }

class { 'ceilometer::collector': }

class { 'ceilometer::api':
  keystone_user => 'ceilometer',
  keystone_tenant => 'services',
  keystone_password => 'SERVICE_PASSWORD',
}

class { 'ceilometer::agent::compute': }

class { 'ceilometer::agent::auth':
  auth_user           => 'admin',
  auth_password       => 'AABBCC112233',
  auth_tenant_name    => 'admin'
}

# heat

class { 'heat::db::mysql':
   password => $heat_db_password,
   allowed_hosts => ['%', $hostname]
}

class { 'heat':
   rpc_backend => 'heat.openstack.common.rpc.impl_qpid',
   sql_connection => $heat_sql_connection,
   qpid_username => $qpid_user,
   qpid_password => $qpid_password,
   keystone_password => 'SERVICE_PASSWORD',
}

class { 'heat::keystone::auth':
   auth_user        => 'admin',
   auth_password    => 'AABBCC112233',
   auth_tenant_name => 'admin'
}
class { 'heat::keystone::auth_cfn':
   auth_user        => 'admin',
   auth_password    => 'AABBCC112233',
   auth_tenant_name => 'admin'
}

class { 'heat::api':
}

class { 'heat::engine':
}

class { 'heat::api_cfn':
}

class { 'heat::api_cloudwatch':
}
