var channel = {
    list: ["supplychain"],
    supplychain: {
        chainCode: {
            supplychain: {
                name: "supplychain",
                version: "v0",
                path: "github.com/supplychain",
                peerList: ["peer101", "peer201"]

            },
            trace: {
                name: "trace",
                version: "v0",
                path: "github.com/trace",
                peerList: ["peer102", "peer202"]

            },
            sourceproduct: {
                name: "sourceproduct",
                version: "v0",
                path: "github.com/sourceproduct",
                peerList: ["peer101", "peer102", "peer201", "peer202"]

            }
        },
        txFilePath: "./app/manage/data/supplychain.tx",
        version: "v0"
    }
}



//module.exports = function(mode) {
//    return channel[mode];
//};


exports.getConfig = function(mode) {
    if (mode) {
        return channel[mode];
    }
    return channel;
}