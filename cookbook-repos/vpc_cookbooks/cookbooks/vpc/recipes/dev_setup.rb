#
# Cookbook Name:: vpc
# Recipe:: def_setup
#
# Copyright 2011, Rackspace
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

%w{bzr python-virtualenv python-dev swig python-m2crypto pep8 screen}.each do |pkg|
  package pkg
end

group node[:vpc][:dev_setup][:group] do
  action :create
  group_name node[:vpc][:dev_setup][:group]
end

user node[:vpc][:dev_setup][:user] do
  group node[:vpc][:dev_setup][:group]
  comment "Nova User"
  home node[:vpc][:dev_setup][:dir]
  shell "/bin/bash"
  not_if "grep #{node[:vpc][:dev_setup][:user]} /etc/passwd"
end

directory node[:vpc][:dev_setup][:dir] do
  owner node[:vpc][:dev_setup][:user]
  group node[:vpc][:dev_setup][:group]
  mode "0700"
  action :create
end

execute "bzr checkout lp:nova #{node[:vpc][:dev_setup][:dir]}/nova" do
  user node[:vpc][:dev_setup][:user]
  not_if do File.exists?("#{node[:vpc][:dev_setup][:dir]}/nova") end
end
