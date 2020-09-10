// == begin write.js

function writeOnload() { // onload handler for write page
	//alert('DEBUG: writeOnload() begin');

	if (document.getElementById) {
	    //alert('DEBUG: writeOnload: document.getElementById is true');

        var pubKey = '';
        if (window.getPublicKey) {
        	//alert('DEBUG: window.getPublicKey exists');

        	pubKey = getPublicKey();
        }

        var privKey = '';
        if (window.getPrivateKey) {
            //alert('DEBUG: window.getPrivateKey exists');

            privKey = getPrivateKey();
        }

        //alert('DEBUG: privKey = ' + !!privKey);
        //alert('DEBUG: pubKey = ' + !!pubKey);

        if (privKey) {
            //alert('DEBUG: privKey was true, adding options...');

			if (document.getElementById('spanSignAs')) {
				var gt = unescape('%3E');
				if (window.getAvatar) {
					var spanSignAs = document.getElementById('spanSignAs');
					if (!GetPrefs('sign_by_default')) {
						var btnSignAs = document.createElement('input');
						btnSignAs.setAttribute('onclick', 'if(window.signMessage){signMessage();}this.value="Meditate...";');
						btnSignAs.setAttribute('type', 'submit');
						btnSignAs.setAttribute('value', 'Sign as ' + getAvatar());
						//btnSignAs.innerHTML = 'Sign as ' + getAvatar(); // use this if it is a GTbuttonLT
						spanSignAs.appendChild(btnSignAs);

					} else { // this is for the sign yes/no checkbox
						var lblSignAs = document.createElement('label');
						lblSignAs.setAttribute('for', 'chkSignAs');

						var chkSignAs = document.createElement('input');
						//chkSignAs.setAttribute('name', 'signAs');
						chkSignAs.setAttribute('id', 'chkSignAs');
						chkSignAs.setAttribute('type', 'checkbox');
						chkSignAs.setAttribute('checked', 1);
						// this checkbox being checked means signMessage() is called in writeSubmit()

						lblSignAs.innerHTML = 'Sign as ' + getAvatar();

						lblSignAs.appendChild(chkSignAs);

						spanSignAs.appendChild(lblSignAs);
					}


					if (window.makeCoin) {
						var spanWriteAdvanced = document.getElementById('spanWriteAdvanced');
						if (spanWriteAdvanced) {
							var btnMakeCoin = document.createElement('input');
							btnMakeCoin.setAttribute('type', 'button');
							btnMakeCoin.setAttribute('value', 'Make a coin, sign, and send');
							btnMakeCoin.setAttribute('onclick', "if (window.makeCoin) { document.compose.comment.value += '\\n\\n' + makeCoin(this); signMessage(); writeSubmit(); } return false;");
							spanWriteAdvanced.appendChild(btnMakeCoin);

							var br = document.createElement('br');
							spanWriteAdvanced.appendChild(br);

							var lblMakeCoin = document.createElement('span');
							lblMakeCoin.setAttribute('class', 'beginner');
							lblMakeCoin.innerHTML = 'Proof of work coin helps prevent spam.';
							spanWriteAdvanced.appendChild(lblMakeCoin);
						}

					}
				}
			}
//
//			if (document.getElementById('addtext')) {
//				document.getElementById('addtext').value = 'Sign Message and Send';
//			}

        }

        if (pubKey) {
            //alert('DEBUG: pubKey was true, adding options...');

//            if (window.PubKeyPing) {
//            	PubKeyPing();
//            }
//
//            var spanInsPubKey = document.getElementById('spanInsPubKey')
//			if (spanInsPubKey) {
//	            var gt = unescape('%3E');
//			    spanInsPubKey.innerHTML = '<span class=beginner' + gt + '<br' + gt + 'Re-upload your public </span' + gt + '<a href="/write.html?#inspubkey"' + gt + 'Profile</a' + gt + ';';
//			}
        }

        if (window.location.hash) {
            //alert('DEBUG: window.location.hash = ' + window.location.hash);

            if (window.location.hash == '#inspubkey') {
                //alert('DEBUG: #inspubkey found');

				if (pubKey) {
					//alert('DEBUG: pubKey is true, inserting it into comment');

					var comment = document.getElementById('comment');

					if (comment) {
						comment.value = pubKey;
					}

					var compose = document.getElementById('compose');

					if (compose) {
						if (compose.submit) {
							compose.submit();
						}
					}
                } else {
                    //alert('DEBUG: pubKey was false, this is unexpected. Giving up.');
                }
            }
        }
    } else {
        //alert('DEBUG: writeOnload: document.getElementById was FALSE');
    }

	if (window.signMessage) {

	}
}

function writeSubmit (t) { // called when user submits write form
	//alert('DEBUG: writeSubmit() begin');

	if (window.localStorage) {
		//alert('DEBUG: window.localStorage');
	} else {
		//alert('DEBUG: no window.localStorage');
	}

	if (window.getPrivateKey && window.signMessage) {
		//alert('DEBUG: window.getPrivateKey && window.signMessage test passed');
		if (getPrivateKey()) {
			//alert('DEBUG: getPrivateKey() is true, writeSubmit() Calling signMessage()');

			if (document.getElementById) {
				if (document.getElementById('chkSignAs').checked) {
					return signMessage();
					// once the message is signed, callback will submit the form
				} else {
					return true;
				}
			}

		} else {
			//alert('DEBUG: no private key, basic submit');
		}
	} else {
		//alert('DEBUG: Test Failed: window.getPrivateKey: ' + !!window.getPrivateKey + '; window.signMessage: ' + !!window.signMessage);
	}

	return true;
}

// == end write.js