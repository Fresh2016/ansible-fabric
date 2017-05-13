#!/usr/bin/env node

var PromisePool = require('es6-promise-pool');
var request = require('request');

var createClient = require('./app/client/create-channel.js');
var joinClient = require('./app/client/join-channel.js');
var installClient = require('./app/client/install-chaincode.js');
var invokeClient = require('./app/client/invoke-transaction.js');
var queryClient = require('./app/client/query.js');
var manager = require('./app/manage/create-client.js');
var interClient = require('./app/manage/param-interceptor.js');

//process.env['HFC_LOGGING'] = '{"error": "console", "warn": "console", "debug":"console", "info": "console"}';
process.env['HFC_LOGGING'] = '{"error": "/dev/null", "warn": "/dev/null", "debug":"/dev/null", "info": "console"}';

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
var paramsInstallChaincode = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1,
        chaincode: {
            name: 'trace',
            version: 'v0'
        }
    },
    id: 2
};
var paramsUpgradeTransaction = JSON.parse(JSON.stringify(paramsInstallChaincode));
paramsUpgradeTransaction.params.chaincode.version = 'v1';

var paramsInvokeTransaction = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1,
        chaincode: {
            name: 'trace',
            version: 'v0'
        },
        ctorMsg: {
            functionName: 'iPostSkuBaseInfo',
            args: ['skuId123', 'vendortest', 'traceCode123456', 'hashabcd', 'name123', 'num123', 'ext123', 'sign123', 'time123']
        }
    },
    id: 2
};

var paramsQueryTransaction = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1,
        chaincode: {
            name: 'trace',
            version: 'v0',
        },
        ctorMsg: {
            functionName: 'qGetSkuTransactionListByTraceCode',
            args: ['1111']
        }
    },
    id: 2
};
var paramsQueryBlocknum = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1
    },
    id: 2
};
var paramsQueryBlockInfo = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1,
        blockNum: 1
    },
    id: 2
};
var paramsQueryPeer = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1
    },
    id: 2
};
var paramsQueryOrderer = {
    rpctime: '2017-04-17 10:00:00',
    params: {
        type: 1
    },
    id: 2
};

var requestCreateChannel = {
    originalUrl: '/v1',
    query: paramsCreateChannel
};
//FIXME: Join should not be a separate REST API but automatically done
// following create request or during initialization
var requestJoinChannel = JSON.parse(JSON.stringify(requestCreateChannel));

var requestInstallChaincode = {
    originalUrl: "/v1/supplychain",
    query: paramsInstallChaincode
};
var requestInstantiateChaincode = JSON.parse(JSON.stringify(requestInstallChaincode));
var requestUpgradeChaincode = {
    originalUrl: "/v1/supplychain",
    query: paramsUpgradeTransaction
};
var requestInvokeTransaction = {
    originalUrl: "/v1/supplychain",
    query: paramsInvokeTransaction
};
var requestQueryTransaction = {
    originalUrl: "/v1/supplychain",
    query: paramsQueryTransaction
};
var requestQueryBlocknum = {
    originalUrl: "/v1/supplychain",
    query: paramsQueryBlocknum
};
var requestQueryBlockInfo = {
    originalUrl: "/v1/supplychain",
    query: paramsQueryBlockInfo
};
var requestQueryPeer = {
    originalUrl: "/v1/supplychain",
    query: paramsQueryPeer
};
var requestQueryOrderer = {
    originalUrl: "/v1/supplychain",
    query: paramsQueryOrderer
};


