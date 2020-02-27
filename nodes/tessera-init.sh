#!/usr/bin/env bash
# Initialise data for Tessera nodes.
# This script will normally perform initialisation for 7 nodes, however
# if file qdata/numberOfNodes exists then the script will read number
# of nodes from that file.

numNodes=7
if [[ -f qdata/numberOfNodes ]]; then
    numNodes=`cat qdata/numberOfNodes`
fi

echo "[*] Initialising Tessera configuration for $numNodes node(s)"

INDEX_NODE=$(cat ~/node_config | grep "NODE_INDEX" | awk -F '=' '{print $2}')
NODE_IP=$(cat ~/node_config | grep "NODE_IP" | awk -F '=' '{print $2}')

# Write the config for the Tessera nodes
currentDir=$(pwd)

DDIR="${currentDir}/qdata/c${INDEX_NODE}"
mkdir -p ${DDIR}
mkdir -p qdata/logs
cp "keys/tm${INDEX_NODE}.pub" "${DDIR}/tm.pub"
cp "keys/tm${INDEX_NODE}.key" "${DDIR}/tm.key"
rm -f "${DDIR}/tm.ipc"

serverPortP2P=9001
serverPortThirdParty=$((9080 + ${INDEX_NODE}))
serverPortEnclave=$((9180 + ${INDEX_NODE}))

    #change tls to "strict" to enable it (don't forget to also change http -> https)
cat <<EOF > ${DDIR}/tessera-config-09-${INDEX_NODE}.json
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:${DDIR}/db${INDEX_NODE};MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "serverConfigs":[
        {
            "app":"ThirdParty",
            "enabled": true,
            "serverAddress": "http://${NODE_IP}:${serverPortThirdParty}",
            "communicationType" : "REST"
        },
        {
            "app":"Q2T",
            "enabled": true,
            "serverAddress":"unix:${DDIR}/tm.ipc",
            "communicationType" : "REST"
        },
        {
            "app":"P2P",
            "enabled": true,
            "serverAddress":"http://${NODE_IP}:${serverPortP2P}",
            "sslConfig": {
                "tls": "OFF",
                "generateKeyStoreIfNotExisted": true,
                "serverKeyStore": "${DDIR}/server${INDEX_NODE}-keystore",
                "serverKeyStorePassword": "quorum",
                "serverTrustStore": "${DDIR}/server-truststore",
                "serverTrustStorePassword": "quorum",
                "serverTrustMode": "TOFU",
                "knownClientsFile": "${DDIR}/knownClients",
                "clientKeyStore": "${DDIR}/client${INDEX_NODE}-keystore",
                "clientKeyStorePassword": "quorum",
                "clientTrustStore": "${DDIR}/client-truststore",
                "clientTrustStorePassword": "quorum",
                "clientTrustMode": "TOFU",
                "knownServersFile": "${DDIR}/knownServers"
            },
            "communicationType" : "REST"
        }
    ],
    "peer": [
    ],
    "keys": {
        "passwords": [],
        "keyData": [
            {
                "privateKeyPath": "${DDIR}/tm.key",
                "publicKeyPath": "${DDIR}/tm.pub"
            }
        ]
    },
    "alwaysSendTo": []
}
EOF

# Enclave configurations

cat <<EOF > ${DDIR}/tessera-config-enclave-09-${INDEX_NODE}.json
{
    "useWhiteList": false,
    "jdbc": {
        "username": "sa",
        "password": "",
        "url": "jdbc:h2:${DDIR}/db${INDEX_NODE};MODE=Oracle;TRACE_LEVEL_SYSTEM_OUT=0",
        "autoCreateTables": true
    },
    "serverConfigs":[
        {
            "app":"ENCLAVE",
            "enabled": true,
            "serverAddress": "http://${NODE_IP}:${serverPortEnclave}",
            "communicationType" : "REST"
        },
        {
            "app":"ThirdParty",
            "enabled": true,
            "serverAddress": "http://${NODE_IP}:${serverPortThirdParty}",
            "communicationType" : "REST"
        },
        {
            "app":"Q2T",
            "enabled": true,
             "serverAddress":"unix:${DDIR}/tm.ipc",
            "communicationType" : "REST"
        },
        {
            "app":"P2P",
            "enabled": true,
            "serverAddress":"http://${NODE_IP}:${serverPortP2P}",
            "sslConfig": {
                "tls": "OFF"
            },
            "communicationType" : "REST"
        }
    ],
    "peer": [
    ]
}
EOF

cat <<EOF > ${DDIR}/enclave-09-${INDEX_NODE}.json
{
    "serverConfigs":[
        {
            "app":"ENCLAVE",
            "enabled": true,
            "serverAddress": "http://${NODE_IP}:${serverPortEnclave}",
            "communicationType" : "REST"
        }
    ],
    "keys": {
        "passwords": [],
        "keyData": [
            {
                "privateKeyPath": "${DDIR}/tm.key",
                "publicKeyPath": "${DDIR}/tm.pub"
            }
        ]
    },
    "alwaysSendTo": []
}
EOF
