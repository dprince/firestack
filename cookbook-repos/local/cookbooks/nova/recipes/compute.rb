#
# Cookbook Name:: nova
# Recipe:: compute
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

include_recipe "nova::common"
nova_package("compute")

if node[:nova][:compute_connection_type] == "kvm"
  service "libvirt-bin" do
    notifies :restart, resources(:service => "nova-compute"), :immediately
  end

  execute "modprobe kvm" do
    action :run
    notifies :restart, resources(:service => "libvirt-bin"), :immediately
  end
end

execute "modprobe nbd" do
  action :run
end
