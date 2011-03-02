name "nova-objectstore"

run_list(
    "role[nova-base]",
    "recipe[nova::objectstore]"
)
