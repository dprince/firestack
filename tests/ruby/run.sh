#!/bin/bash
source /home/stacker/novarc

#FIXME use the OSAPI to generate keypairs (when available)
KEYPAIR="/root/test.pem"
dpkg -l euca2ools &> /dev/null || apt-get install -y euca2ools &> /dev/null
[ -d "$KEYPAIR" ] || euca-add-keypair test > "$KEYPAIR"
chmod 600 /root/test.pem
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
