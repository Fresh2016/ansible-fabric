createClient = require('../client/create-channel.js');
joinClient = require('../client/join-channel.js');
installClient = require('../client/install-chaincode.js');
invokeClient = require('../client/invoke-transaction.js');
queryClient = require('../client/query.js');

var ClientUtils = require('fabric-client/lib/utils.js');
var logger = ClientUtils.getLogger('create-manage');

/**
 * create Channel
 * @returns {Promise.<T>|*|Observable}
 */

function createChannel(params) {
    return queryClient.queryOrderers(params)
        .then((result) => {
            logger.debug('createChannel: Already create');
            //if(result[0]['status'] == 'UP'){
            return new Promise((resolve, reject) => resolve("Already create"));
            //}else{
            //    var err ={msg:"status not is up"}
            //    util.throwError(logger, err, channelName+'status not is up');
            //}

        }).catch((err) => {
            return createClient.createChannel(params);
        });
}
exports.createChannel = createChannel;
/**
 *  join Channel
 * @returns {Promise.<T>|*|Observable}
 */

function joinChannel(params) {
    return queryClient.queryPeers(params)
        .then((result) => {
            if (result[0]['status'] == 'UP') {
                logger.debug('createChannel: Already join');
                return new Promise((resolve, reject) => resolve("Already join"));
            } else {
                var err = { msg: "status  is up" }
                util.throwError(logger, err, channelName + 'status not is DOWN"');
            }

        }).catch((err) => {
            return joinClient.joinChannel(params);
        });
}
exports.joinChannel = joinChannel;

/**
 * installChaincode
 * @returns {Promise.<T>|*|Observable}
 */
function installChaincode(params) {
    return installClient.installChaincode(params)
        .catch((err) => {
            err.errName = "installChaincodeError";
            logger.debug(' install failed %s', JSON.stringify(err));
            //如果失败报错，也继续执行下一个方法instantiate
            return new Promise((resolve, reject) => resolve(err));
        });
}
exports.installChaincode = installChaincode;
/**
 *  instantiateChaincode
 * @returns {Promise.<T>|*|Observable}
 */
function instantiateChaincode(params) {
    //todo rpctime 暂时写死
    return invokeClient.instantiateChaincode('2017-04-17 10:00:00', params)
        .catch((err) => {
            err.errName = "installChaincodeError";
            logger.debug('instantiate failed %s', JSON.stringify(err));
            return new Promise((resolve, reject) => reject(err));
        });
}
exports.instantiateChaincode = instantiateChaincode;


/**
 * create mangage
 * @param channelName
 * @returns {Promise.<T>|*}
 */

function create(params) {
    return createChannel(params)
        .then((response) => {
            logger.debug('createChannel: %j\n\n\n', response);
            return joinChannel(params);

        }).then((response) => {
            logger.debug('joinChannel: %j\n\n\n', response);
            return installChaincode(params);
        }).then((response) => {
            logger.debug('installChaincode: %j\n\n\n', response);
            return instantiateChaincode(params);
        }).then((response) => {
            logger.debug('instantiateChaincode: %j\n\n\n', response);
            return new Promise((resolve, reject) => resolve("Create success"));
        }).catch((err) => {
            logger.debug(' Create failed %s', JSON.stringify(err));
            return new Promise((resolve, reject) => reject("Create failed"));
        });
}
exports.create = create;

/**
 * init
 * @param channelName
 */
exports.initCreate = function() {
    var paramsCreateChannel = {
        rpctime: '2017-04-17 10:00:00',
        params: {
            type: 1,
            channel: {
                name: 'supplychain',
                version: 'v0'
            }
        },
        id: 2
    };
    return create('supplychain')
        .then((result) => {
            logger.debug('init success %s', JSON.stringify(result));
            return true;
        }).catch((err) => {
            logger.debug('init failed %s', JSON.stringify(err));
            return false;
        });
}


/**
 * 查询 Channel是否存在
 * @type {queryChannel}
 */
exports.queryIsChannel = queryIsChannel;

function queryIsChannel(params) {
    console.log('queryIsChannel response: %j\n\n\n', JSON.stringify(params));
    return queryClient.queryOrderers(params)
        .then((response) => {
            //console.log('queryPeers response: %j\n\n\n', response);
            return queryClient.queryPeers(params);

        }).then((response) => {
            if (response[0]['status'] == 'UP') {
                return new Promise((resolve, reject) => resolve(true));
            } else {
                return new Promise((resolve, reject) => resolve(false));
            }

        }).catch((err) => {
            console.log('Return without querying.');
            return new Promise((resolve, reject) => resolve(false));
        });
}