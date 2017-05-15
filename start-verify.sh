#!/bin/bash

image="shiying/jcloud-blockchain:1.7"
instance_name=${instance_name:='verify'}

if [[ -n "$1" ]]; then
    instance_name=$2
fi

channel_tx="$(pwd)/roles/fabric-orderer/files/hfc.jcloud.com/orderers/orderer.hfc.jcloud.com/supplychain.tx"
channel_js="$(pwd)/config/app/manage/data/channel.js"
network_js="$(pwd)/config/app/manage/data/notls.network.js"

create_client_js="$(pwd)/config/app/manage/create-client.js"
param_interceptor_js="$(pwd)/config/app/manage/param-interceptor.js"

dst_path="/jcloud-blockchain/app/manage"

docker run  -d \
            -p 5081:8081 \
            -e LOCK_PWD=blockgodie \
            -v ${channel_tx}:${dst_path}/data/supplychain.tx \
            -v ${channel_js}:${dst_path}/data/channel.js \
            -v ${network_js}:${dst_path}/data/network.js \
            -v ${create_client_js}:${dst_path}/create-client.js \
            -v ${param_interceptor_js}:${dst_path}/param-interceptor.js \
            --name=${instance_name} \
            ${image}
