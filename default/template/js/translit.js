// begin translit.js -- substitutes typed characters with different character set

// translitKeyState
// 0 = off
// 2 = off/passthrough (touched)
// 3 = russian phonetic
// 4 = dvorak
// REMOVED 1 = russian phonetic optimized

function GetDvorakKey(ekey) {
	// lookup lists, each char in keysEn
	// corresponds to the same position in keysRu
	var gt = unescape('%3E');

	var keysQwerty = "abcdefghijklmnopqrstuvwxyz;'\",./ABCDEFGHIJKLMNOPQRSTUVWXYZ<"+gt+"?:[]{}-_=+";
	var keysDvorak = "axje.uidchtnmbrl'poygk,qf;s-_wvzAXJE"+gt+"UIDCHTNMBRL\"POYGK<QF:WVZS/=?+[{]}";

	if (keysQwerty.length != keysDvorak.length) {
		//alert('DEBUG: dvorakKey: warning: length mismatch keysEn and keysRu');
	}

	if (ekey && ekey.length == 1) {
		// if e.key, then try to find it in the lookup list
		for (var i = 0; i < keysQwerty.length; i++) {
			if (ekey == keysQwerty.substr(i, 1)) {
				return keysDvorak.substr(i, 1);
			}
		}
	}

	return '';
} // GetDvorakKey()

