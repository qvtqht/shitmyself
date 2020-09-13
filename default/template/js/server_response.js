// begin server_response.js

function serverResponseOk (t) { // function which hides server response message
// can be called with t pointing to OK button -or- 0
// when t==0, function will look for it on the page

	//alert('DEBUG: serverResponseOk(t): t: ' + !!t);

	if (window.serverResponseTimeout) {
		clearTimeout(serverResponseTimeout);
	}

	if (!t && document.getElementById) {
		t = document.getElementById('serverResponse');
	}

	if (t && t.parentElement && t.parentElement.style && t.nodeName) {
		// this will traverse and hide everything from the OK button up to
		// but not including <body
		// previously, this just said:  t.parentElement.style.display = 'none';
		// but this was not good enough for tables
		while (t.nodeName != 'BODY') {
			// stop before hiding body
			t.style.display = 'none';
			if (t.nodeName == 'TABLE') {
				// if we just hid a table, we can call it a day
				break;
			}
			t = t.parentElement; // go up the element tree until satisfied
		}

		// #todo remove elements from tree altogether
	}

	if (document.body && document.body.onkeydown) {
		//alert('DEBUG: serverResponseOk: setting body.onkeydown to return true;')

		document.body.setAttribute('onkeydown', 'return true;');
	}

	if (window.history) {
		//alert('DEBUG: serverResponseOk: window.history found');

		if (window.history.replaceState) {
			//alert('DEBUG: serverResponseOk: window.history.replaceState found');

			window.history.replaceState(null, null, window.location.pathname);

			// don't follow the link, we already changed the location
			return false;
		} else {
			//alert('DEBUG: serverResponseOk: window.history.replaceState NOT FOUND');

			// this means we'll let the browser follow the link to the page
			// which doesn't have response message on it
			return true;
		}
	} else {
		//alert('DEBUG: serverResponseOk: window.history NOT FOUND');
		return true;
	}
}

function bodyEscPress(keyCode) { // called when user presses esc on a page with server message
// results in server message being hidden

	//alert('DEBUG: bodyEscPress(keyCode): keyCode = ' + keyCode);

	if (document.getElementById) {
		serverResponseOk(document.getElementById('sro'));
	} else {
		serverResponseOk();
	}

	return true;
}

////function serverResponseShrink() { // moves server message to the top of the page instead of floating
////	if (document.getElementById) {
////		var serverResponse = document.getElementById('serverResponse');
////		if (serverResponse) {
////			serverResponse.style.display = 'block';
////			serverResponse.style.position = 'inherit';
////			serverResponse.style.margin = '0';
////			serverResponse.style.borderRadius = '0';
////			serverResponse.style.border = '0';
////			serverResponse.style.borderBottom = '5pt silver double';
////			serverResponse.style.boxShadow = '0 0 0 0';
////		}
////	}
////}
////
//serverResponseTimeout = setTimeout('serverResponseOk()', 15000);
//serverResponseTimeout = setTimeout('serverResponseShrink()', 5000);

// end server_response.js