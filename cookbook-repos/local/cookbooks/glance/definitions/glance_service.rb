define :glance_service do

  service_name="glance-#{params[:name]}"
  pidfile="#{node[:glance][:pid_directory]}/#{service_name}.pid"

  service service_name do
    start_command "cd #{node[:glance][:working_directory]} && su -c 'glance-control #{params[:name]} start --pid-file=#{pidfile}' glance"
    stop_command "su -c 'glance-control #{params[:name]} stop --pid-file=#{pidfile}' glance"
    restart_command "su -c 'glance-control #{params[:name]} restart --pid-file=#{pidfile}' glance"
    status_command "pgrep #{service_name}"
    supports :status => true, :restart => true
    action :start
    subscribes :restart, resources(:template => "/etc/glance/glance.conf")
  end

end
