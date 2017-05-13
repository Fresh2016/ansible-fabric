var ClientUtils = require('fabric-client/lib/utils.js');
var config = require('./data/channel.js').getConfig();
var netWorkinfo = require('./data/network.js');
var network = netWorkinfo.getData();
var allNetWork = netWorkinfo.getAllNetwork();
var logger = ClientUtils.getLogger('param-interceptor');
var manage = require('./create-client.js')
var rf = require("fs");


/**
 * Parameter filter
 * @param req
 */
exports.filterParams = function(req, res) {
        return setParams(req, res)
            .then((response) => {
                //            if(response && !req.query.isCreate){
                //                return  vifchannelName(req,res);
                //            }else{
                //                return  new Promise((resolve, reject) => resolve(false));
                //            }
                return new Promise((resolve, reject) => resolve(false));
            }).catch((err) => {
                logger.error('filterParams error %s', JSON.stringify(err));
                return new Promise((resolve, reject) => resolve(err));
            });
    }
    /**
     * 设置 Param参数
     * @param req
     * @param res
     * @returns {Promise}
     */
function setParams(req, res) {
    try {

        logger.debug('Interceptor received request: %j', req);
        var params = req.query.params || req.body.params;
        if (null != params) {
            if (typeof(params) != "object") {
                params = JSON.parse(params);
                req.query.params = params;
            } else {
                req.query.params = params;
            }

            if (isEmptyObject(req.params)) {
                setChannel(req, res);
            }

            req.query.params['channelName'] = req.params.channelName;

            if (null != params.chaincode) {
                setChaincodePath(req, res);
            } else {
                req.query.isQueryBlock = true;
            }

            setNetwork(req, res);


        } else {
            req.query.params = {}
            req.query.params['channelName'] = req.params.channelName;
            throw new Error('params is null');
        }

        logger.debug('Finish update request query params: %j', req.query.params);
        return new Promise((resolve, reject) => resolve(true));

    } catch (err) {
        logger.error('Error in updating request query params %s', JSON.stringify(err));
        //return res.json("Error in updating request query params");
        err.message = "Error in updating request query params";
        return new Promise((resolve, reject) => reject(err));
    }
}

/**
 * 校验是否存在req.query.params或者req.body.params,都赋值到req.query.params
 * @param req
 */
function checkQueryParam(req) {
    //设置query里面的channelName
    var params = req.query.params || req.body.params;
    logger.debug('Interceptor gets parameters from request: %j', params);

    if (null == req.query.params) {
        req.query.params = JSON.parse(JSON.stringify(params));
    }
    if (null == req.body.params) {
        req.body.params = JSON.parse(JSON.stringify(params));
    }
    return params;
}

/**
 * 校验是否存在channel,不存在，重新创建
 * @param req
 */
function vifchannelName(req, res) {
    return manage.queryIsChannel(req.query.params)
        .then((response) => {
            if (!response) {
                return reCreate(req, res);
            } else {
                return new Promise((resolve, reject) => resolve(true));
            }
        }).catch((err) => {
            logger.error('vifchannelName error %s', JSON.stringify(err));
            return new Promise((resolve, reject) => resolve(false));
        });
}
/**
 * 重新创建
 * @param req
 * @param res
 * @returns {Promise.<T>|*|Observable}
 */
function reCreate(req, res) {
    return setTxFileData(req, res)
        .then((response) => {
            if (response) {
                return manage.create(req.query.params);
            } else {
                return new Promise((resolve, reject) => reject(false));
            }
        }).catch((err) => {
            logger.error('vifchannelName error %s', JSON.stringify(err));
            return new Promise((resolve, reject) => reject(err));
        });
}
/**
 * 设置Channel的名字、版本和Tx文件
 * @param req
 */
function setChannel(req, res) {
    try {
        //todo 第二个参数必须是 Channelname ，如果不是，就需要调整
        var originalUrl = req.originalUrl;
        var originalList = originalUrl.split("/");
        if (2 === originalList.length) {
            logger.debug('Creating channel. About to set channel name and Tx file');
            var reqChannelname = "";
            if (null != req.query.params && null != req.query.params.channel && null != req.query.params.channel.name) {
                reqChannelname = req.query.params.channel.name;
            } else if (null != req.body.params && null != req.body.params.channel && null != req.body.params.channel.name) {
                reqChannelname = req.body.params.channel.name;
            }
            if (!reqChannelname) {
                //get请求的时候，需要截取
                //reqChannelname= originalList[2].replace('supplychain', 'mychannel');
                reqChannelname = originalList[2];
                if (reqChannelname.indexOf("?") >= 0) {
                    reqChannelname = reqChannelname.split("?")[0];
                }
            }
            logger.info('reqChannelname is -- %s', reqChannelname);

            //创建逻辑
            req.query.isCreate = true;
            setChannelName(req, res, reqChannelname);
            setTxFileData(req, res);

        } else if (3 === originalList.length) {
            // FIXME: should be removed when new certs work with correct channel name
            //get请求的时候，需要截取
            //var tempChannelName = originalList[2].replace('supplychain', 'mychannel');
            var tempChannelName = originalList[2];
            if (tempChannelName.indexOf("?") >= 0) {
                tempChannelName = tempChannelName.split("?")[0];
            }
            logger.debug('Operating channel %s. About to set channel name in params', tempChannelName);
            setChannelName(req, res, tempChannelName);

        } else {
            throw new Error('Original URL unrecognized');
        }
        logger.debug('Channel set in params. Updated params: %j', req.params);

    } catch (err) {
        logger.error('setChannel error %s', JSON.stringify(err));
    }
}

