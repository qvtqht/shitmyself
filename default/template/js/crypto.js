// == begin crypto.js

// this file depends on the following:
// === operator
// localStorage
//

// these are used to globally store the user's fingerprint and username
var myFingerprint = '';
var myUsername = '';

// window.confct holds the remaining seconds before the undo button disappears

function getPrivateKey() { // get private key from local storage
// returns null otherwise
	if (window.localStorage) {
		var privateKey = localStorage.getItem("privatekey");

		if (privateKey === null || privateKey.length === 0) {
			return null;
		} else {
			return privateKey;
		}
	} else {
		return null;
	}
}

function buttonSignOut(t) { // sign out button is clicked. t is button's this
// depending on window.signOutButtonStatus,
// displays undo countdown or signs out completely, emptying trash
// #todo move this function to profile.js
	var gt = String.fromCharCode(62);

	if (window.signOutButtonStatus) {
		logOut(t);
	} else {
		window.privKeyTrash = getPrivateKey();

		removeStoredKeys();

		document.getElementById('locm').style.display='inline';
		t.style.backgroundColor='red';
		t.style.color='white';
		window.signOutButtonStatus = 1;

		window.confct = 11;
		document.getElementById('btnUndo').value = 'Undo? ' + window.confct;

		var signinBox = document.getElementById('signin');
		if (signinBox) {
			signinBox.innerHTML = '<a href="/profile.html"' + gt + 'Profile</a' + gt;
		}

		signoutCounterDecrement();
		// this function will set a timer to call itself until undo period ends
	}
}

function undoSignout(t) { // undo signout, if possible
// #todo move this function to profile.js
	setPrivateKey(window.privKeyTrash);
	saveId();

	t = document.getElementById('rmid');
	disarmSignoutButton(t);

	var signinBox = document.getElementById('signin');
	signinBox.innerHTML = '<a href="/profile.html"><i>Profile</i></a>';
}

function signoutCounterDecrement() {
	var ct = window.confct;

	if (!window.privKeyTrash) {
		return '';
	}

	if (ct) {
		if (isNaN(ct)) {
			// nothing
		} else {
			if (ct > 0) {
				window.confct = (ct - 1);
				bu = document.getElementById('btnUndo');
				bu.value = "Undo? " + ct;

				setTimeout(function(){
					signoutCounterDecrement();
				}, 1000);
			}
		}
	} else if (ct == 0) {
		var rmid = document.getElementById('rmid');
		buttonSignOut(rmid);
		logOut2();
		disarmSignoutButton(rmid);
		window.privKeyTrash = '';
		showHideForms();
	}
}

function disarmSignoutButton(t) { // return sign out button to its normal state
	t.style.backgroundColor = '$colorWindow';
	t.style.color = 'red';
	window.signOutButtonStatus = 0;
	window.privKeyTrash = '';
	document.getElementById('locm').style.display='none';
}

var loadingDone = document.getElementById('loading');
if (loadingDone) {
	loadingDone.style.display = 'none';
}


function logOut2() {
	removeStoredKeys();

	// clear the private key textbox if it can be found
	var textbox = document.getElementById("privatekey");
	if (textbox) {
		textbox.value = '';
	}

	// clear the public key textbox if it can be found
	textbox = document.getElementById("publickey");
	if (textbox) {
		textbox.value = '';
	}

	// remove displayed avatar at the top of the page
	var avatar = document.getElementById("myid");
	if (avatar) {
		avatar.innerHTML = '';
	}

	var privateKey = 0;

	if (window.localStorage) {
		privateKey = localStorage.getItem("privatekey");
	}

	return privateKey;
}

function removeStoredKeys() { // log out
	if (window.localStorage) {
		var ls = window.localStorage;
		ls.removeItem('privatekey');
		ls.removeItem('publickey');
		ls.removeItem('fingerprint');
		ls.removeItem('avatar');
	}
}

function getPublicKey() { // returns current user's stored public key from localstorage
	var publicKey = localStorage.getItem("publickey");
	if (publicKey === null || publicKey.length === 0) {
		return null;
	} else {
		return publicKey;
	}
}

// puts generated html avatar into localstorage
function setAvatar(avatar) {
	//alert('DEBUG: setAvatar(' + avatar + ')');
	window.localStorage.setItem("avatar", avatar);
}

