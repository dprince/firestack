name "nova-volume"

run_list(
    "role[nova-base]",
    "recipe[nova::volume]"
)
