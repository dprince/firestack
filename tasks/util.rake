task :distro_name do

    # only run this if it isn't already set
    if ENV['DISTRO_NAME'].nil? or ENV['DISTRO_NAME'] == "" then
        remote_exec %{
# try to install lsb-release if not present (preinstall would be best)
if [ -f /etc/fedora-release ]; then
  rpm -q redhat-lsb-core &> /dev/null || yum -y -q install redhat-lsb-core
elif [ -f /usr/bin/dpkg ]; then
  dpkg -l lsb-release &> /dev/null || apt-get -y -q install lsb-release &> /dev/null
fi
lsb_release -is
    } do |ok, out|
            if ok then
                ENV['DISTRO_NAME'] = out.chomp.downcase
            else
                puts ok
                fail "Unable to set distro name with 'lsb_release'!"
            end
        end
    end

end

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
[ -d /var/log/cinder ] && tail -n #{line_count} /var/log/cinder/*.log || true
[ -d /var/log/quantum ] && tail -n #{line_count} /var/log/quantum/*.log || true
echo "END logs for: $HOSTNAME"
fi
EOF_SERVER_NAME
done
    } do |ok, out|
        puts out
        fail "Tail logs failed!" unless ok
    end

end

task :scp => 'kytoon:init' do
  sg=ServerGroup.get(ENV['GROUP_ID'])
  args=ARGV[1, ARGV.length].join(" ")
  if (ARGV[1] and ARGV[1] =~ /^GROUP_.*/) and (ARGV[2] and ARGV[2] =~ /^GROUP_.*/)
    args=ARGV[3, ARGV.length].join(" ")
  elsif ARGV[1] and ARGV[1] =~ /^GROUP_.*/
    args=ARGV[2, ARGV.length].join(" ")
  end
  exec("scp -o \"StrictHostKeyChecking no\" #{args} root@#{sg.gateway_ip}:")
end

desc "SSH into a running server group."
task :ssh => "kytoon:ssh"

#desc "List server groups."
task :list => "kytoon:list"

#desc "Delete a server group."
task :delete => "kytoon:delete"
