// begin profile.js

if (!window.openpgp && document.head && document.head.appendChild && document.getElementById && window.localStorage) {
	//alert('DEBUG: loading openpgp.js');
	window.openPgpJsLoadBegin = 1;

	var script = document.createElement('script');
	script.src = '/openpgp.js';
	script.async = false; // This is required for synchronous execution
	document.head.appendChild(script);
	//alert('DEBUG: finished loading openpgp.js; window.openpgp: ' + !!window.openpgp);
} else {
	//alert('DEBUG: not loading openpgp.js; window.openpgp: ' + !!window.openpgp + ' document.getElementById: ' + !!document.getElementById + ' window.localStorage: ' + !!window.localStorage + ' window.Promise: ' + !!window.Promise);
}

if (!(window.MakeKey) && document.head && document.head.appendChild && document.getElementById && window.localStorage) {
	//alert('DEBUG: loading crypto2.js');

	var script2 = document.createElement('script');
	script2.src = '/crypto2.js';
	script2.async = false; // This is required for synchronous execution
	document.head.appendChild(script2);

	//alert('DEBUG: finished loading crypto2.js; window.cryptoJs: ' + !!window.cryptoJs + '; document.getPrivateKey: ' + !!document.getPrivateKey + '; window.openpgp: ' + !!window.openpgp);
} else {
	//alert('DEBUG: not loading crypto2.js; ' + ' window.MakeKey = ' + window.MakeKey + '; document.getElementById = ' + document.getElementById + ' window.localStorage = ' + window.localStorage );
}

function btnSignOut_Click(t) { // event for 'Sign Out' button's click
	//alert('DEBUG: btnSignOut_Click begin');

	if (window.localStorage) {
		//alert('DEBUG: localStorage is true');

		var ls = window.localStorage;
		ls.removeItem('privatekey');
		ls.removeItem('publickey');
		ls.removeItem('fingerprint');
		ls.removeItem('avatar');

		SetPrefs('last_pubkey_ping', 0);
	}

	return true;
}

function btnRegister_Click (t) { // event for 'Register' button's click
// t is clicked button's "this" object
	//alert('DEBUG: btnRegister_Click() begin');

	if (window.localStorage) {
		// minimum features check
		// #todo resolve conflict with ie11 vs opera 12

		//alert('DEBUG: btnRegister_Click: localStorage and Promise feature check pass');

		if (window.MakeKey) {
			//alert('DEBUG: btnRegister_Click: window.MakeKey exists, calling MakeKey()');

			var intKeyGenResult = MakeKey();

			//alert('DEBUG: btnRegister_Click: intKeyGenResult = ' + intKeyGenResult);

			SetPrefs('last_pubkey_ping', 0);

			if (intKeyGenResult) {
				//alert('DEBUG: calling PubKeyPing()');
				if (window.addLoadingIndicator) {
					addLoadingIndicator('Creating profile...');
				}
				PubKeyPing();
			} else {
				//alert('DEBUG: NOT calling PubKeyPing(), because intKeyGenResult was false');
			}

			//alert('DEBUG: returning intKeyGenResult = ' + intKeyGenResult);

			return intKeyGenResult;
		}
	} else {
		return true;
	}

	return true;
}

function getUserFp () { // retrieve stored user fingerprint from LocalStorage
	//alert('DEBUG: getUserFp() begin');

	if (window.localStorage) {
		// LocalStorage mode
		var fingerprint = localStorage.getItem('fingerprint');
		if (fingerprint) {
			return fingerprint;
		}
	} else {
		// fallback to cookie mode
		var fingerprint = GetCookie('cookie');

		if (fingerprint) {
			return fingerprint;
		}
	}

	// nothing found, we looked everywhere
	return null;
}

