desc "Tail nova, glance, keystone logs."
task :tail_logs do

    sg=ServerGroup.get()
    server_name=ENV['SERVER_NAME']
    line_count=ENV['LINE_COUNT']
    line_count = 250 if line_count.nil?

    server_names = ""
    sg.server_names do |name|
        server_names +=  "#{name}\n"
    end

    remote_exec %{

if [ -n "#{server_name}" ]; then
  SERVER_NAMES="#{server_name}"
else
  SERVER_NAMES="#{server_names}"
fi
for SERVER_NAME in $SERVER_NAMES; do
ssh "$SERVER_NAME" bash <<-"EOF_SERVER_NAME"
if [ -d /var/log/nova ] || [ -d /var/log/glance ] || [ -d /var/log/keystone ]; then
echo "BEGIN logs for: $HOSTNAME"
[ -d /var/log/nova ] && tail -n #{line_count} /var/log/nova/*.log || true
[ -d /var/log/glance ] && tail -n #{line_count} /var/log/glance/*.log || true
[ -d /var/log/keystone ] && tail -n #{line_count} /var/log/keystone/*.log || true
echo "END logs for: $HOSTNAME"
fi
EOF_SERVER_NAME
done
    } do |ok, out|
        puts out
        fail "Tail logs failed!" unless ok
    end

end

task :ssh => "kytoon:ssh"
