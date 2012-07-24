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
  require => [Class["keystone"], Class["glance::postgresql"], Class["postgresql::python"], Class["glance::registry"]]
}
