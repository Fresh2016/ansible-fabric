var data = {
    "orderer": {
        "url": "grpcs://113.209.68.126:7050",
        "server-hostname": "orderer.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/orderer.hfc.jcloud.com/ca.crt"
    },
    "peer101": {
        "requests": "grpcs://113.209.68.128:7051",
        "events": "grpcs://113.209.68.128:7053",
        "server-hostname": "peer1.org1.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer1.org1.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org1"
    },
    "peer102": {
        "requests": "grpcs://120.132.114.36:7051",
        "events": "grpcs://120.132.114.36:7053",
        "server-hostname": "peer2.org1.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer2.org1.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org1"
    },
    "peer103": {
        "requests": "grpcs://103.235.241.129:7051",
        "events": "grpcs://103.235.241.129:7053",
        "server-hostname": "peer3.org1.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer3.org1.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org1"
    },
    "peer201": {
        "requests": "grpcs://120.132.114.37:7051",
        "events": "grpcs://120.132.114.37:7053",
        "server-hostname": "peer1.org2.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer1.org2.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org2"
    },
    "peer202": {
        "requests": "grpcs://113.209.68.131:7051",
        "events": "grpcs://113.209.68.131:7053",
        "server-hostname": "peer2.org2.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer2.org2.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org2"
    },
    "peer203": {
        "requests": "grpcs://120.132.114.193:7051",
        "events": "grpcs://120.132.114.193:7053",
        "server-hostname": "peer3.org2.hfc.jcloud.com",
        "tls_cacerts": "/jcloud-blockchain/app/manage/data/tls/peer3.org2.hfc.jcloud.com/ca.crt",
        "isAnchor": "true",
        "assign": "org2"
    },


    "org1": {
        "name": "org1",
        "mspid": "Org1MSP",
        "ca": "https://113.209.68.127:7054"
    },
    "org2": {
        "name": "org2",
        "mspid": "Org2MSP",
        "ca": "https://120.132.114.32:7054"
    }
}

var network = {
    "orderer": data.orderer,
    "org1": {
        "name": data.org1.name,
        "mspid": data.org1.mspid,
        "ca": data.org1.ca,
        "peer1": data.peer101,
        "peer2": data.peer102,
        "peer3": data.peer103
    },
    "org2": {
        "name": data.org2.name,
        "mspid": data.org2.mspid,
        "ca": data.org2.ca,
        "peer1": data.peer201,
        "peer2": data.peer202,
        "peer3": data.peer203
    }
}

exports.getData = function(mode) {
    if (mode) {
        return data[mode];
    }
    return data;
}


exports.getAllNetwork = function() {
    return network;
}