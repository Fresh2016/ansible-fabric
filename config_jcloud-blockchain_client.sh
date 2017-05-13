#!/bin/bash

#
# basic variables
#
export _file_name=$(readlink -f $0)
export _path_name=$(dirname ${_file_name})
export _script_name=$(basename ${_file_name})

#
# global constant varialbes
#
channel_id="supplychain"

# dst
dst_root="/jcloud-blockchain"
dst_conf_dir="${dst_root}/app/manage/data"

dst_channel_tx="${dst_conf_dir}/${channel_id}.tx"
dst_channel_js="${dst_conf_dir}/channel.js"
dst_tls_dir="${dst_conf_dir}/tls"
dst_network_js="${dst_conf_dir}/network.js"

# src
src_root="/root/ansible-fabric"
src_orderer_node="orderer.hfc.jcloud.com"
src_orderer_org="`echo ${src_orderer_node} | cut -d '.' -f 2-`"
src_channel_tx="${src_root}/roles/fabric-orderer/files/${src_orderer_org}/orderers/${src_orderer_node}/${channel_id}.tx"
src_channel_js="${src_root}/config/channel.js"
src_network_js_tls="${src_root}/config/tls.network.js"
src_network_js_notls="${src_root}/config/notls.network.js"
src_orderer_tls="${src_root}/roles/fabric-orderer/files/${src_orderer_org}/orderers/${src_orderer_node}/tls/ca.crt"

# templating
src_peer_node=""
#src_peer_org="`echo ${src_peer_node} | cut -d '.' -f 2-`"
#src_peer_tls="${src_root}/roles/fabric-peer/files/${src_peer_org}/peers/${src_peer_node}/tls/ca.crt"
src_peer_list="peer1.org1.hfc.jcloud.com 
peer2.org1.hfc.jcloud.com 
peer3.org1.hfc.jcloud.com 
peer1.org2.hfc.jcloud.com 
peer2.org2.hfc.jcloud.com 
peer3.org2.hfc.jcloud.com "

#
# global command-line args
#
instance_name=${instance_name:='verify'}

#
# help message
#
help() {
    echo "help:"
    echo "    ./${_script_name} --tls|--notls [JCLOUD_CLIENT_instance_name]"
    echo ""
    echo "    --tls    -> copy tls enabled configuration files"
    echo "    --notls  -> copy no tls configuration files"
    echo ""
    echo "    [JCLOUD_CLIENT_instance_name]"
    echo "             -> Container name running for jcloud-blockchain client by shiying"
    exit 0
}

#
# get args from command-line
#
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
    instance_name=$2
fi

echo "++++++++ START ++++++++"

#
# check to working directory
#
cd ansible-fabric

#
# check instance exists or not
#
is_found=`docker ps -f status=running -f name="${instance_name}"$`
if [[ ! ${is_found} ]]; then
    echo ">> ${instance_name} is NOT found, exit ... "
    exit 1
fi

#
# cleanup old configs
#
echo ">> backup existing config files from ${instance_name} for ${channel_id}... "
docker exec ${instance_name} bash -c "mv -f ${dst_channel_tx} ${dst_channel_tx}.`date +%Y%m%d-%H%M%S`"
docker exec ${instance_name} bash -c "mv -f ${dst_channel_js} ${dst_channel_js}.`date +%Y%m%d-%H%M%S`"
docker exec ${instance_name} bash -c "mv -f ${dst_tls_dir} ${dst_tls_dir}.`date +%Y%m%d-%H%M%S`"
docker exec ${instance_name} bash -c "mv -f ${dst_network_js} ${dst_network_js}.`date +%Y%m%d-%H%M%S`"

echo ">> copying new config files to ${instance_name} for ${channel_id}... "
echo "   Copying ${channel_id}.tx ... "
docker cp ${src_channel_tx} ${instance_name}:${dst_conf_dir}/

echo "   Copying ${channel_id}.js ... "
docker cp ${src_channel_js} ${instance_name}:${dst_conf_dir}/

echo "   Copying notls.network.js ... "
docker cp ${src_network_js_notls} ${instance_name}:${dst_conf_dir}/

echo "   Copying tls.network.js ... "
docker cp ${src_network_js_tls} ${instance_name}:${dst_conf_dir}/

echo "   copying new tls files ... "
for src_peer_node in ${src_peer_list}; do
    echo "   Copying tls for ${src_peer_node}  ... "
    src_peer_org="`echo ${src_peer_node} | cut -d '.' -f 2-`"
    src_peer_tls="${src_root}/roles/fabric-peer/files/${src_peer_org}/peers/${src_peer_node}/tls/ca.crt"
    docker exec ${instance_name} bash -c "mkdir -p ${dst_conf_dir}/tls/${src_peer_node}"
    docker cp ${src_peer_tls} ${instance_name}:${dst_conf_dir}/tls/${src_peer_node}/
done
echo "   copying tls for ${src_orderer_node} ..."
docker exec ${instance_name} bash -c "mkdir -p ${dst_conf_dir}/tls/${src_orderer_node}"
docker cp ${src_orderer_tls} ${instance_name}:${dst_conf_dir}/tls/${src_orderer_node}/

echo "   Config network.js ... "
if [[ "${TLS}" == "yes" ]]; then
    docker exec ${instance_name} bash -c "cp -f ${dst_conf_dir}/tls.network.js ${dst_network_js}"
else
    docker exec ${instance_name} bash -c "cp -f ${dst_conf_dir}/notls.network.js ${dst_network_js}"
fi

echo "   Temporarily replace common files ... "
docker cp ${src_root}/config/app/manage/create-client.js  ${instance_name}:${dst_root}/app/manage/
docker cp ${src_root}/config/app/manage/param-interceptor.js  ${instance_name}:${dst_root}/app/manage/
docker cp ${src_root}/config/verify.js  ${instance_name}:${dst_root}/
docker exec ${instance_name} bash -c "chmod +x ${dst_root}/verify.js"

echo "++++++++ DONE ++++++++"

#echo "   Login to ${instance_name} ... "
#docker exec -it ${instance_name} bash
