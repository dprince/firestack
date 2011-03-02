name "nova-base"

run_list(
	"recipe[rackspace::apt]",
    "recipe[nova::common]"
)

default_attributes(
	"nova" => {
		"public_interface" => "tun0",
		"libvirt_type" => "qemu",
		"creds" => {
		"user" => "stacker",
		"group" => "stacker",
		"dir" => "/home/stacker"
		},
		"network_manager" => "nova.network.manager.FlatDHCPManager",
		"default_project" => "admin",
		"glance_host" => "glance1",
		"flat_interface" => "tap0",
		"flat_network_bridge" => "br100",
		"flat_network_dhcp_start" => "172.19.1.2",
		"network" => "172.19.1.0/24 1 256",
		"image_service" => "nova.image.glance.GlanceImageService",
		"images" => ["http://images.ansolabs.com/tty.tgz"]
	}
)
