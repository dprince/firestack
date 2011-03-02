define :glance_service do

  service_name="glance-#{params[:name]}"
  pidfile="#{node[:glance][:pid_directory]}/#{service_name}.pid"

  opts=[]
  opts << "--verbose" if node[:glance][:verbose] and node[:glance][:verbose].to_s == "true"
  opts << "--debug" if node[:glance][:debug] and node[:glance][:debug].to_s == "true"
  opts << "--working-directory=#{node[:glance][:working_directory]}"

  if params[:opts] then
    params[:opts].each_pair do |key, value|
      opts << "--#{key}=#{value}"
    end
  end

  service service_name do
    start_command "su -c '#{service_name} #{opts.join(' ')} --daemonize' glance"
    stop_command "[ -f #{pidfile} ] && kill -s TERM $(cat #{pidfile})"
    status_command "pgrep #{service_name}"
    supports :status => true, :restart => false
    action :start
    #subscribes :restart, resources(:template => "/etc/glance/glance.conf")
  end

end
