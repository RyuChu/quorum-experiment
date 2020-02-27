#!/bin/bash
INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')
PRIVATE_CONFIG=qdata/c$INDEX_NODE/tm.ipc geth --exec "loadScript(\"$1\")" attach ipc:qdata/dd/geth.ipc
