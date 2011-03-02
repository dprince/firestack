#
# Cookbook Name:: nova
# Recipe:: setup
#
# Copyright 2010, Opscode, Inc.
# Copyright 2011, Anso Labs
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

include_recipe "apt"

package "euca2ools"
package "curl"

execute "nova-manage db sync" do
  user "nova"
end

execute "nova-manage user admin #{node[:nova][:user]} #{node[:nova][:access_key]} #{node[:nova][:secret_key]}" do
  user 'nova'
  not_if "nova-manage user list | grep #{node[:nova][:user]}"
end

execute "nova-manage project create #{node[:nova][:project]} #{node[:nova][:user]}" do
  user 'nova'
  not_if "nova-manage project list | grep #{node[:nova][:project]}"
end

execute "nova-manage network create #{node[:nova][:network]}" do
  user 'nova'
  not_if { File.exists?("/var/lib/nova/setup") }
end

execute "nova-manage floating create #{node[:nova][:hostname]} #{node[:nova][:floating_range]}" do
  user 'nova'
  not_if { File.exists?("/var/lib/nova/setup") }
end

(node[:nova][:images] or []).each do |image|
  execute "curl #{image} | tar xvz -C /var/lib/nova/images" do
    user 'nova'
    not_if { File.exists?("/var/lib/nova/setup") }
  end
end

execute "touch /var/lib/nova/setup"