// Detect input args and print hints
if (process.argv.length <= 2 || '-h' == process.argv[2] || '-help' == process.argv[2]) {
    console.log('\nNo input args of operation, using default query.\n');
    console.log('Select test items as command args.');

    console.log('\n   Examples:');
    console.log('       # Test all from end to end:');
    console.log('       $ node testapp.js -a\n');

    console.log('       # Test create channel and join channel:');
    console.log('       $ node testapp.js -l 1,2\n');

    console.log('       # Test invoke transaction:');
    console.log('       $ node testapp.js -l 6\n');

    console.log('       # Test query transaction:');
    console.log('       $ node testapp.js -l 7\n');

    console.log('       # Test invoke concurrency performance:');
    console.log('       $ node testapp.js -c 6\n');

    console.log('\n   Numbers and operation mapping:');
    console.log('       1: create channel');
    console.log('       2: join channel');
    console.log('       3: install chaincode');
    console.log('       4: instantiate chaincode');
    console.log('       5: upgrade chaincode');
    console.log('       6: invoke transaction');
    console.log('       7: query transaction');

} else if ('-a' == process.argv[2]) {
    // Call testOperation() to do testing of all items
    console.log('\nTesting all from end to end\n');
    testOperation([1, 2, 3, 4, 5, 6, 7]);

} else if ('-l' == process.argv[2] && null != process.argv[3]) {
    // Call testOperation() to do testing of selected items
    var opr_num_list = getOprList(process.argv[3], 'operations');
    testOperation(opr_num_list);

} else if ('-c' == process.argv[2] && null != process.argv[3]) {
    // Call testOperation() to do testing of selected items
    var opr_num_list = getOprList(process.argv[3], 'concurrency performance');
    testConcurrency(opr_num_list);

} else {
    console.log('\nIncorrect input args, using -h or -help for help.\n');
}


function fillArrayWithNumbers(start, end, interval) {
    var arr = Array.apply(null, Array(parseInt((end - start) / interval) + 1));
    return arr.map(function(x, i) { return start + i * interval });
}


function getOprList(args, type) {
    var opr_num_list = args.split(',');
    console.log('\nTesting %s of belowing:', type);
    for (i in opr_num_list) {
        console.log('       ' + translateNumToOperation(opr_num_list[i]));
    }
    return opr_num_list;
}


function getStatistics(results) {
    var theResults = results.slice(0, -1);
    var nextResults = results.slice(1, results.length);
    var performance = {};
    var responseDelay = 0;
    var interval = 0;
    var validResponseNum = 1;

    for (let i in theResults) {
        try {
            theResult = theResults[i];
            nextResult = nextResults[i];
            validResponseNum++;
            responseDelay = responseDelay + (theResult.responseTime - theResult.sendTime) / 1000.0;
            interval = interval + (nextResult.sendTime - theResult.sendTime) / 1000.0;
            //			interval = interval + (nextResult.sendTime - theResult.sendTime) / (nextResult.operationIndex - theResult.operationIndex) / 1000.0;

        } catch (err) {
            console.log('Error in getStatistics');
        }
    }

    performance.totalResponseDelay = responseDelay;
    performance.totalInterval = interval;
    performance.validResponseNum = validResponseNum;
    performance.averageResponseDelay = responseDelay / (validResponseNum - 0.99); // Avoid Nan
    performance.averageInterval = interval / (validResponseNum - 0.99); // Avoid Nan
    return performance;
}


function isToDo(operation, opr_num_list) {
    number = translateOperationToNum(operation);
    for (i in opr_num_list) {
        if (number == opr_num_list[i]) {
            return true;
        }
    }
    return false;
}


function producePromises(operation, totalOperationNum, results) {
    var count = 0;
    var promiseProducer = function() {
        if (count < totalOperationNum) {
            count++;
            return produceOnePromise(operation, count, 'rest', results);
            //			return produceOnePromise(operation, count, 'client', results);
        } else {
            return null;
        }
    };
    return promiseProducer;
}


function produceOnePromise(operation, operationIndex, operationType, results) {
    return new Promise((resolve, reject) => {
        var sendTime = Date.now();

        return start()
            .then(() => {
                if ('invoke' == operation && 'client' == operationType) {
                    interClient.filterParams(requestInvokeTransaction, null);
                    return invokeClient.invokeChaincode(requestInvokeTransaction.rpctime, requestInvokeTransaction.query.params);
                } else if ('query' == operation && 'client' == operationType) {
                    interClient.filterParams(requestQueryTransaction, null);
                    return queryClient.queryTransaction(requestQueryTransaction.rpctime, requestQueryTransaction.query.params);
                } else if ('invoke' == operation && 'rest' == operationType) {
                    return sendRequest('POST', 'http://localhost:8081/v1/supplychain', requestInvokeTransaction, operationIndex);
                } else if ('query' == operation && 'rest' == operationType) {
                    return sendRequest('GET', 'http://localhost:8081/v1/supplychain', requestQueryTransaction, operationIndex);
                } else {
                    return {};
                }

            }).then((result) => {
                var responseTime = Date.now();
                result.operationIndex = operationIndex;
                result.sendTime = sendTime;
                result.responseTime = responseTime;
                if (result.status = 'success') {
                    results.push(result);
                }
                resolve();

            }).catch((err) => {
                console.log('Error in #%s %s', operationIndex, operation);
                // Don't have to throw it. Fine to skip
                resolve();
            });
    });
}


