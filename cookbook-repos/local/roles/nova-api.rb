name "nova-api"

run_list(
    "role[nova-base]",
    "recipe[nova::api]"
)
