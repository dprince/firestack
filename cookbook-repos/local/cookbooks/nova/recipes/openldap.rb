#
# Cookbook Name:: nova
# Recipe:: openldap
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

include_recipe "openldap::server"
include_recipe "python-ldap"

##
# Nova includes special templates for this resources, so we override them.
##
r = resources(:template => "#{node[:openldap][:dir]}/slapd.conf")
r.cookbook("nova")

template "#{node[:openldap][:dir]}/ldap.conf" do
  owner "root"
  group "root"
  source "ldap.conf.erb"
  mode "0644"
end

cookbook_file "/etc/ldap/schema/openssh-lpk_openldap.schema" do
  source "openssh-lpk_openldap.schema"
  owner "root"
  group "root"
  mode "0644"
end

cookbook_file "/etc/ldap/schema/nova.schema" do
  source "nova.schema"
  owner "root"
  group "root"
  mode "0644"
end

cookbook_file "/etc/ldap/base.ldif" do
  source "base.ldif"
  owner "root"
  group "root"
  mode "0644"
end

bash "bootstrap_ldap" do
  code <<-EOH
    /etc/init.d/slapd stop
    rm -rf /var/lib/ldap/*
    rm -rf /etc/ldap/slapd.d/*
    slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
    cp /usr/share/slapd/DB_CONFIG /var/lib/ldap/DB_CONFIG
    slapadd -v -l /etc/ldap/base.ldif
    chown -R openldap:openldap /etc/ldap/slapd.d
    chown -R openldap:openldap /var/lib/ldap
    /etc/init.d/slapd start
  EOH
  action :nothing
  subscribes :execute, resources(:cookbook_file => "/etc/ldap/base.ldif")
end

