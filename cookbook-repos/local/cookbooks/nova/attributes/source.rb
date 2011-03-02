default[:nova][:bzr_branch] = "lp:nova"
default[:nova][:services_base_dir] = "/srv"
default[:nova][:nova_base_dir]  = File.join(node[:nova][:services_base_dir], "nova")
default[:nova][:local_branch_name] = "running"
default[:nova][:local_branch_dir] = File.join(node[:nova][:nova_base_dir], node[:nova][:local_branch_name])

