include ChefVPCToolkit::CloudServersVPC

namespace :stackattack do

    desc "Install stack attack and dependencies on SERVER_NAME or nova1 in /usr/local/bin"
    task :install do

        sg=ServerGroup.fetch(:source => "cache")
        gw_ip=sg.vpn_gateway_ip
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        out=%x{
ssh #{SSH_OPTS} root@#{gw_ip} bash <<-"BASH_EOF"
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
curl -L cpanmin.us | perl - App::Rad HTTP::Async JSON LWP
rm -f stack-attack.pl
wget https://raw.github.com/throughnothing/stackattack/master/stack-attack.pl
chmod +x stack-attack.pl
mv stack-attack.pl /usr/local/bin/
EOF_SERVER_NAME
BASH_EOF
RETVAL=$?
exit $RETVAL
        }
        retval=$?
        puts out
        if not retval.success?
            fail "Install failed!"
        end

    end

end
