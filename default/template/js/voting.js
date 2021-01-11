// == begin voting.js

function PingUrlCallback () {
	var xmlhttp = window.xmlhttp;

	if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
		//alert('DEBUG: PingUrlCallback() found status 200');

//		window.location.replace(xmlhttp.responseURL);
//		document.open();
//		document.write(xmlhttp.responseText);
//		document.close();
	}
}

function PingUrl (url) { // loads arbitrary url via image or xhr
// compatible with most js
	//alert('DEBUG: PingUrl() begins');

	// another option below
	// var img = document.createElement('img');
    // img.setAttribute("src", url);
    // document.body.appendChild(img);

	if (window.XMLHttpRequest) {
		//alert('DEBUG: PingUrl: window.XMLHttpRequest was true');

		var xmlhttp;
		if (window.xmlhttp) {
			xmlhttp = window.xmlhttp;
		} else {
			window.xmlhttp = new XMLHttpRequest();
			xmlhttp = window.xmlhttp;
		}

        xmlhttp.onreadystatechange = window.PingUrlCallback;

        xmlhttp.open("HEAD", url, true);
//		xmlhttp.timeout = 5000; //#xhr.timeout
        xmlhttp.send();

        return false;
	} else {
		//alert('DEBUG: PingUrl: using image method, no xhr here');

		if (document.images) {
			//alert('DEBUG: PingUrl: document.images was true');
			if (document.images.length) {
				// use last image on page, if possible. this should be the special pixel image.
				var img = document.images[document.images.length - 1];

				if (img) {
					img.setAttribute("src", url);

					return false;
				}
			} else {
				var img = document.images[0];

				if (img) {
					img.setAttribute("src", url);

					return false;
				}
			}
		}
	}

	return true;
}


//function OptionsDefault(token, privKeyObj) {
//	this.data = token;
//	this.privateKeys = [privKeyObj];
//}

function signCallback (signed) {
	var url = '/post.html?comment=' + encodeURIComponent(signed.data);

	if (PingUrl(url)) {
		// todo incrememnt counter
	}
}

function IncrementTagLink (t) { // increments number of votes in tag button
// adds a number if there isn't one already
// #todo adapt to accommodate buttons as well

	if (t.innerHTML) {
		// update count in vote link
		//alert('DEBUG: SignVote: t.innerHTML');
		var ih = t.innerHTML;
		if (ih.indexOf('(') == -1) {
			//alert('DEBUG: SignVote: ( not found');
			t.innerHTML = ih + '(1)';
		} else {
			//alert('DEBUG: SignVote: ( found');

			var numVal = ih.substring(ih.indexOf('(') + 1, ih.indexOf(')'));
			var newVal = parseInt(numVal) + 1;
			var hashTag = ih.substring(0, ih.indexOf('('));
			t.innerHTML = hashTag + '(' + newVal + ')';
		}
		//alert('DEBUG: SignVote: finished with t.innerHTML');
	}
}

function SignVote (t, token) { // signs a vote from referenced vote button
// t = reference to calling button's 'this'
// token = full voting token, in the format (gt)(gt)fileHash\n#tag
// where (gt) is a greater-than sign, omitted here
	//alert('DEBUG: SignVote(' + t + ',' + token +')');

	if (document.getElementById && window.getPrivateKey) {
	// basic dumb feature check #todo make smarter feature check ;
	// needs better compatibility for older browsers
		// get private key

		if (GetPrefs(token)) {
			// don't let user vote twice basic
			if (window.displayNotification) {
				window.duplicateVoteTries ? window.duplicateVoteTries++ : window.duplicateVoteTries = 1;
				if (3 <= window.duplicateVoteTries) {
					displayNotification('Hey!', t);
				} else {
					displayNotification('Already voted', t);
				}
			} else {
				//alert('DEBUG: window.displayNotification() was missing');
			}

			// returning false will keep the link from navigating to non-js fallback
			return false;
		}

		IncrementTagLink(t);

		var privkey = getPrivateKey();
		//alert('DEBUG: SignVote: privkey: ' + !!privkey);

		if (!privkey) {
			//alert('DEBUG: !privkey');
			// if there is no private key, just do a basic unsigned vote;

			if (PingUrl(t.href)) {
				// todo increment counter
			}
		} else {
			// there is a private key
			//alert('DEBUG: privkey is true');

			// load the private key into openpgp
			var privKeyObj = openpgp.key.readArmored(privkey).keys[0];
			var options;
			options = new Object();
			options.data = token;
			options.privateKeys = privKeyObj;
			openpgp.config.show_version = false;
			openpgp.config.show_comment = false;

			// sign the voting token and send to post.html when finished
			openpgp.sign(options).then(signCallback);
		}

		// remember that we voted for this already
		SetPrefs(token, 1);


		if (window.displayNotification) {
			//displayNotification('Success!', t);
		} else {
			//alert('DEBUG: window.displayNotification() was missing');
		}

		return false; // cancel link click-through
	} else {
		//	    if (document.images) {
		//	        var myUrl = window.location;
		//	    	document.images[0].src = '/post.html?mydomain=' + myUrl;
		//
		//	    	//alert('DEBUG: t = ' + t);
		//
		//	    	return false;
		//	    }
	}

	return true; // allow link click to happen
}

// == end voting.js