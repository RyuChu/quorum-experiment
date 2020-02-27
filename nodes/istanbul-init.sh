#!/bin/bash
set -u
set -e

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [--istanbulTools] [--numNodes numberOfNodes]"
  echo ""
  echo "Where:"
  echo "    --istanbulTools will perform initialisation from data generated using"
  echo "      istanbul-tools (note that permissioned-node.json and istanbul-genesis.json"
  echo "      files will be overwritten)"
  echo "    numberOfNodes is the number of nodes to initialise (default = $numNodes)"
  echo ""
  exit -1
}

istanbulTools="false"
numNodes=7
while (( "$#" )); do
    case "$1" in
        --istanbulTools)
            istanbulTools="true"
            shift
            ;;
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

if [[ "$istanbulTools" == "true" ]]; then
    cp static-nodes.json permissioned-nodes.json
    cp genesis.json istanbul-genesis.json
fi

numPermissionedNodes=`grep "enode" permissioned-nodes.json |wc -l`
if [[ $numPermissionedNodes -ne $numNodes ]]; then
    echo "ERROR: $numPermissionedNodes nodes are configured in 'permissioned-nodes.json', but expecting configuration for $numNodes nodes"
    exit -1
fi

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')

echo "[*] Configuring node ${INDEX_NODE}"
mkdir -p qdata/dd/{keystore,geth}
if [[ "$istanbulTools" == "true" ]]; then
    iMinus1=$(($INDEX_NODE - 1))
    cp ${INDEX_NODEMinus1}/nodekey qdata/dd/geth/nodekey
else
    cp raft/nodekey${INDEX_NODE} qdata/dd/geth/nodekey
fi
cp permissioned-nodes.json qdata/dd/static-nodes.json
cp keys/key${INDEX_NODE} qdata/dd/keystore
geth --datadir qdata/dd init istanbul-genesis.json

#Initialise Tessera configuration
./tessera-init.sh