function hexToChar(string) { // converts hex characters to symbols for the now unused
// used by avatars that included different symbols instead of just two asterisks

	return string.replace(/0/gi,'~').replace(/1/gi,'@').replace(/2/gi,'#').replace(/3/gi,'$').replace(/4/gi,'%').replace(/5/gi,'^').replace(/6/gi,'&').replace(/7/gi,'*').replace(/8/gi,'+').replace(/9/gi,'=').replace(/a/gi,'>').replace(/b/gi,'<').replace(/c/gi,'|').replace(/d/gi,'}').replace(/e/gi,':').replace(/f/gi,'+');
}

function saveId() { // set the current private key and refresh the pubkey, fingerprint, and avatar too
// only if there's a private key textbox,
// not much validation currently #todo

	var gt = String.fromCharCode(62);

	// look for textbox
	var textbox = document.getElementById("privatekey");

	if (textbox) {
		var privkey = textbox.value;

		// store it to localstorage
		setPrivateKey(privkey);

		if (!window.openpgp && document.head && document.head.appendChild && document.getElementById && window.localStorage) {
			window.openPgpJsLoadBegin = 1;

			var script = document.createElement('script');
			script.src = '/openpgp.js';
			script.async = false; // This is required for synchronous execution
			document.head.appendChild(script);
		}

		var openpgp = window.openpgp;

		openpgp.config.show_version = false;
		openpgp.config.show_comment = false;

		// read it into pgp object
		var privKeyObj = openpgp.key.readArmored(privkey);;

		// get the public key out of it
		var pubKeyObj = privKeyObj.keys[0].toPublic();

		// store the armored version into localstorage
		var pubkey = pubKeyObj.armor();
		setPublicKey(pubkey);

		// get the fingerprint as uppercase hex and store it
		myFingerprint = pubKeyObj.primaryKey.keyid.toHex().toUpperCase();
		window.localStorage.setItem("fingerprint", myFingerprint);

		// get username out of key
		myUsername = pubKeyObj.users[0].userId.userid;

		avatar = escapeHTML(myUsername);

		setAvatar(avatar);

		// if there is a myid box, populate it appropriately
		var myidBox = document.getElementById('myid');
		if (myidBox) {
			var myAvatar = localStorage.getItem('avatar');
			var signinBox = document.getElementById('signin');

			if (myAvatar == null || myAvatar.length == 0) {
				if ( !document.getElementById("privatekey")) {
					if (signinBox) {
						var ltChar = String.fromCharCode(62);
						signinBox.innerHTML = '<a href="/profile.html"' + gt + 'Profile</a' + gt;
					}
				}
			} else {
				//signinBox.innerHTML = '';

				var myFp = localStorage.getItem('fingerprint');

				//myidBox.innerHTML = '<a href="/profile.html" class=avatar>' + myAvatar + '</a>';
				if (window.GetPrefs) {
					if (GetPrefs('display_username')) {
						myidBox.innerHTML = '<a href="/profile.html" class=avatar' + gt + myAvatar + '</a' + gt;
						if (signinBox) {
							signinBox.innerHTML = '';
						}
					} else {
						if (signinBox) {
							signinBox.innerHTML = '<a href="/profile.html"' + gt + '<i' + gt + 'Profile</i' + gt + '</a' + gt;
						}
					}
				} else {
					if (signinBox) {
						signinBox.innerHTML = '<a href="/profile.html"' + gt + '<i' + gt + 'Profile</i' + gt + '</a' + gt;
					}
				}

				var myId2 = document.getElementById('myId2');
				if (myId2) {
					myId2.innerHTML = '<a href="/author/' + myFp + '/"' + gt + getAvatar() + '</a' + gt; //todo remove hardcoding of url
				}

				var myIdProfile = document.getElementById('myIdProfile');
				if (myIdProfile) {
					var profileUrl = '/author/' + myFingerprint + '/';

					if (UrlExists(profileUrl)) {
						myIdProfile.innerHTML = '<span class=beginner><a href="' + profileUrl + '">Go to your Profile page</a></span>';
						ShowAdvanced(1);
					} else {
						myIdProfile.innerHTML = '';
					}
				}

				var myCrea = document.getElementById('myCrea');
				if (myCrea) {
					var idCreationTime = pubKeyObj.primaryKey.created.toString();

					if (idCreationTime.indexOf(' GMT-') != -1) {
						idCreationTime = idCreationTime.substring(0, idCreationTime.indexOf(' GMT-'));
					}

					myCrea.innerHTML = idCreationTime;
				}

				var myFinger = document.getElementById('myFP');
				if (myFinger) {
					myFinger.innerHTML = pubKeyObj.primaryKey.keyid.toHex().toUpperCase();
				}
			}

			showHideForms();
		}
	}
}

