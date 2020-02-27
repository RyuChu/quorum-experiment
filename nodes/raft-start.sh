#!/bin/bash
set -u
set -e

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [tessera | tessera-remote | constellation] [--tesseraOptions \"options for Tessera start script\"]"
  echo ""
  echo "Where:"
  echo "    tessera | tessera-remote | constellation (default = tessera): specifies which privacy implementation to use"
  echo "    --tesseraOptions: allows additional options as documented in tessera-start.sh usage which is shown below:"
  echo ""
  echo "Note that this script will examine the file qdata/numberOfNodes to"
  echo "determine how many nodes to start up. If the file doesn't exist"
  echo "then 7 nodes will be assumed"
  echo ""
  ./tessera-start.sh --help
  exit -1
}

privacyImpl=tessera
tesseraOptions=
while (( "$#" )); do
    case "$1" in
        tessera)
            privacyImpl=tessera
            shift
            ;;
        constellation)
            privacyImpl=constellation
            shift
            ;;
        tessera-remote)
            privacyImpl="tessera-remote"
            shift
            ;;
        --tesseraOptions)
            tesseraOptions=$2
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

NETWORK_ID=$(cat genesis.json | tr -d '\r' | grep chainId | awk -F " " '{print $2}' | awk -F "," '{print $1}')

if [ $NETWORK_ID -eq 1 ]
then
	echo "  Quorum should not be run with a chainId of 1 (Ethereum mainnet)"
    echo "  please set the chainId in the genensis.json to another value "
	echo "  1337 is the recommend ChainId for Geth private clients."
fi

mkdir -p qdata/logs

numNodes=7
if [[ -f qdata/numberOfNodes ]]; then
    numNodes=`cat qdata/numberOfNodes`
fi

if [ "$privacyImpl" == "tessera" ]; then
  echo "[*] Starting Tessera nodes"
  ./tessera-start.sh ${tesseraOptions}
elif [ "$privacyImpl" == "constellation" ]; then
  echo "[*] Starting Constellation nodes"
  ./constellation-start.sh
elif [ "$privacyImpl" == "tessera-remote" ]; then
  echo "[*] Starting tessera nodes"
  ./tessera-start-remote.sh ${tesseraOptions}
else
  echo "Unsupported privacy implementation: ${privacyImpl}"
  usage
fi

echo "[*] Starting $numNodes Ethereum nodes with ChainID and NetworkId of $NETWORK_ID"
QUORUM_GETH_ARGS=${QUORUM_GETH_ARGS:-}
set -v
ARGS="--nodiscover --verbosity 5 --networkid $NETWORK_ID --raft --rpc --rpccorsdomain=* --rpcvhosts=* --rpcaddr 0.0.0.0 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,raft --emitcheckpoints --unlock 0 --password passwords.txt $QUORUM_GETH_ARGS"

basePort=21000
rpcPort=22000
raftPort=50401

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')

port=$(($basePort + ${INDEX_NODE} - 1))
permissioned=
if [[ $INDEX_NODE -le 4 ]]; then
    permissioned="--permissioned"
fi
PRIVATE_CONFIG=qdata/c${INDEX_NODE}/tm.ipc nohup geth --datadir qdata/dd ${ARGS} ${permissioned} --raftport ${raftPort} --rpcport ${rpcPort} --port ${port} 2>>qdata/logs/geth.log &

set +v

echo
echo "All nodes configured. See 'qdata/logs' for logs, and run e.g. 'geth attach qdata/dd/geth.ipc' to attach to the first Geth node."
echo "To test sending a private transaction from Node 1 to Node 7, run './runscript.sh private-contract.js'"

exit 0