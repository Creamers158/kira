#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Staring $NODE_TYPE container..."

HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] ; then
    $SELF_CONTAINER/sentry/start.sh | tee -a $COMMON_DIR/start.log
elif [ "${NODE_TYPE,,}" == "snapshoot" ] ; then
    $SELF_CONTAINER/snapshoot/start.sh | tee -a $COMMON_DIR/start.log
elif [ "${NODE_TYPE,,}" == "validator" ] ; then
    $SELF_CONTAINER/validator/start.sh | tee -a $COMMON_DIR/start.log
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi
