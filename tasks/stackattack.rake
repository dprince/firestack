namespace :stackattack do

    #desc "Install stack attack and dependencies on SERVER_NAME or nova1 in /usr/local/bin"
    task :install do
        server_name=ENV['SERVER_NAME']
        server_name = "nova1" if server_name.nil?
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
curl -L cpanmin.us | perl - App::Rad HTTP::Async JSON LWP
rm -f stack-attack.pl
wget https://raw.github.com/throughnothing/stackattack/master/stack-attack.pl
chmod +x stack-attack.pl
mv stack-attack.pl /usr/local/bin/
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Install of stackattack failed!" unless ok
        end

    end

end
