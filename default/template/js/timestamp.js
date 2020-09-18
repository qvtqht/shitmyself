// == begin timestamp.js

function ShowTimestamps() { // finds any class=timestamp, updates its displayed time as needed
	if (document.getElementsByClassName) {
		var d = new Date();
		var curTime = Math.floor(d.getTime() / 1000);
		
		var changeLogged = 0;
	
		// find elements with class=timestamp
		var te = document.getElementsByClassName("timestamp"); // #todo nn3 compat for loop
		for (var i = 0; i < te.length; i++) {
			if (!isNaN(te[i].getAttribute('epoch'))) {
				// element also has an attribute called 'epoch', and it is a number
				var secs = 0 - (curTime - te[i].getAttribute('epoch')); // number of seconds since epoch number
				if (te[i].innerHTML != LongAgo(secs)) {
					// element's content does not already equal what it should equal
					te[i].innerHTML = LongAgo(secs);
					if ((secs * -1) < 3600) {
						te[i].style.backgroundColor = '$colorHighlightAlert';
					} else {
						te[i].style.backgroundColor = '';
					}
					changeLogged++;
				}
			}
		}
	
		if (changeLogged) {
			setTimeout('ShowTimestamps()', 5000);
		} else {
			setTimeout('ShowTimestamps()', 15000);
		}
	}
}

function LongAgo(seconds) { // returns string with time units
// takes seconds as parameter
// returns a string like
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
			// #todo weeks, years, etc.
				seconds = Math.floor(seconds / 24);

				if (seconds != 1) {
					seconds = seconds + ' days';
				} else {
					seconds = seconds + ' day';
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

ShowTimestamps(); // #todo this should probably be called from onload somehow

// == end timestamp.js