function translitKey(e, t) { // replaces pressed qwerty key with russian letter
// called via textarea or input's onkeydown event
// e is event object passed by onkeydown event
// t is the text field's "this"
	//alert('DEBUG: translitKey() begins');
	var nl; // new letter
	var key; // pressed key

	if (e.key) {
		// for browsers which return event.key
		//alert('DEBUG: translitKey: e.key is TRUE, and equal to ' + e.key);
		key = e.key;
	} else if (e.keyCode) {
		// older browsers only return event.keyCode
		//alert('DEBUG: translitKey: e.key is FALSE, but e.keyCode is TRUE');
		// this doesn't work yet becaue there's no way to
		// switch into different modes using this method
		key = String.fromCharCode((96 <= e.keyCode && e.keyCode <= 105)? (e.keyCode - 48) : (e.keyCode));
	} else if (key.toString && key.toString.length == 1) {
		//should check that it's a string and only 1 char
		key = key.toString;
	}
	//alert('DEBUG: key: ' + key);

	if (e.keyCode == 13 && e.ctrlKey) {
		//alert('DEBUG: found ctrl+enter');
		if (t.parentElement) {
			//alert('DEBUG: found t.parentElement');
			var formElement = t.parentElement;
			while (formElement && formElement.parentElement && formElement.nodeName != 'FORM') {
				formElement = formElement.parentElement;
			}
			if (formElement.nodeName == 'FORM') {
				//alert('DEBUG: formElement.nodeName = FORM')
				var inputElements = formElement.getElementsByTagName('input');
				//alert('DEBUG: inputElements.length = ' + inputElements.length);
				if (inputElements.length) {
					var iElement = 0;
					for (iElement = 0; iElement < inputElements.length; iElement++) {
						if (inputElements[iElement].getAttribute('type').toLowerCase() == 'submit') {
							inputElements[iElement].click();
							return '';
						}
					}
				}
			}
		}
	} else {
		//alert('DEBUG: e.keyCode = ' + e.keyCode + '; e.ctrlKey = ' + e.ctrlKey);
	}

	// alt+ ctrl+ meta+` will toggle translit mode
	if (e.altKey || e.ctrlKey || e.metaKey) {
		if (e.key == 'd' || e.key == 'D') {
			// ctrl+d for dvorak
			if (window.translitKeyState == 4) {
				// 2 is off
				window.translitKeyState = 2;
				t.style.borderTop = '3pt solid gray';
			} else {
				window.translitKeyState = 4;
				t.style.borderTop = '3pt solid green';
			}

			// we're doing it, we're overriding the user's keypress
			if (e.preventDefault) {
				e.preventDefault();
			}

//			var asdf = window.frames;
//			var asdf = parent.frames;
			if (window.parent) {
				if (window.parent.frames) {
					var framesRef = window.parent.frames;
					if (framesRef.length) {
						if (framesRef['kbd']) {
							var kDoc = framesRef['kbd'].document;
							if (kDoc.getElementsByTagName) {
								var replaceMode;
								var kbdKeys = kDoc.getElementsByTagName('a');
								if (kbdKeys.length) {
									replaceMode = 1;
								}
								if (!kbdKeys.length) {
									kbdKeys = kDoc.getElementsByTagName('td');
									if (kbdKeys) {
										replaceMode = 1;
									}
								}
								if (!kbdKeys.length) {
									kbdKeys = kDoc.getElementsByTagName('input');
									if (kbdKeys) {
										replaceMode = 2;
									}
								}

								if (kbdKeys && kbdKeys.length) {
									for (kbdKeysI = 0; kbdKeysI < kbdKeys.length; kbdKeysI++) {
										if (!kbdKeys[kbdKeysI].getAttribute('origIH')) {
											kbdKeys[kbdKeysI].setAttribute('origIH', kbdKeys[kbdKeysI].innerHTML);
										}
										if (window.translitKeyState == 4) {
											var orig = kbdKeys[kbdKeysI].getAttribute('origIH').trim();
											var nlTemp = GetDvorakKey(kbdKeys[kbdKeysI].getAttribute('origIH').trim());
											if (nlTemp.length) {
												var nlCaption = orig.replace(orig.trim(), nlTemp);
												kbdKeys[kbdKeysI].innerHTML = nlCaption.toUpperCase();
											}
										} else {
											kbdKeys[kbdKeysI].innerHTML = kbdKeys[kbdKeysI].getAttribute('origIH');
										}
									}
								}
							}
						}
					}
				}
			}

			return false;
		}
		
		if (e.key == '`' || e.key == 'r' || e.key == 'R') {
			// ctrl+r or ctrl+` for russian
			if (window.translitKeyState == 1) {
				// 2 is off
				window.translitKeyState = 2;
				t.style.borderTop = '3pt solid blue';
			} else {
				window.translitKeyState = 1;
				t.style.borderTop = '3pt solid red';
			}

			// we're doing it, we're overriding the user's keypress
			if (e.preventDefault) {
				e.preventDefault();
			}

			return false;
		} else {
			if (e.ctrlKey || e.metaKey) {
				return true;
			}
		}
	}

	// end toggle handler

	// check for toggle status.
	// 2 is off
	if (!window.translitKeyState) {
		window.translitKeyState = 2;
	}
	if (window.translitKeyState == 2) {
		return true;
	}

	if (translitKeyState == 1) {
		if (e.altKey) {
			// alt key combinations

			if (e.key == 'e') {
				nl = "ё";
			} else if (e.key == 'E') {
				nl = 'Ё';
			} else if (e.key == '-' || e.key == '_' || e.key == '=' || e.key == '+') {
				nl = e.key;
			} else {
				return true;
			}
		} else {
			// lookup lists, each char in keysEn
			// corresponds to the same position in keysRu
			var keysEn =
				"`-=" +
				"~_+" +
				"qwertyuiop[]\\" +
				"QWERTYUIOP{}|" +
				"asdfghjkl" +
				"ASDFGHJKL" +
				"zxcvbnm" +
				"ZXCVBNM"
			;

			var keysRu =
				"щьъ" +
				"Щ-=" +
				"яшертыуиопюжэ" +
				"ЯШЕРТЫУИОПЮЖЭ" +
				"асдфгчйкл" +
				"АСДФГЧЙКЛ" +
				"зхцвбнм" +
				"ЗХЦВБНМ"
			;

			if (keysEn.length != keysRu.length) {
				//alert('DEBUG: onKeyDown(e) Warning: length mismatch keysEn ' + keysEn.length + ' and keysRu ' + keysRu.length);
				//alert('DEBUG: keysEn = ' + keysEn);
				//alert('DEBUG: keysRu = ' + keysRu);
			}

			if (e.key) {
				// if e.key, then try to find it in the lookup list
				for (var i = 0; i < keysEn.length; i++) {
					if (e.key == keysEn.substr(i, 1)) {
						//alert('DEBUG: i = ' + i + ' keysEn.substr(i, 1): ' + keysEn.substr(i, 1) + ' ; keysRu.substr(i, 1): ' + keysRu.substr(i, 1));
						nl = keysRu.substr(i, 1);
						break;
					}
				}
			}
		}
	} // if (translitKeyState == 1)

	if (translitKeyState == 4) {
		// dvorak
		if (e.altKey) {
			// alt key combinations
			return true;
		} else {
			var nlTemp = GetDvorakKey(e.key);
			if (nlTemp.length) {
				nl = nlTemp;
			}
		}
	} // if (translitKeyState == 4) (dvorak)

	if (!nl) {
		// new letter was never changed from empty state,
		// which is not part of the possible outputs,
		// so we do not need to replace the input.
		return true;
	}

	// we're doing it, we're overriding the user's keypress
	if (e.preventDefault) {
		e.preventDefault();
	}

	//alert('DEBUG: e.preventDefault() was called');
	var txt = t;

	// this block of code may still come in handy.
	// it finds the textbox by element id instead of using the one passed into the function
	//    if (!txt) {
	//        if (document.getElementById) {
	//            var txt = document.getElementById('txtTranslit');
	//        } else {
	//            if (document.forms) {
	//                var form = document.forms['frmTest'];
	//                if (form) {
	//                    txt = form.txtTranslit;
	//                }
	//            }
	//        }
	//    }

	if (txt) {
		// append the text to the textbox
		// dont bother with looking for pointer location or selection
		txt.value = txt.value + nl;
		//replaceSelectedText(txt, nl);
	} else {
		//alert('DEBUG: no text field');
	}

	return false;
}

