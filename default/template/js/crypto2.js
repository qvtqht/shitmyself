// == begin crypto2.js

// these are used to globally store the user's fingerprint and username
var myFingerprint = '';
var myUsername = '';

//alert('DEBUG: crypto2.js begins');

function time() { // returns epoch time
    var d = new Date();
    return Math.floor(d.getTime() / 1000);
}

function SimpleBenchmark() { // simple benchmark
    //alert('DEBUG: SimpleBenchmark() begins');

    var i = 0;
    for (i = 0; i <= time() * 1000; i++) {
        i += time();
    }

    //alert('DEBUG: SimpleBenchmark() returning ' + (i/time()));

    return (i / time());
}

function MakeKey () { //makes key using default settings
// once key is generated, store it to localStorage

	//alert('DEBUG: MakeKey() begin');
	var openpgp = window.openpgp;

	//var gt = String.fromCharCode(62);
	var gt = unescape('%3E');

	//alert('DEBUG: MakeKey: openpgp: ' + !!openpgp);

	if (openpgp) {
		// if openpgp is loaded, proceed with client-side key generation

		//alert('DEBUG: SimpleBenchmark() returns ' + SimpleBenchmark());

		// it's a bit convoluted here at the moment
		// bits refers to rsa bits
		// BUT if it is not a number, it refers to the alternative algorithm
		// this is used later to select it with an if statement
		// algoSelectMode, in turn is used to select the value of bits
		// it's ok to just leave it at 2048
		// for dev purposes, it's ok to use 512 for faster keygen
		// 512 is reasonably secure, meaning it would take more than an hour to break it

		var bits = 2048; // decent default. reasonably fast, backwards compatible

		var algoSelectMode = 0; // this is set from template when it's generated
		// 0 means leave it alone at bits = 2048, which is the sanest default

		if (algoSelectMode == '512') { // fast and breakable, good for testing and art projects
			var bits = 512;
		}
		if (algoSelectMode == 'random') { // randomize decent crypto
			var bitsOptions = [2048, 'curve25519', 'ed25519', 'p256', 'p384', 'p521', 'secp256k1'];
			var bits = bitsOptions[Math.floor(Math.random() * bitsOptions.length)];
		}
		if (algoSelectMode == 'max') { // slow, more secure
			var bits = 4096;
			//var bits = bitsOptions[Math.floor(Math.random() * bitsOptions.length)];
		}

		// full options list:
		// 512 1024 2048 4096
		// 'curve25519' 'ed25519' 'p256' 'p384' 'p521' 'secp256k1'

		var username = 'Guest';
		username = prompt('Choose your handle:', username);

		//alert('DEBUG: username: ' + username);

		if (username == null) {
			//alert('DEBUG: username == null is true');
		} else {
			//alert('DEBUG: username == null is false');

			if (!username || !username.trim()) {
				username = 'Guest';
			}

			//alert('DEBUG: username: ' + username);

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

			openpgp.config.show_version = false;
			openpgp.config.show_comment = false;

			openpgp.generateKey(options).then(
				function(key) {
					var privkey = key.privateKeyArmored; // '-----BEGIN PGP PRIVATE KEY BLOCK ... '
					var pubkey = key.publicKeyArmored;   // '-----BEGIN PGP PUBLIC KEY BLOCK ... '
					var revocationCertificate = key.revocationCertificate; // '-----BEGIN PGP PUBLIC KEY BLOCK ... '

					openpgp.key.readArmored(privkey);

					// read it into pgp object
					var privKeyObj = openpgp.key.readArmored(privkey);;

					// get the public key out of it
					var pubKeyObj = privKeyObj.keys[0].toPublic();

					// store the armored version into localStorage
					var pubkey = pubKeyObj.armor();

					// get the fingerprint as uppercase hex and store it
					var myFingerprint = pubKeyObj.primaryKey.keyid.toHex().toUpperCase();

					// get username out of key
					var myUsername = pubKeyObj.users[0].userId.userid;

					//var gt = String.fromCharCode(62);
					var gt = unescape('%3E');

					var avatar = escapeHTML(myUsername);

					window.localStorage.setItem('privatekey', privkey);
					window.localStorage.setItem('publickey', pubkey);
					window.localStorage.setItem('fingerprint', myFingerprint);
					window.localStorage.setItem('avatar', avatar);

					document.cookie = "test=" + myFingerprint;

					//alert('DEBUG: about to share public key');

					window.location = '/profile.html?' + myFingerprint;

					//	if (window.sharePubKey) {
					//		//alert('DEBUG: window.sharePubKey exists. calling');
					//		//sharePubKey();
					//
					//		return true;
					//	} else {
					//		//alert('DEBUG: window.sharePubKey does NOT exist, using widow.location');
					//
					//		window.location = '/write.html#inspubkey';
					//		return true;
					//	}
				}
			);

			return false;

		}

	}

	return true;
}

function getPrivateKey() { // get private key from local storage
// returns null otherwise
    //alert('DEBUG: getPrivateKey() begins');

	if (window.localStorage) {
	    //alert('DEBUG: getPrivateKey: window.localStorage is true, checking for localStorage.getItem(privatekey)');

		var privateKey = localStorage.getItem("privatekey");

		if (privateKey) {
		    //alert('DEBUG: getPrivateKey: found something in localStorage: ' + !!privateKey);

			return privateKey;
		} else {
		    //alert('DEBUG: getPrivateKey: found nothing in localStorage');

			return null;
		}
	} else {
		return null;
	}
}

