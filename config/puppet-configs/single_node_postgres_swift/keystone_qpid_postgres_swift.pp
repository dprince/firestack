$db_driver     = 'postgresql'
$db_host     = 'localhost'
$db_name     = 'nova'
$db_user = 'nova'
$db_password = 'password'

$old_root_password = ''
$root_password = ''

$glance_api_servers = 'localhost:9292'
$glance_host        = 'localhost'
$glance_port        = '9292'

$api_server = 'localhost'

$nova_network = '192.168.0.0/24'
$floating_network = '172.20.0.0/24'

$lock_path = '/var/lib/nova/tmp'

$qpid_password = 'p@ssw0rd'
$qpid_user = 'nova_qpid'
$qpid_realm = 'OPENSTACK'

$glance_db_host     = 'localhost'
$glance_db_name     = 'glance'
$glance_db_user = 'glance'
$glance_db_password = 'password'
$glance_sql_connection = "postgresql://${glance_db_user}:${glance_db_password}@${glance_db_host}/${glance_db_name}"

$keystone_db_host     = 'localhost'
$keystone_db_name     = 'keystone'
$keystone_db_user = 'keystone'
$keystone_db_password = 'password'
$keystone_sql_connection = "postgresql://${keystone_db_user}:${keystone_db_password}@${keystone_db_host}/${keystone_db_name}"

resources { 'nova_config':
  purge => true,
}

class { 'qpid::server':
  realm => $qpid_realm,
}

class { 'nova::qpid':
  user => $qpid_user,
  password => $qpid_password,
  realm => $qpid_realm,
}

class { 'postgresql::server': }

class { 'postgresql::python': }

class { 'keystone': }

class { 'keystone::postgresql':
  db_password      => $keystone_db_password,
  db_name        => $keystone_db_name,
  db_user          => $keystone_db_user,
  db_host          => $keystone_db_host
}

class { 'keystone::api':
  sql_connection => $keystone_sql_connection,
  require => [Class["keystone::postgresql"], Class["postgresql::python"]]
}

class { 'nova::postgresql':
  db_password      => $db_password,
  db_name        => $db_name,
  db_user          => $db_user,
  db_host          => $db_host,
  require => Class["postgresql::python"]
}

class { 'nova::controller':
  db_driver => $db_driver,
  db_password => $db_password,
  db_name => $db_name,
  db_user => $db_user,
  db_host => $db_host,

  image_service => 'nova.image.glance.GlanceImageService',

  glance_api_servers => $glance_api_servers,
  glance_host => $glance_host,
  glance_port => $glance_port,

  libvirt_type => 'qemu',

  nova_network => $nova_network,
  floating_network => $floating_network,
  keystone_enabled => true,
  scheduler_default_filters => 'AvailabilityZoneFilter,ComputeFilter',
  allow_resize_to_same_host => true,
  libvirt_wait_soft_reboot_seconds => 15,
  rpc_backend => 'nova.rpc.impl_qpid',
  qpid_username => $qpid_user,
  qpid_password => $qpid_password,
  require => [Class["keystone"], Class["nova::postgresql"], Class["postgresql::python"]]
}

class { 'nova::compute':
  api_server     => $api_server,
  enabled        => true,
  api_port       => 8773,
  aws_address    => '169.254.169.254',
}


# Swift All In One
$proxy_local_net_ip='127.0.0.1'
$swift_shared_secret='PfppwiB1WkoodcnJjFkHrbm5OY'

Exec { logoutput => true }

class { 'ssh::server::install': }

class { 'memcached':
  listen_ip => $proxy_local_net_ip,
}

class { 'swift':
  # not sure how I want to deal with this shared secret
  swift_hash_suffix => $swift_shared_secret,
  package_ensure => latest,
}

class { 'swift::storage': }

# create xfs partitions on a loopback device and mounts them
swift::storage::loopback { ['1', '2', '3']:
  require => Class['swift'],
  seek => '250000',
}
# sets up storage nodes which is composed of a single
# device that contains an endpoint for an object, account, and container

Swift::Storage::Node {
  mnt_base_dir         => '/srv/node',
  weight               => 1,
  manage_ring          => true,
  storage_local_net_ip => '127.0.0.1',
}

swift::storage::node { '1':
  zone                 => 1,
  require              => [Class['swift::storage'], Swift::Storage::Loopback[1]],
}

swift::storage::node { '2':
  zone                 => 2,
  require              => [Class['swift::storage'], Swift::Storage::Loopback[2]],
}

swift::storage::node { '3':
  zone                 => 3,
  require              => [Class['swift::storage'], Swift::Storage::Loopback[3]],
}

class { 'swift::ringbuilder':
  part_power     => '18',
  replicas       => '3',
  min_part_hours => 1,
  require        => Class['swift'],
}

class { 'swift::proxy':
  auth_type => 'keystone',
  account_autocreate => true,
  require            => Class['swift::ringbuilder'],
}

class { 'glance::postgresql':
  db_password      => $glance_db_password,
  db_name        => $glance_db_name,
  db_user          => $glance_db_user,
  db_host          => $glance_db_host,
}

class { 'glance::registry':
  registry_flavor => 'keystone',
  sql_connection => $glance_sql_connection,
  require => [Class["keystone"], Class["glance::postgresql"], Class["postgresql::python"]]
}

class { 'glance::api':
  api_flavor => 'keystone+cachemanagement',
  sql_connection => $glance_sql_connection,
  default_store => 'swift',
  swift_store_auth_version => '2',
  swift_store_auth_address => 'http://127.0.0.1:5000/v2.0/',
  swift_store_user => 'admin:admin',
  swift_store_key => 'AABBCC112233',
  swift_store_create_container_on_put => 'True',
  require => [Class["keystone"], Class["swift::proxy"], Class["glance::postgresql"], Class["postgresql::python"], Class["glance::registry"]]
}
