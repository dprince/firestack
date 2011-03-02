name "glance-registry"

run_list(
    "recipe[rackspace::apt]",
    "recipe[glance::registry]"
)
