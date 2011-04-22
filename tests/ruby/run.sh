#!/bin/bash
source /home/stacker/novarc
KEYPAIR="/root/test.pem"
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