function sharePubKey (t) { // shares current user's public key via injected form and iframe
	//alert('DEBUG: profile.js: sharePubKey() begins');

	if (window.getPublicKey) {
		var pubKey = getPublicKey();

		//alert('DEBUG: sharePubKey: pubKey = ' + (pubKey ? pubKey : '(false)'));

		if (pubKey) {
			if (window.displayNotification) {
				if (t) {
					displayNotification('Creating profile...', t);
				} else {
					displayNotification('Creating profile...');
				}
			}

			//alert('DEBUG: sharePubKey: creating form');

			var form = document.createElement('form');
			form.setAttribute("action", "/post.html");
			form.setAttribute("method", "get");
			//form.setAttribute("target", "ifrSharePubKey");

			//alert('DEBUG: sharePubKey: creating input');

			var txtComment = document.createElement('input');
			txtComment.setAttribute("type", "hidden");
			txtComment.setAttribute("value", pubKey);
			txtComment.setAttribute("name", "comment");

			//alert('DEBUG: sharePubKey: adding txtComment to form');

			form.appendChild(txtComment);

			//alert('DEBUG: sharePubKey: adding form to body');

			//document.getElementsByTagName('body')[0].appendChild(form);

			document.body.appendChild(form);

			//alert('DEBUG: submitting form');

			form.submit();

			return false;
		} else {
			//alert('DEBUG: pubKey was FALSE');

			return true;
		}
	}

///// alternative method 1
//	window.open('/write.html#inspubkey', '_self');

///// alternative method 2
//	var iframe = document.createElement("iframe");
//	iframe.src = '/write.html#inspubkey';
//	iframe.name = "inspubkey"
//	iframe.style.display = 'none';
//	document.body.appendChild(iframe);

	//return 0;
}

function AddPrivateKeyLinks() { // adds save/load links to profile page if features are available
// #todo make it so that this can be called repeatedly and hide/show appropriate links

	//alert('DEBUG: AddPrivateKeyLinks() begin');

	if (document.getElementById && window.getPrivateKey) {
		var privateKey = getPrivateKey();
		var fieldset = document.getElementById('fldRegistration');

		if (fieldset && document.createElement) {
			//alert('DEBUG: AddPrivateKeyLinks: checks pass');

			if (privateKey) {
				//alert('DEBUG: AddPrivateKeyLinks: privateKey: true');

				// add horizontal rule
				var hrDivider = document.createElement('hr');
				fieldset.appendChild(hrDivider);

				// add [go to profile] link
				var pProfileLink = document.getElementById('spanProfileLink');
				if (pProfileLink && pProfileLink.innerHTML) {
					// profile link already there, and contains profile link
					// #todo bind js event to profile create
				} else {
					// profile link not there or the p is empty
					if (!pProfileLink) {
						pProfileLink = document.createElement('p');
					}

					// ATTENTION!
					// THERE IS A GOTCHA HERE: THIS LINK MAY BE ADDED BY PHP
					// IF SO, THEN THIS CODE WILL NOT EXECUTE!

					// "Go to profile" link
					var aProfile = document.createElement('a');
					aProfile.setAttribute('href', '/author/' + getUserFp() + '/index.html');
					aProfile.setAttribute('onclick', 'if (window.sharePubKey) { return sharePubKey(this); }');
					aProfile.setAttribute('id', 'linkGoToProfile');
					aProfile.innerHTML = 'Go to profile';

					// Append both to fieldset
					pProfileLink.appendChild(aProfile);
					fieldset.appendChild(pProfileLink);

					// add horizontal rule
					var hrDivider = document.createElement('hr');
					fieldset.appendChild(hrDivider);
				}

				// add [save as file] link
				var pSaveKeyAsTxt = document.createElement('p');
				var aSaveKeyAsTxt = document.createElement('a');
				aSaveKeyAsTxt.setAttribute('href', '#');
				aSaveKeyAsTxt.setAttribute('id', 'linkSavePrivateKey');
				aSaveKeyAsTxt.setAttribute('onclick', 'if (window.SavePrivateKeyAsTxt) { return SavePrivateKeyAsTxt(); }');
				aSaveKeyAsTxt.innerHTML = 'Save as file';

				// hint for [save as file] link
				var hintSaveKeyAsTxt = document.createElement('span');
				hintSaveKeyAsTxt.setAttribute('class', 'beginner');
				hintSaveKeyAsTxt.innerHTML = 'Save key to use again later';

				// insert [save as file] link into dom
				pSaveKeyAsTxt.appendChild(aSaveKeyAsTxt);
				pShowPrivateKey.appendChild(document.createElement('br'));
				pSaveKeyAsTxt.appendChild(hintSaveKeyAsTxt);
				fieldset.appendChild(pSaveKeyAsTxt);

				// add [show private key] link
				var pShowPrivateKey = document.createElement('p');
				var aShowPrivateKey = document.createElement('a');
				aShowPrivateKey.setAttribute('class', 'advanced');
				aShowPrivateKey.setAttribute('href', '#');
				aShowPrivateKey.setAttribute('id', 'linkShowPrivateKey');
				aShowPrivateKey.setAttribute('onclick', 'if (window.ShowPrivateKey) { return ShowPrivateKey(); }');
				aShowPrivateKey.innerHTML = 'Show private key';

				// hint for [show private key] link
				var hintShowPrivateKey = document.createElement('span');
				hintShowPrivateKey.setAttribute('class', 'beginner');
				hintShowPrivateKey.innerHTML = 'Display as text you can copy';

				pShowPrivateKey.appendChild(aShowPrivateKey);
				pShowPrivateKey.appendChild(document.createElement('br'));
				pShowPrivateKey.appendChild(hintShowPrivateKey);
				fieldset.appendChild(pShowPrivateKey);
			} // privateKey is true
			else {
				//alert('DEBUG: AddPrivateKeyLinks: privateKey: false');

				// add horizontal rule
				var hrDivider = document.createElement('hr');
				fieldset.appendChild(hrDivider);

				var pLoadKeyFromTxt = document.createElement('p');

				//alert('DEBUG: AddPrivateKeyLinks: creating file input...');

				// label for "load from file" button
				var labelLoadFromFile = document.createElement('label');
				labelLoadFromFile.setAttribute('for', 'fileLoadKeyFromText');
				labelLoadFromFile.innerHTML = 'Load from file:';

				// line break after label
				var brLoadFromFile = document.createElement('br');
				labelLoadFromFile.appendChild(brLoadFromFile);

				// "load from file" button itself
				var fileLoadKeyFromText = document.createElement('input');
				fileLoadKeyFromText.setAttribute('type', 'file');
				fileLoadKeyFromText.setAttribute('accept', 'text/plain');
				fileLoadKeyFromText.setAttribute('onchange', 'if (window.openFile) { openFile(event) } else { alert("openFile missing"); }');
				//fileLoadKeyFromText.setAttribute('style', 'display: none');
				fileLoadKeyFromText.setAttribute('id', 'fileLoadKeyFromText');

				// pLoadKeyFromTxt.appendChild(aLoadKeyFromText);
				labelLoadFromFile.appendChild(fileLoadKeyFromText);
				pLoadKeyFromTxt.appendChild(labelLoadFromFile);

				fieldset.appendChild(pLoadKeyFromTxt);
			} // privateKey is FALSE

			if (window.ShowAdvanced) {
				ShowAdvanced(1);
			}
		} // if (fieldset && document.createElement)
		else {
			//alert('DEBUG: AddPrivateKeyLinks: checks FAILED');
		}
	}
}

