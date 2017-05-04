TGZ=crypto-config.v1.0.0-6peers-$(date +%Y%m%d%H%M%S-%N).tgz
tar -czvf ${TGZ} crypto-config/

```

## Optional, For fabric-sdk

```bash
export _FileName=$(readlink -f $0)
export _DirName=$(dirname ${_FileName})
export _ScriptVersion="2017.03.02"
export _ScriptName=$(basename ${_FileName})

CONTAINER_NAME=${CONTAINER_NAME:='verify'}

help() {
    echo "help:"
    echo "    ./${_ScriptName} --tls|--notls [JCLOUD_CLIENT_CONTAINER_NAME]"
    echo ""
    echo "    --tls    -> copy tls enabled configuration files"
    echo "    --notls  -> copy no tls configuration files"
    echo ""
    echo "    [JCLOUD_CLIENT_CONTAINER_NAME]"
    echo "             -> Container name running for jcloud-blockchain client by shiying"
    exit 0
}

if [[ $# > '2' ]]; then
    echo "[ERROR] Only take 2 args."
    echo "      You enter $# args --> \"$@\""
    echo ""
    help
fi

if [[ "$1" == "--tls" ]]; then
    TLS="yes"
elif [[ "$1" == "--notls" ]]; then
    TLS="no"
else
    help
fi

if [[ -n "$2" ]]; then
    CONTAINER_NAME=$2
fi

if [[ `docker ps --format {{.Names}} | grep ^"${CONTAINER_NAME}"$` ]]; then
    echo ">> ${CONTAINER_NAME} is found, continue to config ${CONTAINER_NAME} ... "
else
    echo ">> ${CONTAINER_NAME} is NOT found, exit ... "
    exit 1
fi
echo ">> Cleanup old config files from ${CONTAINER_NAME} ... "
docker exec ${CONTAINER_NAME} \
       sh -c 'rm -f /jcloud-blockchain/app/config/supplychain.tx ; \
              rm -f /jcloud-blockchain/app/config/configtx.yaml ;  \
              rm -f /jcloud-blockchain/app/config/config.json ;    \
              ls -lh /jcloud-blockchain/app/config/'

echo ">> Copy new config files to ${CONTAINER_NAME} ... "
docker cp roles/fabric-orderer/files/hfc.jcloud.com/orderers/orderer.hfc.jcloud.com/supplychain.tx ${CONTAINER_NAME}:/jcloud-blockchain/app/config/
docker cp roles/fabric-orderer/files/hfc.jcloud.com/orderers/orderer.hfc.jcloud.com/configtx.yaml ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

docker cp config.notls.json ${CONTAINER_NAME}:/jcloud-blockchain/app/config/
docker cp config.tls.json ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

NODES_LIST='orderer.hfc.jcloud.com 
peer1.org1.hfc.jcloud.com 
peer2.org1.hfc.jcloud.com 
peer3.org1.hfc.jcloud.com 
peer1.org2.hfc.jcloud.com 
peer2.org2.hfc.jcloud.com 
peer3.org2.hfc.jcloud.com '

for NODE in ${NODES_LIST} ; do
    echo "cleanup old files for ${NODE} ..."
    docker exec ${CONTAINER_NAME} \
       sh -c "rm -rf /jcloud-blockchain/app/config/tls/clliu/${NODE}/*"
    docker exec ${CONTAINER_NAME} \
       sh -c "mkdir -p /jcloud-blockchain/app/config/tls/clliu/${NODE}"
done

echo "copying new certs files ..."
docker cp roles/fabric-orderer/files/hfc.jcloud.com/orderers/orderer.hfc.jcloud.com/tls/server.crt ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/orderer.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org1.hfc.jcloud.com/peers/peer1.org1.hfc.jcloud.com/tls/server.crt ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer1.org1.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org1.hfc.jcloud.com/peers/peer2.org1.hfc.jcloud.com/tls/server.crt  ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer2.org1.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org1.hfc.jcloud.com/peers/peer3.org1.hfc.jcloud.com/tls/server.crt  ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer3.org1.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org2.hfc.jcloud.com/peers/peer1.org2.hfc.jcloud.com/tls/server.crt ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer1.org2.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org2.hfc.jcloud.com/peers/peer2.org2.hfc.jcloud.com/tls/server.crt ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer2.org2.hfc.jcloud.com/

docker cp roles/fabric-peer/files/org2.hfc.jcloud.com/peers/peer3.org2.hfc.jcloud.com/tls/server.crt ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peer3.org2.hfc.jcloud.com/

if [[ "${TLS}" == "yes" ]]; then
    docker exec ${CONTAINER_NAME} sh -c 'cp -f /jcloud-blockchain/app/config/config.tls.json /jcloud-blockchain/app/config/config.json'
else
    docker exec ${CONTAINER_NAME} sh -c 'cp -f /jcloud-blockchain/app/config/config.notls.json /jcloud-blockchain/app/config/config.json'
fi

docker exec ${CONTAINER_NAME} sh -c 'ls -lh /jcloud-blockchain/app/config/'
echo ">> DONE ... "

#docker exec -it ${CONTAINER_NAME} bash
