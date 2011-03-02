#
# Cookbook Name:: nova
# Recipe:: rabbit
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


node[:rabbitmq][:address] = node[:nova][:my_ip]

include_recipe "rabbitmq"

# add a vhost to the queue
execute "rabbitmqctl add_vhost #{node[:nova][:rabbit][:vhost]}" do
  not_if "rabbitmqctl list_vhosts | grep #{node[:nova][:rabbit][:vhost]}"
  subscribes :run, resources(:service => "rabbitmq-server"), :immediately
  #action :nothing
end

# create user for the queue
execute "rabbitmqctl add_user #{node[:nova][:rabbit][:user]} #{node[:nova][:rabbit][:password]}" do
  not_if "rabbitmqctl list_users | grep #{node[:nova][:rabbit][:user]}"
  subscribes :run, resources(:service => "rabbitmq-server"), :immediately
  #action :nothing
end

# grant the mapper user the ability to do anything with the vhost
# the three regex's map to config, write, read permissions respectively
execute "rabbitmqctl set_permissions -p #{node[:nova][:rabbit][:vhost]}  #{node[:nova][:rabbit][:user]} \".*\" \".*\" \".*\"" do
  not_if "rabbitmqctl list_user_permissions #{node[:nova][:rabbit][:user]} | grep #{node[:nova][:rabbit][:vhost]}"
  subscribes :run, resources(:service => "rabbitmq-server"), :immediately
  #action :nothing
end

# save data so it can be found by search
unless Chef::Config[:solo]
  Chef::Log.info("Saving node data")
  node.save
end

