#!/bin/bash
exec 2>&1
set -e
# quick edit: FILE="$KIRA_SCRIPTS/container-running.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

# NOTE: $1 (arg 1) must be a valid container id
if [ -z "$1" ] ; then
    echo "false"
else
    STATUS=$(timeout 2 docker inspect "$1" 2> /dev/null | jq -rc '.[0].State.Status' 2> /dev/null || echo "")
    if [ "${STATUS,,}" == "running" ] || [ "${STATUS,,}" == "starting" ] ; then
        echo "true"
    else
        echo "false"
    fi
fi
