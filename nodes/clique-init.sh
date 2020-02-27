#!/bin/bash
set -u
set -e

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [--numNodes numberOfNodes]"
  echo ""
  echo "Where:"
  echo "    numberOfNodes is the number of nodes to initialise (default = $numNodes)"
  echo ""
  exit -1
}

numNodes=7
while (( "$#" )); do
    case "$1" in
        --numNodes)
            re='^[0-9]+$'
            if ! [[ $2 =~ $re ]] ; then
                echo "ERROR: numberOfNodes value must be a number"
                usage
            fi
            numNodes=$2
            shift 2
            ;;
        --help)
            shift
            usage
            ;;
        *)
            echo "Error: Unsupported command line parameter $1"
            usage
            ;;
    esac
done

echo "[*] Cleaning up temporary data directories"
rm -rf qdata
mkdir -p qdata/logs

echo "[*] Configuring for $numNodes node(s)"
echo $numNodes > qdata/numberOfNodes

numPermissionedNodes=`grep "enode" permissioned-nodes.json |wc -l`
if [[ $numPermissionedNodes -ne $numNodes ]]; then
    echo "ERROR: $numPermissionedNodes nodes are configured in 'permissioned-nodes.json', but expecting configuration for $numNodes nodes"
    exit -1
fi

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')

echo "[*] Configuring node ${INDEX_NODE}"
mkdir -p qdata/dd/{keystore,geth}
cp permissioned-nodes.json qdata/dd/static-nodes.json
cp permissioned-nodes.json qdata/dd/
cp keys/key${INDEX_NODE} qdata/dd/keystore
cp raft/nodekey${INDEX_NODE} qdata/dd/geth/nodekey
geth --datadir qdata/dd init clique-genesis.json

#Initialise Tessera configuration
./tessera-init.sh
