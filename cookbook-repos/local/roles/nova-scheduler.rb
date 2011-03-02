name "nova-scheduler"

run_list(
    "role[nova-base]",
    "recipe[nova::scheduler]"
)
