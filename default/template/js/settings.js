// == begin settings.js

var showAdvancedLastAction = '';
var showBeginnerLastAction = '';
var showMeaniesLastAction = '';
var showAdminLastAction = '';

var timerShowAdvanced;

function SetElementVisible (element, displayValue, bgColor, borderStyle) { // sets element's visible status based on tag type
// displayValue = 'none' or 'initial'
// 	when 'initial', will try to substitute appropriate default for tag type
// also sets background color
// used for hiding/showing and highlighting beginner, advanced element classes on page.

    //alert ('DEBUG: \nelement:' + element + "\ndisplayValue:" + displayValue + "\nbgColor:" + bgColor + "\nborderStyle:" + borderStyle + "\n");

	if (bgColor) {
		// background color
		if (bgColor == 'initial') {
			bgColor = '$colorWindow';
		}
		element.style.backgroundColor = bgColor;
		// #todo this may cause issues in some themes
	}

	// depending on element type, we set different display style
	// block, table-row, table-cell, or default of 'initial'
	if (displayValue == 'initial' && (element.nodeName == 'P' || element.nodeName == 'H3' || element.nodeName == 'FIELDSET' || element.nodeName == 'HR')) {
		element.style.display = 'block';
	} else if (displayValue == 'initial' && element.nodeName == 'TR') {
		element.style.display = 'table-row';
	} else if (displayValue == 'initial' && (element.nodeName == 'TH' || element.nodeName == 'TD')) {
		if (element.innerHTML != '') {
			element.style.display = 'table-cell';
		} else {
			element.style.display = 'none'; // empty table cells display = none #todo explain why?
		}
	} else {
		if (displayValue == 'initial') {
			displayValue = 'inline';
		}
		element.style.display = displayValue;
		if (borderStyle) {
			// border style
			element.style.border = borderStyle;
			element.style.borderRadius = '3pt';
		}
	}

	return 1;
} // SetElementVisible()

function ShowAll (t, container) { // shows all elements, overriding settings
// admin elements are excluded. only beginner, advanced class elements are shown

	if (!container) {
		container = document;
	}

	var isMore = 1;
	if (t.innerHTML == 'Less') {
		t.innerHTML = 'More';
		isMore = 0;
	}
	if (t.innerHTML == 'Less (<u>O</u>)') {
		t.innerHTML = 'M<u>o</u>re';
		isMore = 0;
	}

    if (isMore && container.getElementsByClassName) {
		if (t.innerHTML == 'More') {
			t.innerHTML = 'Less';
		}
		if (t.innerHTML == 'M<u>o</u>re') {
			t.innerHTML = 'Less (<u>O</u>)';
		}

        var display;
        display = 'initial';

        var elements = container.getElementsByClassName('advanced');
        for (var i = 0; i < elements.length; i++) {
            SetElementVisible(elements[i], display, '$colorHighlightAdvanced', 0);
        }
        elements = container.getElementsByClassName('beginner');
        for (var i = 0; i < elements.length; i++) {
            SetElementVisible(elements[i], display, '$colorHighlightBeginner', 0);
        }
        elements = container.getElementsByClassName('expand');
        for (var i = 0; i < elements.length; i++) {
            SetElementVisible(elements[i], 'none', '', 0);
        }

        if (timerShowAdvanced) {
            clearTimeout(timerShowAdvanced);
        }
//        timerShowAdvanced = setTimeout('ShowAdvanced(1);', 10000);
//
//		if (t && t.getAttribute('onclick')) {
//			t.setAttribute('onclick', '');
//		}

        return false;
    } else {
    	ShowAdvanced(1);

    	return false;
	}

    return true;
} // ShowAll()

