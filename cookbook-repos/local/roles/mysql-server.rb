name "mysql-server"
description "MySQL server"

run_list(
  "recipe[build-essential]",
  "recipe[ruby]",
  "recipe[mysql::server]",
  "recipe[nova::mysql]"
)
