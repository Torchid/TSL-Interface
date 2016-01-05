module.exports = {
    pair: function(successCallback, failCallback) {
        cordova.exec(successCallback,
                     failCallback,
                     "TSLInterface",
                     "pair",
                     ["firstArgument"]);
    },
    write: function(tagID, writeData, successCallback, failCallback) {
        cordova.exec(successCallback,
                     failCallback,
                     "TSLInterface",
                     "write",
                     [tagID, writeData]);
    },
   read: function(tagID, successCallback, failCallback) {
   cordova.exec(successCallback,
                failCallback,
                "TSLInterface",
                "read",
                [tagID]);
   }
};