function ShowAdvanced (force, container) { // show or hide controls based on preferences
//handles class=advanced based on 'show_advanced' preference
//handles class=beginner based on 'beginner' preference
//handles class=tag-abuse based on 'show_meanies' preference
//force parameter
// 1 = does not re-do setTimeout (called this way from checkboxes)
// 0 = previous preference values are remembered, and are not re-done (called by timer)

	//alert('DEBUG: ShowAdvanced(' + force + ')');

	if (!container) {
		container = document;
	}

	if (window.localStorage && container.getElementsByClassName) {
		//alert('DEBUG: ShowAdvanced: feature check passed!');
		///////////

		var displayMeanies = 'none'; // no voting controls by default
		if (GetPrefs('show_meanies') == 1) {
		    // check value of show_meanies preference
			displayMeanies = 'initial'; // display
		}

		if (force || showMeaniesLastAction != displayMeanies) {
			var elemMeanies = container.getElementsByClassName('item-abuse');

			for (var i = 0; i < elemMeanies.length; i++) {
				SetElementVisible(elemMeanies[i], displayMeanies, 0, 0);
			}
			showMeaniesLastAction = displayMeanies;
		}

		///////////

		var displayAdmin = 'none'; // not voting by default
		if (GetPrefs('show_admin') == 1) { // check value of show_admin preference
			displayAdmin = 'initial'; // display
		}

		if (force || showAdminLastAction != displayAdmin) {
			var elemAdmin = container.getElementsByClassName('admin');

			for (var i = 0; i < elemAdmin.length; i++) {
				SetElementVisible(elemAdmin[i], displayAdmin, 0, 0);
			}
		}

		var displayValue = 'none'; // hide by default
		if (GetPrefs('show_advanced') == 1) { // check value of show_advanced preference
			displayValue = 'initial'; // display
		}

		var bgColor = 'initial';
		if (GetPrefs('advanced_highlight') == 1) { // check value of advanced_highlight preference
			bgColor = '$colorHighlightAdvanced'; // advanced_highlight
		}

		if (force || showAdvancedLastAction != (displayValue + bgColor)) {
			// thank you stackoverflow
			var divsToHide = container.getElementsByClassName("advanced"); //divsToHide is an array #todo nn3 compat
			for (var i = 0; i < divsToHide.length; i++) {
				//divsToHide[i].style.visibility = "hidden"; // or
				SetElementVisible(divsToHide[i], displayValue, bgColor, 0);
			}
//			var clock = document.getElementById('txtClock');
//			if (clock) {
//			    SetElementVisible(clock, displayValue, bgColor, 0);
//			}
			showAdvancedLastAction = displayValue + bgColor;
		}

		displayValue = 'initial'; // show by default
		if (GetPrefs('beginner') == 0) { // check value of beginner preference
			displayValue = 'none';
		}

		bgColor = 'initial';
		if (GetPrefs('beginner_highlight') == 1) { // check value of beginner preference
			bgColor = '$colorHighlightBeginner'; // beginner_highlight
		}

		if (force || showBeginnerLastAction != displayValue + bgColor) {
			var divsToShow = container.getElementsByClassName('beginner');//#todo nn3 compat

			for (var i = 0; i < divsToShow.length; i++) {
				SetElementVisible(divsToShow[i], displayValue, bgColor, 0);
			}
			showBeginnerLastAction = displayValue + bgColor;
		}
//
//		if (window.freshTimeoutId) {
//			// reset the page change notifier state
//			clearTimeout(window.freshTimeoutId);
//
//			if (GetPrefs('notify_on_change')) {
//				// check if page has changed, notify user if so
//				if (window.EventLoop) {
//					EventLoop();
//				}
//			}
//		}

		if (window.setAva) {
			setAva(); // #todo caching similar to above
		}

		//if (!force) {
			//if (timerShowAdvanced) {
			//	clearTimeout(timerShowAdvanced);
			//}
			//timerShowAdvanced = setTimeout('ShowAdvanced()', 3000);
		//}

		//SettingsOnload();

	} else {
		//alert('DEBUG: ShowAdvanced: feature check FAILED!');
		//alert('DEBUG: window.localStorage: ' + window.localStorage + '; document.getElementsByClassName: ' + document.getElementsByClassName);
	}

	//alert('DEBUG: ShowAdvanced: returning false');
	return false;
} // ShowAdvanced()

function GetPrefs (prefKey) { // get prefs value from localstorage
	//alert('debug: GetPrefs(' + prefKey + ')');
	if (window.localStorage) {
		var nameContainer = 'settings';
		{ // settings beginning with gtgt go into separate container
			var gt = unescape('%3E');
			if (prefKey.substr(0, 2) == gt+gt) {
				nameContainer = 'voted';
			}
		}
		var currentPrefs = localStorage.getItem(nameContainer);

		var prefsObj;
		if (currentPrefs) {
			prefsObj = JSON.parse(currentPrefs);
		} else {
			prefsObj = Object();
		}
		var prefValue = prefsObj[prefKey];

		if (!prefValue && prefValue != 0) {
			// these settings default to 1/true:
			if (
				prefKey == 'beginner' ||
				prefKey == 'beginner_highlight' ||
				prefKey == 'notify_on_change'
			) {
				prefValue = 1;
			}
		}

		return prefValue;
	}

	//alert('debug: GetPrefs: fallthrough, returning false');
	return false;
} // GetPrefs()

function SetPrefs (prefKey, prefValue) { // set prefs key prefKey to value prefValue
    //alert('DEBUG: SetPrefs(' + prefKey + ', ' + prefValue + ')');

	if (prefKey == 'show_advanced') {
		if (window.SetCookie) {
			SetCookie('show_advanced', prefValue);
		}
	}

	if (window.localStorage) {
		var nameContainer = 'settings';
		var gt = unescape('%3E');
		if (prefKey.substr(0, 2) == gt+gt) {
			nameContainer = 'voted';
		}

		var currentPrefs = localStorage.getItem(nameContainer);
		var prefsObj;
		if (currentPrefs) {
			prefsObj = JSON.parse(currentPrefs);
		} else {
			prefsObj = Object();
		}
		prefsObj[prefKey] = prefValue;

		var newPrefsString = JSON.stringify(prefsObj);
		localStorage.setItem(nameContainer, newPrefsString);
		return 0;
	}

	return 1;
}

