name "rabbitmq-server"

run_list(
    "recipe[rabbitmq]",
    "recipe[nova::rabbit]"
)
