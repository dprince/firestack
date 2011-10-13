#
# Cookbook Name:: vpc
# Recipe:: apt_config
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

include_recipe 'apt'

ruby_block "block until local APT repo is online" do
    block do
        require 'net/http'

        repo_loaded=false
        until repo_loaded == true do

            begin
            if Net::HTTP.get_response(URI.parse("#{node[:vpc][:apt][:local_url]}/dists/#{node[:vpc][:apt][:distro]}/Release")).class == Net::HTTPOK
                repo_loaded=true
                Chef::Log.info("APT repo is online.")
            else
                Chef::Log.info("Waiting on APT repo to load...")
                sleep 5
            end
            rescue
                Chef::Log.info("Waiting on APT repo to load...")
                sleep 5
            end

        end
    end
    not_if do File.exists?("/etc/apt/sources.list.d/local-source.list") end
end

apt_repository "local" do
  uri node[:vpc][:apt][:local_url]
  distribution node[:vpc][:apt][:distro]
  components(["main"])
  action :add
end

apt_repository "nova_ppa" do
  key "2A2356C9"
  keyserver "keyserver.ubuntu.com"
  uri node[:vpc][:apt][:nova_ppa_url]
  distribution node[:vpc][:apt][:distro]
  components(["main"])
  action :add
end

apt_repository "glance_ppa" do
  key "2085FE8D"
  keyserver "keyserver.ubuntu.com"
  uri node[:vpc][:apt][:glance_ppa_url]
  distribution node[:vpc][:apt][:distro]
  components(["main"])
  action :add
end

if node[:vpc][:apt][:ubuntu_mirror] then
  execute "sed -e 's|archive.ubuntu.com|#{node[:vpc][:apt][:ubuntu_mirror]}|g' -i /etc/apt/sources.list" do
    user 'root'
    not_if "grep #{node[:vpc][:apt][:ubuntu_mirror]} /etc/apt/sources.list"
  end
end
