name "nova-network"

run_list(
    "role[nova-base]",
    "recipe[nova::network]"
)