function SaveCheckbox (ths, prefKey) { // saves value of checkbox, toggles affected elements
// id = id of pane to hide or show; not required
// ths = "this" of calling checkbox)
// prefKey = key of preference value to set with checkbox
//
// this function is a bit of a mess, could use a refactor #todo

	//alert('DEBUG: SaveCheckbox(' + ths + ',' + prefKey);

	var checkboxState = (ths.checked ? 1 : 0);
	//alert('DEBUG: checkboxState = ' + checkboxState);

	// saves checkbox's value as 0/1 value to prefs(prefKey)
	SetPrefs(prefKey, (ths.checked ? 1 : 0));

	//alert('DEBUG: after SetPrefs, GetPrefs(' + prefKey + ') returns: ' + GetPrefs(prefKey));

	// call ShowAdvanced(1) to update ui appearance
	ShowAdvanced(1);

	return 1;
}

function SetInterfaceMode (ab) { // updates several settings to change to "ui mode" (beginner, advanced, etc.)
    //alert('DEBUG: SetInterfaceMode(' + ab + ')');

	if (window.localStorage && window.SetPrefs) {
		if (ab == 'beginner') {
			SetPrefs('show_advanced', 0);
			SetPrefs('advanced_highlight', 0);
			SetPrefs('beginner', 1);
			SetPrefs('beginner_highlight', 1);
			SetPrefs('notify_on_change', 1);
			SetPrefs('show_admin', 0);
			SetPrefs('show_meanies', 0);
//			SetPrefs('sign_by_default', 1);
		} else if (ab == 'intermediate') {
			SetPrefs('show_advanced', 1);
			SetPrefs('advanced_highlight', 1);
			SetPrefs('beginner', 1);
			SetPrefs('beginner_highlight', 1);
			SetPrefs('notify_on_change', 1);
//            SetPrefs('show_admin', 0);
		} else if (ab == 'expert') {
			SetPrefs('show_advanced', 1);
			SetPrefs('advanced_highlight', 0);
			SetPrefs('beginner', 0);
			SetPrefs('beginner_highlight', 0);
			SetPrefs('notify_on_change', 1);
//            SetPrefs('show_admin', 0);
// 		} else if (ab == 'minimal') {
// 			SetPrefs('show_advanced', 0);
// 			SetPrefs('advanced_highlight', 0);
// 			SetPrefs('beginner', 0);
// 			SetPrefs('beginner_highlight', 0);
// 			SetPrefs('notify_on_change', 0);
// //            SetPrefs('show_admin', 0);
// 		} else if (ab == 'operator') {
//             SetPrefs('show_admin', 1);
//             SetPrefs('show_meanies', 1);
		}

		ShowAdvanced(1);

        //alert('DEBUG: window.SetPrefs was found, and ShowAdvanced(1) was called');

		return false;
	}

	//alert('DEBUG: returning true');

	return true;
}


function LoadCheckbox (c, prefKey) { // updates checkbox state to reflect settings
// c = checkbox
// prefKey = key of preference value
//
	//alert('DEBUG: LoadCheckbox(' + c + ',' + prefKey);
	var checkboxState = GetPrefs(prefKey);
	//alert('DEBUG: checkboxState = ' + checkboxState);

	if (c && c.checked != (checkboxState ? 1 : 0)) {
		c.checked = (checkboxState ? 1 : 0);
	}

	return 1;
}


function SettingsOnload () { // onload function for settings page
	//alert('debug: SettingsOnload() begin');

	if (document.getElementById) {
	// below is code which sets the checked state of settings checkboxes
	// based on settings state
		var pane;

		//LoadCheckbox(document.getElementById('chkShowMeanies'), 'show_meanies');
		//LoadCheckbox(document.getElementById('chkSignByDefault'), 'sign_by_default');
		LoadCheckbox(document.getElementById('chkShowAdmin'), 'show_admin');

		//if (GetPrefs('sign_by_default') == 1) {
		//	var cbM = document.getElementById('chkSignByDefault');
		//	if (cbM) {
		//		cbM.checked = 1;
		//	}
		//}

		if (GetPrefs('show_admin') == 1) {
			var cbM = document.getElementById('chkShowAdmin');
			if (cbM) {
				cbM.checked = 1;
			}
		}
	}

	//alert('debug: SettingsOnload: returning false');
	return false;
} // SettingsOnload()

if (window.EventLoop) {
	window.eventLoopShowAdvanced = 1;
} else {
	ShowAdvanced();
}

// == end settings.js