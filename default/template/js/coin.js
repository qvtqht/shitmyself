// coin.js

if (document.createElement && document.head) {
// include sha512.js library instead of embedding it in page
// because it's big and cointains (gt) characters
// and because it is large
	var script = document.createElement('script');
	script.src = '/sha512.js';
	script.async = false; // This is required for synchronous execution
	document.head.appendChild(script);
}

function doMakeCoin () { // makes coin
// called from a timeout set by makeCoin()
	var fp = '0000000000000000';
	if (window.getUserFp) {
		fp = getUserFp();
	}
	// user's fp or default to 000

	var i = 0; // counts iterations
	var done = 0; // done status

	var d = new Date();
	var epoch = d.getTime();
	epoch = Math.ceil(epoch / 1000); // current time in epoch format

	var r = 0 + ''; // stores random number as string
	var lookingFor = '1337'; // required hash prefix
	var lookingForLength = lookingFor.length;
	var cycleLimit = 1000000; // give up after this many tries
	var coin = ''; // finished coin
	var hash = ''; // hash of coin

	while(!done) {
		// look for a coin which fits criteria

		i = i + 1; // counter

		r = Math.random() + '';
		coin = fp + ' ' + epoch + ' ' + r;
		hash = hex_sha512(coin);

		if (hash.substring(0, lookingForLength) == lookingFor) {
			// match found
			done = 1;
		}

		if (cycleLimit < i) {
			// give up
			done = 2;
		}
	}

	// add to compose form, sign, and submit
	var dcc = document.compose.comment;
	if (dcc && window.makeCoin) {
		if (done == 1) {
			dcc.value += '\n\n' + coin
		} else {
			dcc.value += '\n\n' + 'coin not minted';
		}
	}
	if (window.signMessage) {
		signMessage();
	}
	if (window.writeSubmit) {
		writeSubmit();
	}
} // doMakeCoin()

function makeCoin (t) { // t = button pressed ; begins coin minting process and indicates to user
// done with timeout to give button a chance to change caption before pegging cpu

	if (!window.hex_sha512 || !window.doMakeCoin) {
		// required function is missing
		return true;
	}
	if (t) {
		// update button caption
		t.value = 'Meditate...';
	}

	// set timeout to mint coin
	var timeoutMakeCoin = setTimeout('doMakeCoin()', 50);

	return false; // do not let the form submit
} // makeCoin()

// / coin.js
