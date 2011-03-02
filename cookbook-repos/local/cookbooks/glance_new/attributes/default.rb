default[:glance][:log_dir]="/var/log/glance"
default[:glance][:working_directory]="/var/lib/glance"
default[:glance][:pid_directory]="/var/run/glance/"

default[:glance][:verbose] = "false"
default[:glance][:debug] = "false"
default[:glance][:host] = "0.0.0.0"
default[:glance][:port] = "9292"
default[:glance][:registry_host] = "0.0.0.0"
default[:glance][:registry_port] = "9191"
default[:glance][:sql_connection] = "sqlite:///glance.sqlite"

#default_store choices are: file, http, https, swift, s3
default[:glance][:default_store] = "file"
default[:glance][:filesystem_store_datadir] = "/var/lib/glance/images"

# automatically glance upload the tty linux image. (glance::setup recipe)
default[:glance][:tty_linux_image] = "http://images.ansolabs.com/tty.tgz"
