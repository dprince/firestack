#!/bin/bash

if [ ! -f ~/.ssh/id_rsa ]; then
	[ -d ~/.ssh ] || mkdir ~/.ssh
	ssh-keygen -q -t rsa -f ~/.ssh/id_rsa &> /dev/null || \
		echo "Failed to create private key."
fi

if [ -z "$MODE" ] && [ -f /etc/nova/nova.conf ]; then
	if grep "nova.network.xenapi_net" /etc/nova/nova.conf &> /dev/null; then
		MODE="xenserver"
	fi
fi

if [[ "$MODE" == "xenserver" ]]; then
	# When using XenServer we make our timeouts a bit larger since our test
	# image is a bit larger and boot time takes longer
	export SSH_TIMEOUT="60"
	export PING_TIMEOUT="60"
	export SERVER_BUILD_TIMEOUT="360"

else
	# When using libvirt we'll use an AMI style image which require keypairs
	export KEYPAIR="/root/test.pem"
	dpkg -l euca2ools &> /dev/null || apt-get install -y euca2ools &> /dev/null
	[ -f "$KEYPAIR" ] || euca-add-keypair test > "$KEYPAIR"
	chmod 600 /root/test.pem
fi

RETVAL=0
for TEST in $(ls test*); do
    echo -n "Running: $TEST - "
    TMP_STDOUT=$(mktemp)
    if ruby $TEST > $TMP_STDOUT; then
      echo "PASS"
    else
      echo "FAIL"
      cat $TMP_STDOUT 
      RETVAL=1
    fi
done
exit $RETVAL
