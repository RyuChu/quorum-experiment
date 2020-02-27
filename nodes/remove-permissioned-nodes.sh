#!/bin/bash

NodesNum=$1

jq_del_str=""

for i in {7..1}; do

  jq_del_str+="$i,"

  if [ $i -eq $NodesNum ]
  then
    break
  fi
done

cat permissioned-nodes.json | jq -r "del(.[$(echo $jq_del_str | rev | cut -c 2- | rev)])" > permissioned-nodes.json
