include ChefVPCToolkit::CloudServersVPC

desc "Tail nova, glance, keystone logs."
task :tail_logs => "chef:tail_logs" do

    sg=ServerGroup.fetch(:source => "cache")
    gw_ip=sg.vpn_gateway_ip
    server_name=ENV['SERVER_NAME']
    line_count=ENV['LINE_COUNT']
    line_count = 250 if line_count.nil?

    out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"

if [ -n "#{server_name}" ]; then
  SERVER_NAMES="#{server_name}"
else
  SERVER_NAMES="$(knife node list)"
fi
for SERVER_NAME in $SERVER_NAMES; do
if [ "$(hostname -f)" = "$SERVER_NAME" ]; then
if [ -d /var/log/nova ] || [ -d /var/log/glance ] || [ -d /var/log/keystone ]; then
echo "BEGIN logs for: $HOSTNAME"
[ -d /var/log/nova ] && tail -n #{line_count} /var/log/nova/nova-* || true
[ -d /var/log/glance ] && tail -n #{line_count} /var/log/glance/*.log || true
[ -d /var/log/keystone ] && tail -n #{line_count} /var/log/keystone/*.log || true
echo "END logs for: $HOSTNAME"
fi
else
ssh "$SERVER_NAME" bash <<-"EOF_SERVER_NAME"
if [ -d /var/log/nova ] || [ -d /var/log/glance ] || [ -d /var/log/keystone ]; then
echo "BEGIN logs for: $HOSTNAME"
[ -d /var/log/nova ] && tail -n #{line_count} /var/log/nova/nova-* || true
[ -d /var/log/glance ] && tail -n #{line_count} /var/log/glance/*.log || true
[ -d /var/log/keystone ] && tail -n #{line_count} /var/log/keystone/*.log || true
echo "END logs for: $HOSTNAME"
fi
EOF_SERVER_NAME
fi
done
BASH_EOF
    }
    retval=$?
    puts out
    if not retval.success?
        fail "Tail logs failed!"
    end

end