function ShowPrivateKey() { // displays private key in textarea
	//alert('DEBUG: ShowPrivateKey() begin');
	if (document.getElementById) {
		//alert('DEBUG: ShowPrivateKey: document.getElementById is true');

		var txtPrivateKey = document.getElementById('txtPrivateKey');
		if (txtPrivateKey) {
			//alert('DEBUG: ShowPrivateKey: txtPrivateKey is true');

			if (txtPrivateKey.style.display == 'none') {
				//alert('DEBUG: style is none, set to block');
				txtPrivateKey.style.display = 'block';
			} else {
				//alert('DEBUG: style is block, set to none');
				txtPrivateKey.style.display = 'none';
			}

			var linkShowPrivateKey = document.getElementById('linkShowPrivateKey');
			if (linkShowPrivateKey) {
				if (txtPrivateKey.style.display == 'none') {
					linkShowPrivateKey.innerHTML = 'Show private key';
				} else {
					linkShowPrivateKey.innerHTML = 'Hide private key';
				}
			}

			return false;
		}
	}

	if (window.getPrivateKey) {
		var privateKey = getPrivateKey();
		if (privateKey && document.createElement) {
			var txtPrivKey = document.createElement('textarea');
			txtPrivKey.setAttribute('cols', 80);
			txtPrivKey.setAttribute('rows', 24);
			txtPrivKey.setAttribute('id', 'txtPrivateKey');
			txtPrivKey.innerHTML = privateKey;

			var fldRegistration = document.getElementById('fldRegistration');
			if (fldRegistration) {
				fldRegistration.appendChild(txtPrivKey);
			} else {
				document.body.appendChild(txtPrivKey);
			}

			var linkShowPrivateKey = document.getElementById('linkShowPrivateKey');
			if (linkShowPrivateKey) {
				linkShowPrivateKey.innerHTML = 'Hide private key';
			}

			txtPrivKey.focus();

			return false;
		}
	}
}

