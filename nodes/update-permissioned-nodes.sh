#!/bin/bash

NodesNum=$1

IFS=$'\r\n' GLOBIGNORE='*' command eval  'PEERS=($(cat ~/node_peers))'
ARR=()

for i in {1..7}; do

  Index=$i-1
  ARR+=($(cat permissioned-nodes.json | jq -r ".[$Index] | sub(\"127.0.0.1\"; \"${PEERS[$Index]}\")"))

  if [ $i -eq $NodesNum ]
  then
    break
  fi
done

printf '%s\n' "${ARR[@]}" | jq -R . | jq -s . > permissioned-nodes.json
