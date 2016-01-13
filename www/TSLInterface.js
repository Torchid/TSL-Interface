module.exports = {
    pair: function(successCallback, failCallback) {
        cordova.exec(successCallback,
                     failCallback,
                     "TSLInterface",
                     "pair",
                     ["firstArgument"]);
    },
    read: function(tagID, successCallback, failCallback) {
        cordova.exec(successCallback,
                    failCallback,
                    "TSLInterface",
                    "read",
                    [tagID]);
   },
    write: function(tagID, writeData, successCallback, failCallback) {
        cordova.exec(successCallback,
                     failCallback,
                     "TSLInterface",
                     "write",
                     [tagID, writeData]);
    },
    disconnect: function() {
        cordova.exec(function(){},
                     function(){},
                     "TSLInterface",
                     "disconnect",
                     [""]);
    },
    reconnect: function() {
        cordova.exec(function(){},
                     function(){},
                     "TSLInterface",
                     "reconnect",
                     [""]);
    }
};
