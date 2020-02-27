#!/bin/bash
set -u
set -e

function usage() {
  echo ""
  echo "Usage:"
  echo "    $0 [--tesseraJar path to Tessera jar file] [--remoteDebug] [--jvmParams \"JVM parameters\"] [--remoteEnclaves <number of remote enclaves>]"
  echo ""
  echo "Where:"
  echo "    --tesseraJar specifies path to the jar file, default is to use the ubuntu location"
  echo "    --remoteDebug enables remote debug on port 500n for each Tessera node (for use with JVisualVm etc)"
  echo "    --jvmParams specifies parameters to be used by JVM when running Tessera"
  echo "    --remoteEnclaves specifies the number of nodes that should be using a remote enclave"
  echo "Notes:"
  echo "    Tessera jar location defaults to ${defaultTesseraJarExpr};"
  echo "    Enclave jar location defaults to ${defaultEnclaveJarExpr};"
  echo "    however, this can be overridden by environment variable TESSERA_JAR or ENCLAVE_JAR or by the command line option."
  echo ""
  exit -1
}

defaultNumberOfRemoteEnclaves=4
defaultEnclaveJarExpr="/home/ubuntu/tessera/enclave.jar"
defaultTesseraJarExpr="/home/ubuntu/tessera/tessera.jar"

set +e
defaultTesseraJar=`find ${defaultTesseraJarExpr} 2>/dev/null`
set -e
if [[ "${TESSERA_JAR:-unset}" == "unset" ]]; then
  tesseraJar=${defaultTesseraJar}
else
  tesseraJar=${TESSERA_JAR}
fi

set +e
defaultEnclaveJar=`find ${defaultEnclaveJarExpr} 2>/dev/null`
set -e
if [[ "${ENCLAVE_JAR:-unset}" == "unset" ]]; then
  enclaveJar=${defaultEnclaveJar}
else
  enclaveJar=${ENCLAVE_JAR}
fi

numberOfRemoteEnclaves=${defaultNumberOfRemoteEnclaves}

PEERS_CMD=""

IN=$(cat ~/node_config | grep "PEER_IPS" | awk -F '=' '{print $2}')
IFS=',' read -ra PEER <<< "$IN"
for i in "${PEER[@]}"; do
    PEERS_CMD+=" --peer.url http://$i:9001"
done

remoteDebug=false
jvmParams=
while (( "$#" )); do
  case "$1" in
    --tesseraJar)
      tesseraJar=$2
      shift 2
      ;;
    --remoteEnclaves)
      numberOfRemoteEnclaves=$2
      shift 2
      ;;
    --enclaveJar)
      enclaveJar=$2
      shift 2
      ;;
    --remoteDebug)
      remoteDebug=true
      shift
      ;;
    --jvmParams)
      jvmParams=$2
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

if [  "${tesseraJar}" == "" ]; then
  echo "ERROR: unable to find Tessera jar file using TESSERA_JAR envvar, or using ${defaultTesseraJarExpr}"
  usage
elif [  ! -f "${tesseraJar}" ]; then
  echo "ERROR: unable to find Tessera jar file: ${tesseraJar}"
  usage
fi

if [  "${enclaveJar}" == "" ]; then
  echo "ERROR: unable to find Enclave jar file using ENCLAVE_JAR envvar, or using ${defaultEnclaveJarExpr}"
  usage
elif [  ! -f "${enclaveJar}" ]; then
  echo "ERROR: unable to find Enclave jar file: ${enclaveJar}"
  usage
fi

#extract the tessera version from the jar
TESSERA_VERSION=$(unzip -p $tesseraJar META-INF/MANIFEST.MF | grep Tessera-Version | cut -d" " -f2)
echo "Tessera version (extracted from manifest file): $TESSERA_VERSION"

TESSERA_CONFIG_TYPE="-09-"

#if the Tessera version is 0.10, use this config version
if [ "$TESSERA_VERSION" \> "0.10" ] || [ "$TESSERA_VERSION" == "0.10" ]; then
    TESSERA_CONFIG_TYPE="-09-"
fi

echo "Config type $TESSERA_CONFIG_TYPE"


# Order of operation:
# Start up the remote enclaves
# Wait for remote enclaves to finish startup
# Start up remote enclave enabled transaction managers
# Start up local enclave transaction managers
# Wait for all transaction managers to finish startup

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')

