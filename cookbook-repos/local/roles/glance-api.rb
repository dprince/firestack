name "glance-api"

run_list(
    "recipe[rackspace::apt]",
    "recipe[glance::api]"
)