function openFile (event) {
	//alert('DEBUG: openFile() begin');

	var input = event.target;

	if (window.FileReader) {
		reader = new FileReader();

		// this eval is for hiding the "=function(){}" syntax from incompatible browsers
		// they shouldn't try to execute it because they don't make it here due to other tests
		eval('reader.onload = function() { var text = reader.result; LoadPrivateKeyFromTxt(text); }');
		reader.readAsText(input.files[0]);
	}
}

function LoadPrivateKeyFromTxt (text) {
	if (window.setPrivateKeyFromTxt) {
		setPrivateKeyFromTxt(text);
	}
}

function StripToFilename (text) { // strips provided text to only filename-valid characters
	if (!text) return '';

	text = text.trim();

	if (!text) return '';

	var charsAllowed = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_';

	for (var i = 0; i < text.length; i++) {
		if (-1 < charsAllowed.indexOf(text.substr(i, 1))) {
			// ok
		} else {
			text = text.substr(0, i) + '' + text.substr(i + 1);
			i = i - 1;
		}
	}

	return text;
}

function getUsername2 () { // returns pgp username
// #todo cache it
    var openpgp = window.openpgp;

    if (openpgp) {
		// read it into pgp object
		var privKeyObj = openpgp.key.readArmored(getPrivateKey());

		// get the public key out of it
		var pubKeyObj = privKeyObj.keys[0].toPublic();

		var myUsername = pubKeyObj.users[0].userId.userid;

		return myUsername;
	}

	return '';
}

function SavePrivateKeyAsTxt() { // initiates "download" of private key as text file
	var myFp = getUserFp();
	var myUsername = getUsername2();
	var text = getPrivateKey();

	myUsername = StripToFilename(myUsername);

	return DownloadAsTxt(myUsername + '_' + myFp + '.txt', text);
}

// override cookie if we have a profile in LocalStorage
if (document.cookie) {
	//alert('DEBUG: cookie=' + document.cookie);
} else {
	//alert('DEBUG: document.cookie missing');
	if (window.localStorage) {
		//alert('DEBUG: window.localStorage exists');
		var fp = localStorage.getItem('fingerprint');
		if (fp) {
			//alert('DEBUG: fp exists, setting cookie via js');
			document.cookie = 'test=' + fp;
		}
	}
}

function PubkeyCheckProfileExists(fp) { // PLACEHOLDER checks if profile exists
// PLACEHOLDER, ALWAYS RETURNS TRUE
	//alert('DEBUG: PubkeyCheckProfileExists() begin');

	//alert('DEBUG: PubkeyCheckProfileExists: fp = ' + fp);

	var profileUrl = '/author/' + fp + '/';

	//alert('DEBUG: profileUrl = ' + profileUrl);

	if (UrlExists(profileUrl)) {
		//alert('DEBUG: lastPubKeyPing: profile exists');
		return true;
	} else {
		//alert('DEBUG: lastPubKeyPing: profile NOT FOUND');
		return false;
	}
}

function PubKeyPing () { // checks if user's public key is on server
// uploads it to server if it is missing
//
	//alert('DEBUG: PubKeyPing() begin');

	var lastPubKeyPing = GetPrefs('last_pubkey_ping');

	if (lastPubKeyPing && (time() < (lastPubKeyPing + 3600))) {
		//alert('DEBUG: PubKeyPing: lastPubKeyPing+10 = ' + (lastPubKeyPing+10) + ' < time() = ' + time());
	} else {
		//alert('DEBUG: PubKeyPing: lastPubKeyPing was false or stale, doing a check at ' + time());

		if (window.getUserFp) {
			//alert('DEBUG; PubKeyPing: window.getUserFp check passed');

			var myFingerprint = getUserFp();

			//alert('DEBUG: PubKeyPing: myFingerprint = ' + myFingerprint);

			if (myFingerprint) {
				if (PubkeyCheckProfileExists(myFingerprint)) {
					//alert('DEBUG: PubKeyPing: profile already exists');
				} else {
					if (window.sharePubKey) {
						//alert('DEBUG: PubKeyPing: lastPubKeyPing: window.sharePubKey check passed, doing it...');
						sharePubKey();
					} else {
						//alert('DEBUG: PubKeyPing: lastPubKeyPing: window.sharePubKey check FAILED');
					}
				}
			} else {
				//alert('DEBUG: PubKeyPing: myFingerprint: false');
			}

			//alert('DEBUG: PubKeyPing: lastPubKeyPing check complete, saving time');

			lastPubKeyPing = time();
			SetPrefs('last_pubkey_ping', lastPubKeyPing);
		} else {
			//alert('DEBUG: PubKeyPing: window.getUserFp check FAILED');
		}
	}
}

