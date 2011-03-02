name "nova-compute"

run_list(
    "role[nova-base]",
	"recipe[rackspace::nova_compute]"
)