/**
 * 设置Channel的名字
 * @param req
 */
function setChannelName(req, res, reqChannelname) {
    var channelList = config.list;

    if (channelList.indexOf(reqChannelname) < 0) {
        throw new Error("Config channelname not exist. Check content in ./data/network.js");
    } else {
        //设置query里面的 channelName
        if (isEmptyObject(req.params)) {
            req.params = {
                channelName: reqChannelname
            };
        } else {
            req.params.channelName = reqChannelname;
        }

        logger.debug('Channel name set in params. Updated channel: %j', req.params.channelName);
    }


}


/**
 * 设置Chaincode的Path
 * @param req
 */
function setChaincodePath(req, res) {
    try {
        if (!req.query.isCreate) {
            var chaincodePath = config[req.query.params['channelName']]['chainCode'][req.query.params.chaincode.name].path;
            req.query.params.chaincode.path = chaincodePath;;
        }

        logger.debug('Chaincode path set in params. Updated chaincode: %j', req.query.params.chaincode);
    } catch (err) {
        logger.error('setChaincodePath error %s', JSON.stringify(err));
    }
}
/**
 * 设置network
 * @param req
 * @param res
 */
function setNetwork(req, res) {
    try {
        if (req.query.isCreate || req.query.isQueryBlock) {
            if (!req.query.params) {
                req.query.params = {}
            }
            req.query.params.network = allNetWork;
        } else {
            if (null == config[req.query.params.channelName]) {

                return res.json("channelName is null")
            }
            if (null == config[req.query.params.channelName]['chainCode']) {

                return res.json("chainCode is null")
            }
            if (null == config[req.query.params.channelName]['chainCode'][req.query.params.chaincode.name]) {

                return res.json("chainCodeName is null")
            }
            var peerList = config[req.query.params.channelName]['chainCode'][req.query.params.chaincode.name].peerList;
            req.query.params.network = {};
            req.query.params.network.orderer = network.orderer;
            for (var i = 0; i < peerList.length; i++) {
                var peer = network[peerList[i]];
                if (req.query.params.network[peer.assign]) {
                    req.query.params.network[peer.assign]["num"] = req.query.params.network[peer.assign]["num"] + 1;
                    var peerNum = "peer" + req.query.params.network[peer.assign]["num"];
                    req.query.params.network[peer.assign][peerNum] = peer;
                } else {
                    req.query.params.network[peer.assign] = network[peer.assign];
                    req.query.params.network[peer.assign]["peer1"] = peer;
                    req.query.params.network[peer.assign]["num"] = 1;
                }
            }
        }

        logger.debug('Network set in params. Updated network: %j', req.query.params.network);

    } catch (err) {
        logger.error('setNetwork error %s', JSON.stringify(err));
    }
}


/**
 * 设置txfile的data
 * @param req
 */
function setTxFileData(req, res) {
    try {
        var channelName = req.params['channelName'];

        if (null == channelName || "" == channelName) {
            channelName = req.query.params['channelName'];
        }
        //channelName = channelName.replace('supplychain', 'mychannel');
        if (channelName) {
            var txFilePath = config[channelName].txFilePath;
            var data = rf.readFileSync(txFilePath);
            if (!req.query.params) {
                req.query.params = {}
            }
            if (!req.query.params.channel) {
                req.query.params.channel = {}
            }
            req.query.params.channel.txFileData = data;
            logger.debug('Tx file data set in params. Updated channel: %j', req.query.params.channel);
        } else {
            throw new Error('channelName is null');
        }
        return new Promise((resolve, reject) => resolve(true));
    } catch (err) {
        logger.error('setTxFileData error %s', JSON.stringify(err));
        return new Promise((resolve, reject) => reject(err));
    }
}


/**
 * 是否空对象
 * @param e
 * @returns {boolean}
 */
function isEmptyObject(e) {
    for (var t in e)
        return false;
    return true;
}




//var req = { params: { channelname: 'mychannel' },
//    query:
//    { rpctime: '2017-04-17 10:00:00',
//        params: { type: 1,
//            channelName: 'mychannel',
//            chaincode : {
//            name : 'trace',
//            version : 'v0'
//        },
//            ctorMsg : {
//                functionName : 'iPostSkuBaseInfo',
//                args : ["skuId123", "vendortest", "traceCode123456", "hashabcd", "name123", "num123", "ext123", "sign123", "time123"]
//            } },
//        id: 2 } }
//

//var req ={ originalUrl: '/v1',
//    params: { channelname: 'mychannel' },
//    query:
//    { rpctime: '2017-04-17 10:00:00',
//        params: { type: 1, channel: {
//            name : 'trace',
//            version : 'v0'
//        }, network: {} },
//        id: 2 } }

//setChaincodePath(req);
//setNetwork (req)

//console.log(req.query.params.channelName)
//console.log(config[req.query.params.channelName])
//console.log(config[req.query.params.channelName]['chainCode'])
//console.log(config[req.query.params.channelName]['chainCode'][req.query.params.chaincode.name])