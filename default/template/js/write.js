// == begin write.js

function WriteOnload () { // onload handler for write page
	//alert('DEBUG: WriteOnload() begin');

	if (document.getElementById) {
	    //alert('DEBUG: WriteOnload: document.getElementById is true');
        if (window.GetPrefs) {
			//alert('DEBUG: window.GetPrefs = TRUE');
        	if (GetPrefs('enhance_write')) {
				//alert('DEBUG: enhance_write = TRUE');
				var comment = document.getElementById('comment');
				if (comment) {
					if (window.location.href.indexOf('write') != -1) {
						CommentMakeWp(comment);
					} else {
						comment.setAttribute('onfocus', 'CommentMakeWp(this)');
					}
				}
			} else {
				//alert('DEBUG: enhance_write = FALSE');
			}
		} else {
			//alert('DEBUG: window.GetPrefs = FALSE');
		}
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
					var comment = document.getElementById('comment');
					if (comment) {
						comment.value = pubKey;
					}
                } else {
                    //alert('DEBUG: pubKey was false, this is unexpected. Giving up.');
                }
            }
        }
    } // document.getElementById
    else {
        //alert('DEBUG: WriteOnload: document.getElementById was FALSE');
    }

    return true;
}

function CommentMakeWp(comment) { // makes editor textarea larger and gives it wp color scheme
// called when enhance_write is on
	if (!comment) {
		// #todo more sanity checks here
		return;
	}
	comment.style.backgroundColor = '#000080';
	comment.style.color = 'ffffff';
	comment.style.width = '95%';
	comment.style.height = '50%';
	comment.style.padding = '1em';
	comment.setAttribute('cols', 80);
	comment.setAttribute('rows', 24);
} // CommentMakeWp()

function writeSubmit (t) { // called when user submits write form
	//alert('DEBUG: writeSubmit() begin');

	if (window.localStorage) {
		//alert('DEBUG: window.localStorage');
		if (window.ClearAutoSave) {
			ClearAutoSave();
		}
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
					// if there's a "sign as" checkbox, it should be checked
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
} // writeSubmit()

function DoAutoSave() {
	var initDone = window.autoSaveInitDone;
	if (!initDone) {
		window.autoSaveInitDone = 1;

		var ls = window.localStorage;
		var storedValue = ls.getItem('autosave');

		if (storedValue) {
			var comment = document.getElementById('comment');
			if (comment) {
				comment.value += storedValue;
			}
		}

		return 0;
	}

	if (document.getElementById) {
		//alert('DEBUG: DoAutoSave: document.getElementById is true');

		if (window.GetPrefs) {
			//alert('DEBUG: DoAutoSave: window.GetPrefs = TRUE');

			if (GetPrefs('enhance_write')) {
				//alert('DEBUG: DoAutoSave: enhance_write = TRUE');

				var comment = document.getElementById('comment');
				if (comment) {
					if (window.localStorage) {
						var ls = window.localStorage;
						ls.setItem('autosave', comment.value);
					}
				}
			} else {
				//alert('DEBUG: enhance_write = FALSE');
			}
		} else {
			//alert('DEBUG: window.GetPrefs = FALSE');
		}
	}
}

function ClearAutoSave () {
	var ls = window.localStorage;
	if (ls) {
		window.eventLoopDoAutoSave = 0;
		ls.removeItem('autosave');
	}
} // ClearAutoSave()

window.eventLoopDoAutoSave = 1;

// == end write.js