function sendConcurrencyRequest(operation) {
    // The total number of promises to process
    var totalOperationNum = 100;
    // The number of promises to process simultaneously, current version only allow 1
    var concurrency = 5;
    // Responses from all queries
    var results = [];

    // Create a pool.
    var promiseProducer = producePromises(operation, totalOperationNum, results);
    var pool = new PromisePool(promiseProducer, concurrency);

    // Start the pool.
    var poolPromise = pool.start();
    // Wait for the pool to settle.
    return poolPromise.then((nothing) => {
        console.log('All promises fulfilled. Going to calculate statistics.');
        return getStatistics(results);
    }, function(error) {
        console.log('Some promise rejected: ' + error.message);
    });

}


function sendRequest(method, uri, reqJson, operationIndex) {
    var option = {
        headers: { 'content-type': 'application/json' },
        method: method,
        uri: uri,
        json: reqJson.query
    };

    return new Promise(function(resolve, reject) {
        request(option, function(error, response, body) {
            // in addition to parsing the value, deal with possible errors
            if (error) {
                console.log('Request #%s, get statusCode: %s, get error: %s', operationIndex, response && response.statusCode, JSON.stringify(error));
                reject(error);
            }
            try {
                // JSON.parse() can throw an exception if not valid JSON
                console.log('Request #%s, get statusCode: %s, get response: %s', operationIndex, response && response.statusCode, JSON.stringify(body));
                resolve(body);
            } catch (error) {
                reject(error);
            }
        });
    });

}


function start() {
    return Promise.resolve();
}