function getPublicKey() { // get public key from local storage
// returns null otherwise

    //alert('DEBUG: getPublicKey() begins');

	if (window.localStorage) {
	    //alert('DEBUG: getPublicKey: window.localStorage is true, checking for localStorage.getItem(publickey)');

		var publicKey = localStorage.getItem("publickey");

		if (publicKey) {
		    //alert('DEBUG: getPublicKey: found in localStorage: ' + publicKey);

			return publicKey;
		} else {
		    //alert('DEBUG: getPublicKey: not found in localStorage');

			return null;
		}
	} else {
		return null;
	}
}

function setPrivateKeyFromTxt (newKey) { // set the current private key and refresh the pubkey, fingerprint, and avatar too
	var gt = unescape('%3E'); // greater thean symbol, which we hide from mosaic

    //window.localStorage.setItem("privatekey", newKey);

    if (document.head && document.head.appendChild && document.getElementById && window.localStorage) {
        //alert('DEBUG: setPrivateKeyFromTxt: document.head: ' + !!document.head + '; document.head.appendChild = ' + !!document.head.appendChild + '; document.getElementById = ' + !!document.getElementById + '; window.localStorage: ' + !!window.localStorage);

        if (!window.openpgp) {
            // load openpgp.js if we haven't already and if we have the dependencies

            //alert('DEBUG: setPrivateKeyFromTxt: checks passed, loading openpgp.js');

			window.openPgpJsLoadBegin = 1;

            var script = document.createElement('script');
            script.src = '/openpgp.js';
            script.async = false; // This is required for synchronous execution
            document.head.appendChild(script);

            //alert('DEBUG: setPrivateKeyFromTxt: finished loading openpgp.js');
        } else {
            //alert('DEBUG: setPrivateKeyFromTxt: window.openpgp already exists');
        }
    } else {
        return '';
    }

    var openpgp = window.openpgp;

    // don't display version and comment
    openpgp.config.show_version = false;
    openpgp.config.show_comment = false;

    // read it into pgp object
    var privKeyObj = openpgp.key.readArmored(newKey);

    // get the public key out of it
    var pubKeyObj = privKeyObj.keys[0].toPublic();

    // store the armored version into localstorage
    var pubkey = pubKeyObj.armor();
    window.localStorage.setItem("publickey", pubkey);

    // get the fingerprint as uppercase hex and store it
    var myFingerprint = pubKeyObj.primaryKey.keyid.toHex().toUpperCase();
    // get username out of key

    var myUsername = pubKeyObj.users[0].userId.userid;
    var avatar = escapeHTML(myUsername);
    var privkey = privKeyObj.privateKeyArmored;

    // save to localStorage
    window.localStorage.setItem('privatekey', newKey);
    window.localStorage.setItem('publickey', pubkey);
    window.localStorage.setItem('fingerprint', myFingerprint);
    window.localStorage.setItem('avatar', avatar);

    document.cookie = "test=" + myFingerprint;

    window.location = '/profile.html?' + myFingerprint;

    // this will submit public key as an item to the board
    if (window.PubKeyPing) {
    	PubKeyPing();
    } else {
    	window.location = '/write.html#inspubkey';
	}
}

function getUsername () { // returns pgp username
	var openpgp = window.openpgp;

    if (window.getUsernameReturn) {
    	return window.getUsernameReturn;
	}

    if (openpgp) {
		// read it into pgp object
		var privKeyObj = openpgp.key.readArmored(getPrivateKey());

		// get the public key out of it
		var pubKeyObj = privKeyObj.keys[0].toPublic();
		var myUsername = pubKeyObj.users[0].userId.userid;

		window.getUsernameReturn = myUsername;

		return myUsername;
	}

	return '';
}

function signMessage() { // find the compose textbox and sign whatever is in it
// if message is already signed or is a public key, exit
// relies on getElementById and localStorage
// submits the form when finished
// #todo maybe some of these things can/should be decoupled?

	//alert('DEBUG: signMessage() begin');

	var privkey = getPrivateKey();
	if (privkey) {
	    // private key exists, can proceed
		//alert('DEBUG: signMessage: privkey is true');

		var textbox = document.getElementById('comment');
		var composeForm = document.getElementById('compose');

		if (textbox && composeForm && window.openpgp) {
			//alert('DEBUG: signMessage: textbox && composeForm is true');

			// this would change textbox appearance to indicate something happened
			// textbox.style.color = '#00ff00';
			// textbox.style.backgroundColor = '#c0c000';

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
			// look for a replyto field

			if (replyTo) {
			    // if replyto exists, prepend it contents to the message as a (gtgt) token
				var replyToId = replyTo.value;
				if (replyToId) {
					var gt = unescape('%3E');
					if (-1 < message.indexOf(gt + gt + replyToId)) {
					} else {
						message = gt + gt + replyToId + '\n\n' + message;
					}
				}
			}

			var privKeyObj = openpgp.key.readArmored(privkey).keys[0];
			//
			// privateKey.decrypt('hello');
			// var privKeyObj = (await openpgp.key.readArmored(privkey)).keys[0];
			// await privKeyObj.decrypt(passphrase);

            // set basic options for signing the message
			options = {
				data: message,                             // input as String (or Uint8Array)
				privateKeys: [privKeyObj]                  // for signing
			};

            openpgp.config.show_version = false; // don't add openpgp version message to output
			openpgp.config.show_comment = false; // don't add comment to output
			openpgp.sign(options).then(function(signed) {
			    // begin signing process

			    // put the signed data into th textbox when it's done
				textbox.value = signed.data;
				// submit the form
				composeForm.submit();
			});
			return false; // don't submit the form yet, will submit after signed
		}
		return true; // let the form submit
	} else {
		// this is an edge case
		// user signed out in another window, but wants to sign in this one
		// signing is no longer possible, so just submit to be on safe side
		return true;
	}

	return true;
}

function cryptoJs() { // used for checking if crypto2.js has been loaded
	return 1;
}

//alert('DEBUG: crypto2.js ends');


// == end crypto2.js