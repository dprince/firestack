#!/bin/bash
source /home/stacker/novarc
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
