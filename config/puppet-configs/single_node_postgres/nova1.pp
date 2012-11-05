ver     = 'postgresql'
$db_host     = 'localhost'
$db_name     = 'nova'
$db_user = 'nova'
$db_password = 'password'

$old_root_password = ''
$root_password = ''

$glance_api_servers = 'localhost:9292'
$glance_host        = 'localhost'
$glance_port        = '9292'

$nova_network = '192.168.0.0/24'
$available_ips = '256'
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

$cinder_db_driver     = 'postgresql'
$cinder_db_host     = 'localhost'
$cinder_db_name     = 'cinder'
$cinder_db_user = 'cinder'
$cinder_db_password = 'password'

$cinder_lock_path = '/var/lib/cinder/tmp'

$cinder_qpid_password = 'p@ssw0rd'
$cinder_qpid_user = 'cinder_qpid'
$cinder_qpid_realm = 'OPENSTACK'


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

class { 'cinder::client': }


class { 'nova':
  sql_connection => "${db_driver}://${db_user}:${db_password}@${db_host}/${db_name}",
  image_service => 'nova.image.glance.GlanceImageService',

  glance_api_servers => $glance_api_servers,
  glance_host => $glance_host,
  glance_port => $glance_port,

  libvirt_type => 'qemu',

  force_dhcp_release => true,
  scheduler_default_filters => 'AvailabilityZoneFilter,ComputeFilter',
  allow_resize_to_same_host => true,
  libvirt_wait_soft_reboot_seconds => 15,
  rpc_backend => 'nova.rpc.impl_qpid',
  qpid_username => $qpid_user,
  qpid_password => $qpid_password,
  enabled_apis => 'ec2,osapi_compute,metadata',
  volume_api_class => 'nova.volume.cinder.API',
  require => [Class["keystone"], Class["nova::postgresql"], Class["postgresql::server"], Class["cinder::client"]]
}

  class { "nova::api": enabled => true, keystone_enabled => true }

  $flat_network_bridge  = 'br100'
  $flat_network_bridge_ip  = '11.0.0.1'
  $flat_network_bridge_netmask  = '255.255.255.0'
  class { "nova::network::flat":
    enabled                     => true,
    flat_network_bridge         => $flat_network_bridge,
    flat_network_bridge_ip      => $flat_network_bridge_ip,
    flat_network_bridge_netmask => $flat_network_bridge_netmask,
  }

  class { "nova::objectstore":
    enabled => true,
  }

  class { "nova::cert":
    enabled => true,
  }

  class { "nova::scheduler": enabled => true }


  nova::manage::network { "net-${nova_network}":
    network       => $nova_network,
    available_ips => $available_ips
  }

  nova::manage::floating { "floating-${floating_network}":
    network       => $floating_network
  }

class { 'nova::compute':
  enabled        => true
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

resources { 'cinder_config':
  purge => true,
}

class { 'cinder::qpid':
  user => $cinder_qpid_user,
  password => $cinder_qpid_password,
  realm => $cinder_qpid_realm,
}

class { 'cinder::postgresql':
  db_password      => $cinder_db_password,
  db_name        => $cinder_db_name,
  db_user          => $cinder_db_username,
  db_host          => $cinder_db_host,
  require => Class["postgresql::python"],
}

class { 'cinder':
  db_driver => $cinder_db_driver,
  db_password => $cinder_db_password,
  db_name => $cinder_db_name,
  db_user => $cinder_db_user,
  db_host => $cinder_db_host,
  rpc_backend => 'cinder.openstack.common.rpc.impl_qpid',
  qpid_username => $cinder_qpid_user,
  qpid_password => $cinder_qpid_password,
  auth_strategy => 'keystone',
  scheduler_driver => 'cinder.scheduler.chance.ChanceScheduler',
  require => [Class["cinder::postgresql"], Class["postgresql::server"]]
}

class { 'cinder::api': }
class { 'cinder::scheduler': }
class { 'cinder::volume': }
