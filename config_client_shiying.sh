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
docker exec ${CONTAINER_NAME} sh -c 'rm -f /jcloud-blockchain/app/config/mychannel.tx'
docker exec ${CONTAINER_NAME} sh -c 'rm -f /jcloud-blockchain/app/config/configtx.yaml'
docker exec ${CONTAINER_NAME} sh -c 'rm -f /jcloud-blockchain/app/config/config.json'
docker exec ${CONTAINER_NAME} sh -c 'ls -lh /jcloud-blockchain/app/config/'

echo ">> Copy new config files to ${CONTAINER_NAME} ... "
echo "   Copy mychannel.tx ... "
docker cp ./roles/fabric-orderer/files/ordererorg1/orderers/ordererorg1orderer1/mychannel.tx ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

echo "   Copy configtx.yaml ... "
docker cp ./roles/fabric-orderer/files/ordererorg1/orderers/ordererorg1orderer1/configtx.yaml ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

echo "   Copy config.notls.json ... "
docker cp ./config.notls.json ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

echo "   Copy config.tls.json ... "
docker cp ./config.tls.json ${CONTAINER_NAME}:/jcloud-blockchain/app/config/

echo "   Create directories ... "
docker exec ${CONTAINER_NAME} sh -c 'cd /jcloud-blockchain/app/config/tls/; mkdir -p clliu && cd clliu; for DIR in ordererorg1orderer1 peerorg1peer1 peerorg1peer2 peerorg2peer1 peerorg2peer2 ; do mkdir -p $DIR ; done'

echo "   Copy certs  ... "
docker cp ./roles/fabric-orderer/files/ordererorg1/orderers/ordererorg1orderer1/cacerts/ordererorg1-cert.pem ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/ordererorg1orderer1/
docker cp ./roles/fabric-peer/files/peerorg1/peers/peerorg1peer1/cacerts/peerorg1-cert.pem ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peerorg1peer1/
docker cp ./roles/fabric-peer/files/peerorg1/peers/peerorg1peer2/cacerts/peerorg1-cert.pem ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peerorg1peer2/
docker cp ./roles/fabric-peer/files/peerorg2/peers/peerorg2peer1/cacerts/peerorg2-cert.pem ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peerorg2peer1/
docker cp ./roles/fabric-peer/files/peerorg2/peers/peerorg2peer2/cacerts/peerorg2-cert.pem ${CONTAINER_NAME}:/jcloud-blockchain/app/config/tls/clliu/peerorg2peer2/

echo "   Config config.json ... "
if [[ "${TLS}" == "yes" ]]; then
    docker exec ${CONTAINER_NAME} sh -c 'cp -f /jcloud-blockchain/app/config/config.tls.json /jcloud-blockchain/app/config/config.json'
else
    docker exec ${CONTAINER_NAME} sh -c 'cp -f /jcloud-blockchain/app/config/config.notls.json /jcloud-blockchain/app/config/config.json'
fi

docker exec ${CONTAINER_NAME} sh -c 'ls -lh /jcloud-blockchain/app/config/'
echo ">> DONE ... "

echo "   Login to ${CONTAINER_NAME} ... "
docker exec -it ${CONTAINER_NAME} bash
