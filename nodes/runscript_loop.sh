#!/bin/bash
LOOP=$2

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')

INDEX=1
while [ $INDEX -le $LOOP ]
do
  PRIVATE_CONFIG=qdata/c$INDEX_NODE/tm.ipc geth --exec "loadScript(\"$1\")" attach ipc:qdata/dd/geth.ipc
  sleep 1
  (( INDEX++ ))
done
