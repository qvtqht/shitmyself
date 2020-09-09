// coin.js

var script = document.createElement('script');
script.src = '/sha512.js';
script.async = false; // This is required for synchronous execution
document.head.appendChild(script);

function makeCoin(t) {
	if (t) {
		t.value = 'Minting...';
	}

	var fp = '0000000000000000'
	if (window.getUserFp) {
		fp = getUserFp();
	}
	// user's fp or default to 000

	var i = 0; // counts iterations
	done = 0;

	var d = new Date();
	var epoch = d.getTime();
	epoch = Math.ceil(epoch / 1000);

	var r = 0 + ''; // stores random number as string

	var lookingFor = '1337';
	var lookingForLength = lookingFor.length;

	var cycleLimit = 1000000;
	var coin = '';
	var hash = '';

	while(!done) {
		coin = fp + ' ' + epoch + ' ' + r;
		hash = hex_sha512(coin);

		i = i + 1;
		r = Math.random() + '';

		if (hash.substring(0, lookingForLength) == lookingFor) {
			done = 1;
		}

		if (cycleLimit < i) {
			done = 2;
		}
	}

	if (done == 1) {
		if (t) {
			t.value = 'Done. ' + i + ' iterations.';
			t.disabled = true;
			return coin;
		}
	} else {
		if (t) {
			t.value = 'No coin. ' + i + ' iterations.';
			return '';
		}
	}
}

// / coin.js
