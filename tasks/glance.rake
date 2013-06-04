namespace :glance do

    #desc "Install local Glance source code into the group."
    task :install_source => :tarball do
        server_name=ENV['SERVER_NAME']
        server_name = "glance1" if server_name.nil?
        remote_exec %{
scp /tmp/glance.tar.gz #{server_name}:/tmp
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
cd /usr/lib/python2.7/site-packages
rm -Rf glance
tar xf /tmp/glance.tar.gz 2> /dev/null || { echo "Failed to extract glance source tar."; exit 1; }
service openstack-glance-api restart
service openstack-glance-registry restart
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Failed to install source!" unless ok
        end
    end

    desc "Build Glance packages."
    task :build_packages => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_glance"].invoke
    end

    # Warlock is a fairly new Glance requirement so we provide a builder
    # in FireStack for now until stable releases of distros pick it up
    task :build_python_warlock => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_warlock"].invoke
    end

    desc "Build Python Glanceclient packages."
    task :build_python_glanceclient => :distro_name do
        Rake::Task["#{ENV['DISTRO_NAME']}:build_python_glanceclient"].invoke
    end

    task :tarball do
        gw_ip = ServerGroup.get.gateway_ip
        src_dir = ENV['SOURCE_DIR'] or raise "Please specify a SOURCE_DIR."
        glance_revision = get_revision(src_dir)
        raise "Failed to get glance revision." if glance_revision.empty?

        shh %{
            set -e
            cd #{src_dir}
            [ -f glance/version.py ] \
                || { echo "Please specify a valid glance project dir."; exit 1; }
            MY_TMP="#{mktempdir}"
            cp -r "#{src_dir}" $MY_TMP/src
            cd $MY_TMP/src
            [ -d ".git" ] && rm -Rf .git
            [ -d ".bzr" ] && rm -Rf .bzr
            [ -d ".glance-venv" ] && rm -Rf .glance-venv
            [ -d ".venv" ] && rm -Rf .venv
            tar czf $MY_TMP/glance.tar.gz . 2> /dev/null || { echo "Failed to create glance source tar."; exit 1; }
            scp #{SSH_OPTS} $MY_TMP/glance.tar.gz root@#{gw_ip}:/tmp
            rm -rf "$MY_TMP"
        } do |ok, res|
            fail "Unable to create glance tarball! \n #{res}" unless ok
        end
    end

    desc "Load images into Glance."
    task :load_images do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        remote_exec %{
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
  mkdir -p /var/lib/glance/
  [ -f /root/openstackrc ] && source /root/openstackrc
  if [ ! -d "/root/tty_linux" ]; then
    curl http://c3226372.r72.cf0.rackcdn.com/tty_linux.tar.gz | tar xvz -C /root/
  fi
  ARI_ID=$(glance image-create --name "ari-tty" --disk-format="ari" --container-format="ari" --is-public=true < /root/tty_linux/ramdisk | awk '/ id / { print $4 }')
  echo "ARI_ID=$ARI_ID"
  AKI_ID=$(glance image-create --name "aki-tty" --disk-format="aki" --container-format="aki" --is-public=true < /root/tty_linux/kernel | awk '/ id / { print $4 }')
  echo "AKI_ID=$AKI_ID"
  glance image-create --name "ami-tty" --disk-format="ami" --container-format="ami" --is-public=true --property ramdisk_id=$ARI_ID --property kernel_id=$AKI_ID < /root/tty_linux/image
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Load images failed!" unless ok
        end
    end

    task :load_images_xen do
        server_name=ENV['SERVER_NAME']
        # default to nova1 if SERVER_NAME is unset
        server_name = "nova1" if server_name.nil?
        remote_exec %{
if [ -f /images/squeeze-agent-0.0.1.31.ova ]; then
  scp /images/squeeze-agent-0.0.1.31.ova #{server_name}:/tmp/
fi
ssh #{server_name} bash <<-"EOF_SERVER_NAME"
  mkdir -p /var/lib/glance/
  [ -f /root/openstackrc ] && source /root/openstackrc
  if [ ! -f /tmp/squeeze-agent-0.0.1.31.ova ]; then
    cd /tmp
    curl http://c3324746.r46.cf0.rackcdn.com/squeeze-agent-0.0.1.31.ova -o /tmp/squeeze-agent-0.0.1.31.ova
  fi
  glance image-create --name "squeeze" --disk-format="vhd" --container-format="ovf" --is-public=true < /tmp/squeeze-agent-0.0.1.31.ova
EOF_SERVER_NAME
        } do |ok, out|
            puts out
            fail "Load images failed!" unless ok
        end
    end

end
