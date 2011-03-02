default[:glance][:config_file]="/etc/glance/glance.conf"
default[:glance][:log_dir]="/var/log/glance"
default[:glance][:working_directory]="/var/lib/glance"
default[:glance][:pid_directory]="/var/run/glance/"

default[:glance][:verbose] = "True"
default[:glance][:debug] = "True"
default[:glance][:api_bind_host] = "0.0.0.0"
default[:glance][:api_bind_port] = "9292"
default[:glance][:registry_host] = "0.0.0.0"
default[:glance][:registry_bind_host] = "0.0.0.0"
default[:glance][:registry_bind_port] = "9191"
default[:glance][:sql_connection] = "sqlite:////var/lib/glance/glance.sqlite"
default[:glance][:sql_idle_timeout] = "3600"

#default_store choices are: file, http, https, swift, s3
default[:glance][:default_store] = "file"
default[:glance][:filesystem_store_datadir] = "/var/lib/glance/images"

# automatically glance upload the tty linux image. (glance::setup recipe)
default[:glance][:tty_linux_image] = "http://images.ansolabs.com/tty.tgz"