function ProfileOnLoad() { // onload event for profile page
	//alert('DEBUG: ProfileOnLoad() begin');

	var lblSigningIndicator;
	if (document.getElementById) {
		//alert('DEBUG: ProfileOnLoad: document.getElementById check passed');

		if (window.getPrivateKey) {
			//alert('DEBUG: ProfileOnLoad: window.getPrivateKey check passed');

			if (getUserFp() == '$currentAdminId') {
				// if user's fingerprint matches current admin, set show_admin true
				// show_admin is when operator controls are displayed
            	if (window.SetPrefs && window.GetPrefs) {
            		if (!GetPrefs('show_admin')) {
            			SetPrefs('show_admin', 1);
					}
            	}
            }

			if (window.localStorage) {
				//alert('DEBUG: ProfileOnLoad: window.localStorage check passed, calling getPrivateKey()...');

				var pk = getPrivateKey();

				// span used to indicate whether openpgp signing is available
				lblSigningIndicator = document.getElementById('lblSigningIndicator');

				if (pk) {
					//alert('DEBUG: ProfileOnLoad: pk = GetPrivateKey() = ' + !!pk);

					if (lblSigningIndicator) {
						lblSigningIndicator.innerHTML = 'Yes';

						AddPrivateKeyLinks();
					}

					lblHandle = document.getElementById('lblHandle');

					if (lblHandle) {
						var strHandle = localStorage.getItem('avatar');
						if (strHandle) {
							lblHandle.innerHTML = strHandle;
						}
					}

					lblFingerprint = document.getElementById('lblFingerprint');

					if (lblFingerprint) {
						var strFingerprint = localStorage.getItem('fingerprint');
						if (strFingerprint) {
							lblFingerprint.innerHTML = strFingerprint;
						}
					}

					//alert('DEBUG: ProfileOnLoad: calling PubKeyPing()');
					PubKeyPing();
				} else {
					//alert('DEBUG: pk = false')
					if (lblSigningIndicator) {
						//alert('DEBUG: lblSigningIndicator check passed');
						if (window.openpgp) {
							//alert('DEBUG: window.openpgp check passed, setting no (available)');

							lblSigningIndicator.innerHTML = 'Available';

							AddPrivateKeyLinks();
						} else {
							//alert('DEBUG: window.openpgp check passed, setting nope');

							lblSigningIndicator.innerHTML = 'Nope';
						}
					} else {
						//alert('DEBUG: lblSigningIndicator check FAILED');
					}
				}
			} else {
				//alert('DEBUG: ProfileOnLoad: window.localStorage check FAILED');
			}
		} else {
			//alert('DEBUG: ProfileOnLoad: window.getPrivateKey check FAILED');
		}
	} else {
		//alert('DEBUG: ProfileOnLoad: document.getElementById check FAILED');
	}
}

function SetCookie(cname, cvalue, exdays) { // set cookie
// #todo this is untested and unused at this time
	var d = new Date();
	d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
	var expires = "expires="+d.toUTCString();
	document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
}

function GetCookie (cname) { // get cookie value
	// in js, cookies are accessed via one long string of the form
	// key1=value1; key2=value2;
	// so we make an array, splitting the string using the ; separator
	var ca = document.cookie.split(';');

	// the value we are looking for will be prefixed with cname=
	var name = cname + "=";

	for(var i = 0; i < ca.length; i++) {
		// loop through ca array until we find prefix we are looking for
		var c = ca[i];
		while (c.charAt(0) == ' ') {
			// remove any spaces at beginning of string
			c = c.substring(1);
		}
		if (c.indexOf(name) == 0) {
			// if prefix matches, return value
			return c.substring(name.length, c.length);
		}
	}

	// at this point, nothing left to do but return empty string
	return "";
}

// end profile.js