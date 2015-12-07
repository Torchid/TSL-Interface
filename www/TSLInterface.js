module.exports = {
	pair: function(successCallback, failCallback) {
		cordova.exec(successCallback,
			failCallback,
	        "TSLInterface",
		    "pair",
	        ["firstArgument"]);
	}
};