if [[ $INDEX_NODE -le numberOfRemoteEnclaves ]]; then
  DDIR="qdata/c$INDEX_NODE"
  mkdir -p ${DDIR}
  mkdir -p qdata/logs
  rm -f "$DDIR/tm.ipc"

  DEBUG=""
  if [ "$remoteDebug" == "true" ]; then
    DEBUG="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=501$INDEX_NODE -Xdebug"
  fi

  #Only set heap size if not specified on command line
  MEMORY=
  if [[ ! "$jvmParams" =~ "Xm" ]]; then
    MEMORY="-Xms128M -Xmx128M"
  fi

  CMD="java $jvmParams $DEBUG $MEMORY -jar ${enclaveJar} -configfile $DDIR/enclave$TESSERA_CONFIG_TYPE$INDEX_NODE.json"
  echo "$CMD >> qdata/logs/enclave$INDEX_NODE.log 2>&1 &"
  nohup ${CMD} >> "qdata/logs/enclave$INDEX_NODE.log" 2>&1 &
  sleep 1
fi

#Wait until Enclaves are running
echo "Waiting until all Tessera enclaves are running..."
DOWN=true
k=10
while ${DOWN}; do
    sleep 1
    DOWN=false
    if [[ $INDEX_NODE -le numberOfRemoteEnclaves ]]; then
        set +e

        result=$(curl -s http://localhost:918${INDEX_NODE}/ping)
        set -e
        if [ ! "${result}" == "STARTED" ]; then
            echo "Enclave ${INDEX_NODE} is not yet listening on http"
            DOWN=true
        fi
    fi

    k=$((k - 1))
    if [ ${k} -le 0 ]; then
        echo "Tessera is taking a long time to start.  Look at the Tessera logs in qdata/logs/ for help diagnosing the problem."
    fi
    echo "Waiting until all Tessera enclaves are running..."

    sleep 5
done

#Startup remote enclave Transaction Managers while INDEX_NODE <= numberOfRemoteEnclaves
currentDir=`pwd`
if [[ $INDEX_NODE -le numberOfRemoteEnclaves ]]; then
    DDIR="qdata/c$INDEX_NODE"
    mkdir -p ${DDIR}
    mkdir -p qdata/logs
    rm -f "$DDIR/tm.ipc"

    DEBUG=""
    if [ "$remoteDebug" == "true" ]; then
      DEBUG="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=500$INDEX_NODE -Xdebug"
    fi

    #Only set heap size if not specified on command line
    MEMORY=
    if [[ ! "$jvmParams" =~ "Xm" ]]; then
      MEMORY="-Xms128M -Xmx128M"
    fi

    CMD="java $jvmParams $DEBUG $MEMORY -jar ${tesseraJar} -configfile $DDIR/tessera-config-enclave$TESSERA_CONFIG_TYPE$INDEX_NODE.json ${PEERS_CMD}"
    echo "$CMD >> qdata/logs/tessera$INDEX_NODE.log 2>&1 &"
    nohup ${CMD} >> "qdata/logs/tessera$INDEX_NODE.log" 2>&1 &
    sleep 1
fi

#Startup local enclave Transaction Managers while INDEX_NODE > numberOfRemoteEnclaves
if [[ $INDEX_NODE -gt numberOfRemoteEnclaves ]]; then
    DDIR="qdata/c$INDEX_NODE"
    mkdir -p ${DDIR}
    mkdir -p qdata/logs
    rm -f "$DDIR/tm.ipc"

    DEBUG=""
    if [ "$remoteDebug" == "true" ]; then
      DEBUG="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=500$INDEX_NODE -Xdebug"
    fi

    #Only set heap size if not specified on command line
    MEMORY=
    if [[ ! "$jvmParams" =~ "Xm" ]]; then
      MEMORY="-Xms128M -Xmx128M"
    fi

    CMD="java $jvmParams $DEBUG $MEMORY -jar ${tesseraJar} -configfile $DDIR/tessera-config$TESSERA_CONFIG_TYPE$INDEX_NODE.json ${PEERS_CMD}"
    echo "$CMD >> qdata/logs/tessera.log 2>&1 &"
    nohup ${CMD} >> "qdata/logs/tessera.log" 2>&1 &
    sleep 1
fi

#Wait until transaction managers are running
echo "Waiting until Tessera nodes are running..."
DOWN=true
k=10
while ${DOWN}; do
    sleep 1
    DOWN=false

    if [ ! -S "qdata/c${INDEX_NODE}/tm.ipc" ]; then
        echo "Node ${INDEX_NODE} is not yet listening on tm.ipc"
        DOWN=true
    fi

    set +e
    #NOTE: if using https, change the scheme
    #NOTE: if using the IP whitelist, change the host to an allowed host
    result=$(curl -s http://localhost:9001/upcheck)
    set -e
    if [ ! "${result}" == "I'm up!" ]; then
        echo "Node ${INDEX_NODE} is not yet listening on http"
        DOWN=true
    fi

    k=$((k - 1))
    if [ ${k} -le 0 ]; then
        echo "Tessera is taking a long time to start.  Look at the Tessera logs in qdata/logs/ for help diagnosing the problem."
    fi
    echo "Waiting until all Tessera nodes are running..."

    sleep 5
done

echo "All Tessera nodes started"
exit 0
