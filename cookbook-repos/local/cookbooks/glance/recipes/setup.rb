#
# Cookbook Name:: glance
# Recipe:: setup
#

include_recipe "#{@cookbook_name}::common"

bash "tty linux setup" do
  cwd "/tmp"
  user "root"
  code <<-EOH
	mkdir -p /var/lib/glance/
	curl #{node[:glance][:tty_linux_image]} | tar xvz -C /tmp/
	glance-upload --type ramdisk /tmp/ari-tty/image ari-tty
	glance-upload --type kernel /tmp/aki-tty/image aki-tty
	glance-upload --type machine /tmp/ami-tty/image ami-tty --ramdisk=1 --kernel=2
	touch /var/lib/glance/tty_setup
  EOH
  not_if do File.exists?("/var/lib/glance/tty_setup") end
end
