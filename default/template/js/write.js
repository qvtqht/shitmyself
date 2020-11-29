// == begin write.js

function WriteOnload () { // onload handler for write page
	//alert('DEBUG: WriteOnload() begin');

	if (document.getElementById) {
	    //alert('DEBUG: WriteOnload: document.getElementById is true');

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

        if (privKey) {
            //alert('DEBUG: privKey was true, adding options...');

			if (document.getElementById('spanSignAs')) {
				var gt = unescape('%3E');
				if (window.getAvatar) {
					var spanSignAs = document.getElementById('spanSignAs');
//					if (!GetPrefs('sign_by_default')) {
//						var btnSignAs = document.createElement('input');
//						btnSignAs.setAttribute('onclick', 'if(window.signMessage){signMessage();}this.value="Meditate...";');
//						btnSignAs.setAttribute('type', 'submit');
//						btnSignAs.setAttribute('value', 'Sign as ' + getAvatar());
//						//btnSignAs.innerHTML = 'Sign as ' + getAvatar(); // use this if it is a GTbuttonLT
//						spanSignAs.appendChild(btnSignAs);
//
//					}
//					else { // this is for the sign yes/no checkbox
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
//					}

					if (window.solvePuzzle) {
						var spanWriteAdvanced = document.getElementById('spanWriteAdvanced');
						if (spanWriteAdvanced) {
							var btnSolvePuzzle = document.createElement('input');
							btnSolvePuzzle.setAttribute('id', 'btnSolvePuzzle');
							btnSolvePuzzle.setAttribute('type', 'button');
							btnSolvePuzzle.setAttribute('value', 'Solve Puzzle');
							btnSolvePuzzle.setAttribute('onclick',	"if (window.solvePuzzle) { return solvePuzzle(this); } else { return true; }");
							spanWriteAdvanced.appendChild(btnSolvePuzzle);

							var br = document.createElement('br');
							spanWriteAdvanced.appendChild(br);

							var lblSolvePuzzle = document.createElement('span');
							lblSolvePuzzle.setAttribute('class', 'beginner');
							var gt = unescape('%3E');
							lblSolvePuzzle.innerHTML = 'Establish trust, takes time.';
							spanWriteAdvanced.appendChild(lblSolvePuzzle);
						}
					} // window.solvePuzzle
				} // window.getAvatar
			} // document.getElementById('spanSignAs')

			if (0) {
				// config/admin/js/write_more_link
				var pMoreLink = document.getElementById('pMoreLink');
				if (pMoreLink) {
					var aMore = document.createElement('a');
					aMore.setAttribute('href', '#');
					aMore.setAttribute(
						'onclick',
						'if (window.ShowAll) { ShowAll(this, this.parentElement.parentElement); this.parentElement.remove(); }'
					);
					aMore.innerHTML = 'More';
					pMoreLink.appendChild(aMore);
				}
			}
//
//			if (document.getElementById('addtext')) {
//				document.getElementById('addtext').value = 'Sign Message and Send';
//			}

        }

        if (pubKey) {
            //alert('DEBUG: pubKey was true, calling PubKeyPing()');
            if (window.PubKeyPing) {
            	PubKeyPing();
            }
        }

        if (window.location.hash) {
            //alert('DEBUG: window.location.hash = ' + window.location.hash);
            if (window.location.hash == '#inspubkey') {
                //alert('DEBUG: #inspubkey found');
				if (pubKey) {
					//alert('DEBUG: pubKey is true, inserting it into comment');
					var comment = document.getElementById('comment'); // #todo no-gebi compat
					if (comment) {
						comment.value = pubKey;
					}
                } else {
                    //alert('DEBUG: pubKey was false, this is unexpected. Giving up.');
                }
            }
        }
    } else {
        //alert('DEBUG: WriteOnload: document.getElementById was FALSE');
    }

    return true;
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
				var chkSignAs = document.getElementById('chkSignAs');
				if (!chkSignAs || (chkSignAs && chkSignAs.checked)) {
					if (window.signMessage) {
						var signMessageResult = signMessage();
						if (!signMessageResult) {
							signMessageResult = 0;
						}
						// once the message is signed, callback will submit the form
					}
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

	window.eventLoopFresh = 0; // disables fresh.js. may not be a wise move here.

	return true;
}

// == end write.js
