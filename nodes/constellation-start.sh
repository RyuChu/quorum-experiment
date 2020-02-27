#!/bin/bash
set -u
set -e

numNodes=7
if [[ -f qdata/numberOfNodes ]]; then
    numNodes=`cat qdata/numberOfNodes`
fi

echo "[*] Starting $numNodes Constellation node(s)"

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')
NODE_IP=$(cat ~/node_config | grep "NODE_IP" | awk -F '=' '{print $2}')

PEERS=""

IN=$(cat ~/node_config | grep "PEER_IPS" | awk -F '=' '{print $2}')
IFS=',' read -ra PEER <<< "$IN"
for i in "${PEER[@]}"; do
    PEERS+="http://$i:9001/,"
done

PEERS_LIST=$(echo $PEERS | rev | cut -c 2- | rev)

DDIR="qdata/c$INDEX_NODE"
mkdir -p $DDIR
mkdir -p qdata/logs
cp "keys/tm$INDEX_NODE.pub" "$DDIR/tm.pub"
cp "keys/tm$INDEX_NODE.key" "$DDIR/tm.key"
rm -f "$DDIR/tm.ipc"
CMD="constellation-node --url=https://$NODE_IP:9001/ --port=9001 --workdir=$DDIR --socket=tm.ipc --publickeys=tm.pub --privatekeys=tm.key --othernodes=$PEERS_LIST -vvv"
echo "$CMD >> qdata/logs/constellation.log 2>&1 &"
nohup $CMD >> "qdata/logs/constellation.log" 2>&1 &

DOWN=true
while $DOWN; do
    sleep 0.1
    DOWN=false
    if [ ! -S "qdata/c$INDEX_NODE/tm.ipc" ]; then
      DOWN=true
    fi
done
