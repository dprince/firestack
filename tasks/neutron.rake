namespace :neutron do

    desc "Build Neutron packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_neutron"].invoke
    end

    desc "Build Python Neutronclient packages."
    task :build_python_neutronclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_neutronclient"].invoke
    end

    desc "Configure a sample Neutron network."
    task :configure do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        #floating_range=ENV['FLOATING_RANGE'] || "172.20.0.0/24"
        #fixed_range=ENV['FIXED_RANGE'] || "192.168.0.0/24"
        #network_gateway=ENV['NETWORK_GATEWAY'] || "192.168.0.1"
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"

cat >/root/provision.pp <<-"EOF_CAT"
class openstack::provision(

  $admin_tenant_name         = 'admin',
  $tenant_name               = 'user1',
  $public_network_name       = 'public',
  $public_subnet_name        = 'public_subnet',
  $floating_range            = '172.24.4.224/28',
  $private_network_name      = 'private',
  $private_subnet_name       = 'private_subnet',
  $fixed_range               = '10.0.0.0/24',
  $router_name               = 'router1',
  $public_bridge_name        = 'br-ex',

) {

  ## Networks
  neutron_network { $public_network_name:
    ensure          => present,
    router_external => true,
    tenant_name     => $admin_tenant_name,
  }
  neutron_subnet { $public_subnet_name:
    ensure          => 'present',
    cidr            => $floating_range,
    enable_dhcp     => false,
    network_name    => $public_network_name,
    tenant_name     => $admin_tenant_name,
  }
  neutron_network { $private_network_name:
    ensure      => present,
    tenant_name => $tenant_name,
  }
  neutron_subnet { $private_subnet_name:
    ensure       => present,
    cidr         => $fixed_range,
    network_name => $private_network_name,
    tenant_name  => $tenant_name,
  }
  # Tenant-owned router - assumes network namespace isolation
  neutron_router { $router_name:
    ensure               => present,
    tenant_name          => $tenant_name,
    gateway_network_name => $public_network_name,
    # A neutron_router resource must explicitly declare a dependency on
    # the first subnet of the gateway network.
    require              => Neutron_subnet[$public_subnet_name],
  }
  neutron_router_interface { "${router_name}:${private_subnet_name}":
    ensure => present,
  }

  neutron_l3_ovs_bridge { $public_bridge_name:
    ensure      => present,
    subnet_name => $public_subnet_name,
  }

}

class { 'openstack::provision': }

EOF_CAT

puppet apply /root/provision.pp

EOF_SERVER_NAME

        } do |ok, out|
            puts out
            fail "Failed to configure networking!" unless ok
        end
    end

end
