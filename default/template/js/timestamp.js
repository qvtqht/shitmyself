// == begin timestamp.js

function LongAgo(seconds) { // returns string with time units
// takes seconds as parameter
// returns a string like "3 days ago" or "3 days from now"
	var flip = 0;
	if (seconds < 0) {
		flip = 1;
		seconds = 0 - seconds;
	}

	if (seconds < 60) {
		if (seconds != 1) {
			seconds = seconds + ' seconds';
		} else {
			seconds = seconds + ' second';
		}
	} else {
		seconds = Math.floor(seconds / 60);

		if (seconds < 60) {
			if (seconds != 1) {
				seconds = seconds + ' minutes';
			} else {
				seconds = seconds + ' minute';
			}
		} else {
			seconds = Math.floor(seconds / 60);

			if (seconds < 24) {
				if (seconds != 1) {
					seconds = seconds + ' hours';
				} else {
					seconds = seconds + ' hour';
				}
			} else {
				seconds = Math.floor(seconds / 24);

				if (seconds < 7) {
					if (seconds != 1) {
						seconds = seconds + ' days';
					} else {
						seconds = seconds + ' day';
					}
				} else {
					if (seconds < 30) {
						seconds = Math.floor(seconds / 7);
						if (seconds != 1) {
							seconds = seconds + ' weeks';
						} else {
							seconds = seconds + ' week';
						}
					} else {
						if (seconds < 365) {
							seconds = Math.floor(seconds / 30);

							if (seconds != 1) {
								seconds = seconds + ' months';
							} else {
								seconds = seconds + ' month';
							}
						} else {
							seconds = Math.floor(seconds / 365);
							if (seconds != 1) {
								seconds = seconds + ' years';
							} else {
								seconds = seconds + ' year';
							}
						}
					}
				}
			}
		}
	}

	if (flip) {
		return seconds + ' ago';
	}

	if (seconds != '0 seconds') {
		return seconds + ' from now';
	}

	return 'just now!';
}

function ShowTimestamps () { // finds any class=timestamp, updates its displayed time as needed
	//alert('DEBUG: ShowTimestamps()');
	if (document.getElementsByClassName) {
		//alert('DEBUG: ShowTimestamps: document.getElementsByClassName feature check passed');

		var d = new Date();
		var curTime = Math.floor(d.getTime() / 1000);
		var changeLogged = 0;
	
		// find elements with class=timestamp
		var te = document.getElementsByClassName("timestamp"); // #todo nn3 compat for loop

		//alert('DEBUG: ShowTimestamps: class=timestamp elements found: ' + te.length);

		for (var i = 0; i < te.length; i++) {
			if (!isNaN(te[i].getAttribute('epoch'))) {
				// element also has an attribute called 'epoch', and it is a number
				var secs = 0 - (curTime - te[i].getAttribute('epoch')); // number of seconds since epoch number
				var longAgo = LongAgo(secs);
				if (te[i].innerHTML != longAgo) {
					// element's content does not already equal what it should equal
					te[i].innerHTML = longAgo;
					if ((secs * (-1)) < 3600) {
						te[i].style.fontWeight = 'bold';
					} else {
						te[i].style.fontWeight = '';
					}
					if ((secs * (-1)) < 86400) {
						te[i].style.backgroundColor = '$colorHighlightAlert';
					} else {
						te[i].style.backgroundColor = '';
					}
					changeLogged++;
				}
			}
		}

		if (window.EventLoop) {
			// do nothing
		} else {
			// allows ShowTimestamps() to run decoupled from main EventLoop
			if (changeLogged) {
				setTimeout('ShowTimestamps()', 5000);
			} else {
				setTimeout('ShowTimestamps()', 15000);
			}
		}
	}
} // ShowTimestamps()

if (window.EventLoop) {
	// do nothing
} else {
	ShowTimestamps();
}
 // #todo this should probably be called from onload somehow

// == end timestamp.js