// begin translit.js -- substitutes typed characters with different character set

function translateKeyEvent(key, altState, toLayout) {
}

function dvorakKey(e, t) { // replaces pressed qwerty key with dvorak key
	var gt = unescape('%3E');

// called via textarea or input's onkeydown event
// e is event object passed by onkeydown event
// t is the text field's "this"

	//alert('DEBUG: dvorakKey() begins');

	var nl; // new letter

	var key; // pressed key

	if (e.key) {
	// for browsers which return event.key
		//alert('DEBUG: translitKey: e.key is TRUE, and equal to ' + e.key);
		key = e.key;
	} else if (e.keyCode) {
		// older browsers only return event.keyCode
		alert('DEBUG: dvorakKey: e.key is FALSE');

		// magic, not sure if this actually works
		// what browsers is this for?
		key = String.fromCharCode((96 <= e.keyCode && e.keyCode <= 105)? (e.keyCode - 48) : (e.keyCode));
	}
	//alert('DEBUG: key: ' + key);


	// alt+d will toggle dvorak mode
	if (e.altKey || e.ctrlKey || e.metaKey) {
		if (e.key == 'd' || e.key == 'D') {
			if (window.translitKeyState == 1) {
				// 2 is off
				window.translitKeyState = 2;
				t.style.borderTop = '3pt solid gray';
			} else {
				window.translitKeyState = 1;
				t.style.borderTop = '3pt solid green';
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

	if (e.altKey) {
		// alt key combinations
		return true;
	} else {
		// lookup lists, each char in keysEn
		// corresponds to the same position in keysRu

		var keysEn = "abcdefghijklmnopqrstuvwxyz;'\",./ABCDEFGHIJKLMNOPQRSTUVWXYZ<"+gt+"?:[]{}-_=+";
		var keysRu = "axje.uidchtnmbrl'poygk,qf;s-_wvzAXJE"+gt+"UIDCHTNMBRL\"POYGK<QF:WVZS/=?+[{]}";

		if (keysEn.length != keysRu.length) {
			//alert('DEBUG: dvorakKey: Warning: length mismatch keysEn and keysRu');
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
		//alert('DEBUG: translitKey: e.key is FALSE');

		// magic, not sure if this actually works
		// what browsers is this for?
		key = String.fromCharCode((96 <= e.keyCode && e.keyCode <= 105)? (e.keyCode - 48) : (e.keyCode));
	} else if (key.toString && key.toString.length == 1) {
		//should check that it's a string and only 1 char
		key = key.toString;
	}
	//alert('DEBUG: key: ' + key);


	// alt+` will toggle translit mode
	if (e.altKey || e.ctrlKey || e.metaKey) {
		if (e.key == '`' || e.key == 'r' || e.key == 'R') {
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

		// these shortened lookup lists exclude some letters
		// the letter x (cyrillic version) for some reason presents a problem
		// in perl's unicode processing.
		// other letters have been removed just because
		var keysEn =
			"`-=" +
			"~_+" +
			"qwrtyuip[]\\" +
			"QWRTYUIP{}|" +
			"sdfghjkl" +
			"SDFGHJKL" +
			"zcvbnm" +
			"ZCVBNM"
		;

		var keysRu =
			"щьъ" +
			"Щ-=" +
			"яшртыуипюжэ" +
			"ЯШРТЫУИПЮЖЭ" +
			"сдфгчйкл" +
			"СДФГЧЙКЛ" +
			"зцвбнм" +
			"ЗЦВБНМ"
		;

		// var keysEn =
		// 	"`-=" +
		// 	"~_+" +
		// 	"qwertyuiop[]\\" +
		// 	"QWERTYUIOP{}|" +
		// 	"asdfghjkl" +
		// 	"ASDFGHJKL" +
		// 	"zxcvbnm" +
		// 	"ZXCVBNM"
		// ;
		//
		// var keysRu =
		// 	"щьъ" +
		// 	"Щ-=" +
		// 	"яшертыуиопюжэ" +
		// 	"ЯШЕРТЫУИОПЮЖЭ" +
		// 	"асдфгчйкл" +
		// 	"АСДФГЧЙКЛ" +
		// 	"зхцвбнм" +
		// 	"ЗХЦВБНМ"
		// ;

		if (keysEn.length != keysRu.length) {
			//alert('DEBUG: onKeyDown(e) Warning: length mismatch keysEn and keysRu');
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