function setPrivateKey(privateKey) {
	window.localStorage.setItem("privatekey", privateKey);
}

function setPublicKey(publicKey) {
	window.localStorage.setItem("publickey", publicKey);
}

function getPublicKeyFromPrivateKey (privateKey) {
	var openpgp = window.openpgp;
	openpgp.initWorker({path:'openpgp.worker.js'});

	var privKeyObj = openpgp.key.readArmored(privateKey).keys[0];
}

function makePrivateKey (username, bits) { // generate private key with provided username and algorithm
	if (window.localStorage) {
		var privateKey = getPrivateKey();

		if (!privateKey) {
			var privkey;
			var pubkey;

			var openpgp = window.openpgp;
			openpgp.initWorker({path:'openpgp.worker.js'});

			var options;
			if (bits == 512 || bits == 1024 || bits == 2048 || bits == 4096) {
				options = {
					userIds: [{ name: username }],
					numBits: bits,
					passphrase: ''
				};
			} else {
				options = {
					userIds: [{ name: username }],
					curve: bits,
					passphrase: ''
				};
			}

			var textbox = document.getElementById("privatekey");
			var genStatus = document.getElementById('genStatus');
			if (genStatus) {
				genStatus.innerHTML = 'Working...';
			}
			var cSb = document.getElementById('cSb');
			if (cSb) {
				cSb.disabled = 1;
			}

			openpgp.config.show_version = false;
			openpgp.config.show_comment = false;

			openpgp.generateKey(options).then(
				function(key) {
					setPrivateKey(key.privateKeyArmored);
					if (textbox) {
						textbox.value = key.privateKeyArmored;
					}
					if (genStatus) {
						genStatus.innerHTML = '';
					}
					if (cSb) {
						cSb.disabled = 0;
					}

					saveId();

					setPublicKey(key.publicKeyArmored);

					sharePubKey();

//					sharePubKey();

//					var btnSharePubkey = document.getElementById('btnSharePub');
//					if (btnSharePubkey) {
//						btnSharePubkey.value = 'Share Public Key';
//						btnSharePubkey.disabled = false;
//					}
//
					//return frames["frame"].location.host;

					//window.open('/write.html#inspubkey', '_self');
				}
			);
		} else {
			// key already exists in storage
		}
	} else {
		// sorry, your browser does not support Web Storage...
	}
}

function makeKeyFromInputs() {
	var privkey = getPrivateKey();

	if (privkey) {
		logOut2();
	}

	var user = document.getElementById('name').value;
	var bits = document.getElementById('bits').value;

	makePrivateKey(user, bits);

	return 0;
}

function signForm(formId) {
	var form = document.getElementById(formId);
	if (form) {
		var elements = form.elements;

		for (var i=0, element; element = elements[i++];) {
			//alert(element.type);
			//alert(element.name);
			//alert(element.value);
		}

		//	var elements = document.getElementById("my-form").elements;
		//
		//    for (var i = 0, element; element = elements[i++];) {
		//        if (element.type === "text" && element.value === "")
		//            console.log("it's an empty textfield")
		//    }

		//function getFormElelemets(formName){
		//  var elements = document.forms[formName].elements;
		//  for (i=0; i<elements.length; i++){
		//    some code...
		//  }
		//}

		//document.getElementById("someFormId").elements;


		//document.forms["form_name"].getElementsByTagName("input");


	} else {
		return null;
	}
}

//signForm('compose');
//
//function signMessage2(message) {
//	var privkey = getPrivateKey();
//
//	if (privkey) {
//		var textbox = document.getElementById('comment');
//		var composeForm = document.getElementById('compose');
//
//		textbox.style.color = '#00ff00';
//		textbox.style.backgroundColor = '#c0c000';
//
//		if (textbox && composeForm) {
//			var message = textbox.value;
//
//			var privKeyObj = openpgp.key.readArmored(privkey).keys[0];
//
//			options = {
//				data: message,                             // input as String (or Uint8Array)
//				privateKeys: [privKeyObj]                  // for signing
//			};
//
//			openpgp.config.show_version = false;
//
//			openpgp.config.show_comment = false;
//
//			openpgp.sign(options).then(function(signed) {
//				textbox.value = signed.data;
//				composeForm.submit();
//			});
//		}
//	} else {
//		alert('No identity defined, cannot sign.');
//	}
//
//}