/////////////////////////////
// below code is not in use and doesn't work
//////////////////////////////

//
//function getInputSelection(el) {
//    var start = 0, end = 0, normalizedValue, range,
//        textInputRange, len, endRange;
//
//    if (typeof el.selectionStart == "number" && typeof el.selectionEnd == "number") {
//        start = el.selectionStart;
//        end = el.selectionEnd;
//    } else {
//        range = document.selection.createRange();
//
//        if (range && range.parentElement() == el) {
//            len = el.value.length;
//            normalizedValue = el.value.replace('/\r\n/g', "\n");
//
//            // Create a working TextRange that lives only in the input
//            textInputRange = el.createTextRange();
//            textInputRange.moveToBookmark(range.getBookmark());
//
//            // Check if the start and end of the selection are at the very end
//            // of the input, since moveStart/moveEnd doesn't return what we want
//            // in those cases
//            endRange = el.createTextRange();
//            endRange.collapse(false);
//
//            if (-1 < textInputRange.compareEndPoints("StartToEnd", endRange)) {
//                start = end = len;
//            } else {
//                start = -textInputRange.moveStart("character", -len);
//                start += normalizedValue.slice(0, start).split("\n").length - 1;
//
//                if (-1 < textInputRange.compareEndPoints("EndToEnd", endRange)) {
//                    end = len;
//                } else {
//                    end = -textInputRange.moveEnd("character", -len);
//                    end += normalizedValue.slice(0, end).split("\n").length - 1;
//                }
//            }
//        }
//    }
//}
//
//function replaceSelectedText(el, text) {
//    var sel = getInputSelection(el), val = el.value;
//    el.value = val.slice(0, sel.start) + text + val.slice(sel.end);
//}


// end translit.js