//Execute concurrency performance test
//Only selected items are executed, while others are skipped
function testConcurrency(opr_num_list) {
    start()
        .then(() => {
            console.log('\n\n***** TESTAPP: Start concurrency testing *****\n\n');
            console.log('*****   DANGEROUS! DONNOT DO IT AT HOME  *****\n\n');
            if (isToDo('invoke', opr_num_list)) {
                return sendConcurrencyRequest('invoke');
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: invoke channel concurrency performance %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                return sendConcurrencyRequest('query');
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: query channel concurrency performance %s', JSON.stringify(result));
            console.log('### shiying is aaa ###');

        }).catch((err) => {
            console.log('Quit with err: %s', err);
            return false;
        });
}


//Execute items in serial order
//Only selected items are executed, while others are skipped
function testOperation(opr_num_list) {
    start()
        .then(() => {
            console.log('\n\n***** TESTAPP: Start testing *****\n\n');
            if (isToDo('create', opr_num_list)) {
                interClient.filterParams(requestCreateChannel, null);
                return createClient.createChannel(requestCreateChannel.query.params);
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: create channel result %s', JSON.stringify(result));
            if (isToDo('join', opr_num_list)) {
                interClient.filterParams(requestJoinChannel, null);
                return joinClient.joinChannel(requestJoinChannel.query.params);
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: join channel result %s', JSON.stringify(result));
            if (isToDo('install', opr_num_list)) {
                interClient.filterParams(requestInstallChaincode, null);
                return installClient.installChaincode(requestInstallChaincode.query.params);
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: install chaincode result %s', JSON.stringify(result));
            if (isToDo('instantiate', opr_num_list)) {
                interClient.filterParams(requestInstantiateChaincode, null);
                return invokeClient.instantiateChaincode(requestInstantiateChaincode.rpctime, requestInstantiateChaincode.query.params);
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: instantiate chaincode result %s', JSON.stringify(result));
            if (isToDo('upgrade', opr_num_list)) {
                interClient.filterParams(requestUpgradeChaincode, null);
                return installClient.installChaincode(requestUpgradeChaincode.query.params)
                    .then((result) => {
                        return invokeClient.upgradeChaincode(requestUpgradeChaincode.rpctime, requestUpgradeChaincode.query.params);
                    });

            } else {
                return 'Skipped';
            }

        }).then((result) => {
            console.log('TESTAPP: upgrade chaincode result %s', JSON.stringify(result));
            if (isToDo('invoke', opr_num_list)) {
                interClient.filterParams(requestInvokeTransaction, null);
                return invokeClient.invokeChaincode(requestInvokeTransaction.rpctime, requestInvokeTransaction.query.params);
            } else {
                return 'Skipped';
            }

        }).then((result) => {
            //TODO:eventhub断开
            console.log('TESTAPP: invoke chaincode result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryTransaction, null);
                return queryClient.queryTransaction(requestQueryTransaction.rpctime, requestQueryTransaction.query.params);
            } else {
                return 'Skipped';
            }

            /*
        }).then((result) => {
            console.log('TESTAPP: queryTransaction result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryTransaction, null);
                return queryClient.queryTransactionHistory(requestQueryTransaction.params.rpctime, requestQueryTransaction.query.params);
            } else {
                return 'Skipped';
            }
            */

            /*
        }).then((result) => {
            console.log('TESTAPP: queryTransactionHistory result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                params = manager. ? ? // FIXME:should be some filter interface from manager
                    return queryClient.isTransactionSucceed(response[0].TransactionId);
            } else {
                return 'Skipped';
            }
            */

            /*
        }).then((result) => {
            console.log('TESTAPP: isTransactionSucceed result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryPeer, null);
                return queryClient.queryPeers(requestQueryPeer.query.params);
            } else {
                return 'Skipped';
            }
            */

            /*
        }).then((result) => {
            console.log('TESTAPP: queryPeers result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryOrderer, null);
                return queryClient.queryOrderers(requestQueryOrderer.query.params);
            } else {
                return 'Skipped';
            }
            */

        }).then((result) => {
            console.log('TESTAPP: queryOrderers result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryBlocknum, null);
                return queryClient.queryBlocks(requestQueryBlocknum.params.rpctime, requestQueryBlocknum.query.params);
            } else {
                return 'Skipped';
            }

            /*
        }).then((result) => {
            console.log('TESTAPP: queryBlocks number result %s', JSON.stringify(result));
            if (isToDo('query', opr_num_list)) {
                interClient.filterParams(requestQueryBlockInfo, null);
                return queryClient.queryBlocks(requestQueryBlockInfo.params.rpctime, requestQueryBlockInfo.query.params);
            } else {
                return 'Skipped';
            }
            */

        }).then((result) => {
            //console.log('TESTAPP: queryBlocks info result %s', JSON.stringify(result));
            console.log('TESTAPP: queryBlocks number result %s', JSON.stringify(result));

            if ('Skipped' != result) {
                console.log('CURRENT_BLOCK_NUMBER:%s', result.message.Payloads.low);
            }

            console.log('### shiying is aaa ###');
            // FORCE to exit
            process.exit();

        }).catch((err) => {
            console.log('Quit with err: %s', err);
            return false;
        });
}


function translateOperationToNum(operation) {
    if ('create' == operation) {
        return 1;
    } else if ('join' == operation) {
        return 2;
    } else if ('install' == operation) {
        return 3;
    } else if ('instantiate' == operation) {
        return 4;
    } else if ('upgrade' == operation) {
        return 5;
    } else if ('invoke' == operation) {
        return 6;
    } else if ('query' == operation) {
        return 7;
    } else {
        return -1;
    }
}


function translateNumToOperation(number) {
    if (1 == number) {
        return 'create';
    } else if (2 == number) {
        return 'join';
    } else if (3 == number) {
        return 'install';
    } else if (4 == number) {
        return 'instantiate';
    } else if (5 == number) {
        return 'upgrade';
    } else if (6 == number) {
        return 'invoke';
    } else if (7 == number) {
        return 'query';
    } else {
        return 'undefined';
    }
}

/*
//for clear docker container and images
docker rm -f $(docker ps -a | grep trace | awk '{print $1 }')
docker rmi -f $(docker images | grep trace | awk '{print $3 }')
*/