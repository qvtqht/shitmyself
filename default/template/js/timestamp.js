// == begin timestamp.js

function LongAgo (seconds) { // returns string with time units
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
// currently requires getElementsByClassName()
// in the future, ie4+, nn4+, and others compat can be improved

	//alert('DEBUG: ShowTimestamps()');
	if (document.getElementsByClassName) {
		//alert('DEBUG: ShowTimestamps: document.getElementsByClassName feature check passed');
		var d = new Date();
		var curTime = Math.floor(d.getTime() / 1000);
		var changeLogged = 0;
		var showAdvancedMode = 0;

		if (window.GetPrefs) {
			if (GetPrefs('expert_timestamps')) {
				showAdvancedMode = 1;
			}
		}
	
		// find elements with class=timestamp
		var te = document.getElementsByClassName("timestamp");

		//alert('DEBUG: ShowTimestamps: class=timestamp elements found: ' + te.length);
		for (var i = 0; i < te.length; i++) {
			// loop through all the timestamp elements on the page
			if (!isNaN(te[i].getAttribute('epoch'))) {
				// element also has an attribute called 'epoch', and it is
				// a number, which would represent epoch seconds
				var secs = 0 - (curTime - te[i].getAttribute('epoch')); // number of seconds since epoch begin
				var longAgo = '';
				if (!showAdvancedMode) {
					longAgo = LongAgo(secs); // what the element's displayed value should be
				} else {
					longAgo = secs;
				}

				if (te[i].innerHTML != longAgo) {
					// element's content does not already equal what it should equal
					te[i].innerHTML = longAgo;
					if ((secs * (-1)) < 3600) {
						// less than an hour ago = bold
						te[i].style.fontWeight = 'bold';
					} else {
						te[i].style.fontWeight = '';
					}
					if ((secs * (-1)) < 86400) {
						// less than a day ago = highlight
						te[i].style.backgroundColor = '$colorHighlightAlert';
					} else {
						te[i].style.backgroundColor = '';
					}
					changeLogged++; // count change logged
				}
			}
		}

		if (window.EventLoop) {
			// do nothing, EventLoop() will call us when needed
			return changeLogged;
		} else {
			// allow ShowTimestamps() to run decoupled from EventLoop()
			if (changeLogged) {
				setTimeout('ShowTimestamps()', 5000);
			} else {
				setTimeout('ShowTimestamps()', 15000);
			}
			return changeLogged;
		}
	}
} // ShowTimestamps()
//
//if (window.EventLoop) {
//	// do nothing, EventLoop() will take care of us
//} else {
//	// if no EventLoop(), we do it ourselves
//	ShowTimestamps();
//}

// == end timestamp.js