function signMessage() {
	//alert('DEBUG: signMessage() begin');

	var privkey = getPrivateKey();

	if (privkey) {
		//alert('DEBUG: signMessage: privkey is true');

		var textbox = document.getElementById('comment');
		var composeForm = document.getElementById('compose');

		if (textbox && composeForm) {
			//alert('DEBUG: signMessage: textbox && composeForm is true');

//			textbox.style.color = '#00ff00';
//			textbox.style.backgroundColor = '#c0c000';

			var message = textbox.value;
			
			// if the message already has the header,
			//    assume it's already signed and return
			// #todo make it also verify that it's signed before returning
			// #todo some kind of *unobtrusive* indicator/confirmation/option
			// #todo change color of textbox when message is properly signed

			if (message.trim().substring(0, 34) == ('-----BEGIN PGP SIGNED MESSAGE-----')) {
				//alert('DEBUG: signMessage: message is already signed, returning');

				return true;
			}
			
			if (message.trim().substring(0, 36) == ('-----BEGIN PGP PUBLIC KEY BLOCK-----')) {
				//alert('DEBUG: signMessage: message contains public key, returning');

				return true;
			}

			var replyTo = document.getElementById('replyto');

			if (replyTo) {
				var replyToId = replyTo.value;

				if (replyToId) {
					if (message.indexOf('>>' + replyToId) > -1) {
					} else {
						message = '>>' + replyToId + '\n\n' + message;
					}
				}
			}
//			
			var privKeyObj = openpgp.key.readArmored(privkey).keys[0];
//
//			privateKey.decrypt('hello');
//
//			var privKeyObj = (await openpgp.key.readArmored(privkey)).keys[0];
//			await privKeyObj.decrypt(passphrase);
//			

			options = {
				data: message,                             // input as String (or Uint8Array)
				privateKeys: [privKeyObj]                  // for signing
			};

			openpgp.config.show_version = false;

			openpgp.config.show_comment = false;

			openpgp.sign(options).then(function(signed) {
				textbox.value = signed.data;
				composeForm.submit();
			});

			return false;
		}

		return true;
	} else {
		// this is an edge case
		// user signed out in another window, but wants to sign in this one
		// signing is no longer possible, so just submit to be on safe side
	}

	return true;
}

function writeOnload2() {
	if (window.location.hash) {
		if (window.location.hash == '#inspubkey') {
			insPubKey();
		}
		if (window.location.hash == '#insvotes') {
			insVotes();
		}
		if (window.location.hash == '#profile') {
			insProfileTemplate();
		}
	}
	if (window.localStorage && window.localStorage.getItem('writesmall')) {
	    var writebox = document.getElementById('comment');
	    if (writebox) {
	        writebox.value = localStorage.getItem('writesmall');
	        localStorage.removeItem('writesmall');
	    }
	}
	if (document.getElementById) {
		var writeAdvL = document.getElementById('writeAdvL');
		if (writeAdvL) {
			writeAdvL.style.display = 'inline';
		}
		var userRadio = document.getElementById('userRadio');
//		alert(userRadio);
		if (userRadio) {
			if (window.getAvatar) {
				if (getAvatar()) {
					userRadio.innerHTML = '<label for=asign><input id=asign type=radio name=a value=sign> Sign as ' + getAvatar() + '</label>';
					//}
					var asign = document.getElementById('asign');
					if (asign) {
						asign.checked = 1;
						asign.checked = true;
					}
					//userRadio.innerHTML = '...';
				} else {
					userRadio.innerHTML = 'Sign in to post under identity.';
				}
			}
		}
	}
}
//
//function writeSubmit() {
//	if (document.forms['compose'].aanon.checked) {
//		return true;
//	} else if (document.forms['compose'].asign.checked) {
//		signMessage();
//		return false;
//	} else {
////		console.log('neither anonymous nor signed option is checked. this should not happen under normal circumstances. submitting anyway!');
//		return true;
//		// this should not happen
//	}
//}

function cryptoJs() {
	return 1;
}


//var statusBox = document.getElementById('status');
//if (statusBox) {
//	statusBox.value = statusBox.value + '\nReady!';
//}

// == end crypto.js
