// == begin utils.js

// begin html escape hack (credit stacko)
// only works with createElement #backlog
if (document.createElement) {
	var escapeTA = document.createElement('textarea');
}
function escapeHTML(html) {
	if (window.escapeTA) {
		escapeTA.textContent = html;
		return escapeTA.innerHTML;
	}
}
function unescapeHTML(html) {
	if (window.escapeTA) {
		escapeTA.innerHTML = html;
		return escapeTA.textContent;
	}
}
// end html escape hack

function OnLoadEverything () { // checks for each onLoad function and calls it
// keywords: OnLoadAll BodyOnLoad body onload body.onload
// typically called from body.onload
	//alert('DEBUG: OnLoadEverything() begins');

	if (window.setClock) {
		//alert('DEBUG: OnLoadEverything: setClock()');
		window.eventLoopSetClock = 1;
		setClock();
	}
	if (window.ItsYou) {
		//alert('DEBUG: OnLoadEverything: ItsYou()');
		ItsYou();
	}
	if (window.ShowTimestamps) {
		//alert('DEBUG: OnLoadEverything: ShowTimestamps()');
		window.eventLoopShowTimestamps = 1;
	}
	if (window.SettingsOnload) {
		//alert('DEBUG: OnLoadEverything: SettingsOnload()');
		SettingsOnload();
	}
	if (window.ProfileOnLoad) {
		//alert('DEBUG: OnLoadEverything: ProfileOnLoad()');
		ProfileOnLoad();
	}
	if (window.WriteOnload) {
		//alert('DEBUG: OnLoadEverything: WriteOnload()');
		WriteOnload();
	}
	if (window.ShowAdvanced) {
		//alert('DEBUG: OnLoadEverything: ShowAdvanced()');
		window.eventLoopShowAdvanced = 1;
		ShowAdvanced(0);
	}
	if (window.SearchOnload) {
		//alert('DEBUG: OnLoadEverything: SearchOnload()');
		SearchOnload();
	}
	if (window.UploadAddImagePreviewElement) {
		//alert('DEBUG: OnLoadEverything: UploadAddImagePreviewElement()');
		UploadAddImagePreviewElement();
	}
	if (
		(
			window.location.href &&
			window.location.href.indexOf('write') != -1 ||
			window.location.hash.indexOf('reply') != -1
		) &&
		document.compose &&
		document.compose.comment &&
		document.compose.comment.focus
	) {
		//alert('DEBUG: OnLoadEverything: document.compose.comment.focus()()');
		document.compose.comment.focus();
	}
	if (window.location.href && (window.location.href.indexOf('search') != -1) && document.search.q) {
		//alert('DEBUG: OnLoadEverything: document.search.q.focus()');
		document.search.q.focus();
	}
	if (window.DraggingInit && GetPrefs('draggable')) {
		//alert('DEBUG: OnLoadEverything: DraggingInit()');
		if (window.location.href.indexOf('desktop') != -1) {
			DraggingInit(1);
		} else {
			DraggingInit(0);
		}
	}
	if (window.EventLoop) {
		//alert('DEBUG: OnLoadEverything: EventLoop()');
		if (window.CheckIfFresh) {
			window.eventLoopFresh = 1;
		}
		window.eventLoopEnabled = 1
		EventLoop();
	}
	if (window.HideLoadingIndicator) {
		//alert('DEBUG: OnLoadEverything: HideLoadingIndicator()');
		HideLoadingIndicator();
	}

	// everything is set now, start event loop
	//
} // OnLoadEverything()

function EventLoop () { // for calling things which need to happen on a regular basis
// sets another timeout for itself when done
// replaces several independent timeouts
// #backlog add secondary EventLoopWatcher timer which ensures this one runs when needed
	//alert('debug: EventLoop');
	var d = new Date();
	var eventLoopBegin = d.getTime();

	if (window.flagUnloaded) {
		document.title = 'Meditate...';
		//document.body.style.opacity="0.8";

		var ariaAlert;
		ariaAlert = document.getElementById('ariaAlert');
		if (!ariaAlert) {
			ariaAlert = document.createElement('p');
			ariaAlert.setAttribute('role', 'alert');
			ariaAlert.setAttribute('id', 'ariaAlert');
			ariaAlert.innerHTML = 'Meditate...';
			ariaAlert.style.opacity = '1';
			ariaAlert.style.zIndex = '1';

			//document.body.appendChild(ariaAlert);
			document.body.insertBefore(ariaAlert, document.body.firstChild);
		}
	}

	//return;
	// uncomment to disable event loop
	// makes js debugging easier

	if (window.eventLoopShowTimestamps && window.ShowTimestamps) {
		if (13000 < (eventLoopBegin - window.eventLoopShowTimestamps)) {
			ShowTimestamps();
			window.eventLoopShowTimestamps = eventLoopBegin;
		} else {
			// do nothing
		}
	}

	if (window.eventLoopDoAutoSave && window.DoAutoSave) {
		if (5000 < (eventLoopBegin - window.eventLoopDoAutoSave)) { // autosave interval
			DoAutoSave();
			window.eventLoopDoAutoSave = eventLoopBegin;
		} else {
			// do nothing
		}
	}

	if (window.eventLoopSetClock && window.setClock) {
		setClock();
	}

	if (window.eventLoopShowAdvanced && window.ShowAdvanced) {
		ShowAdvanced();
	}

	if (window.eventLoopFresh && window.CheckIfFresh) {
		//window.eventLoopFresh = eventLoopBegin;
		if (GetPrefs('notify_on_change')) {
			CheckIfFresh();
		}
	}

	if (window.eventLoopEnabled) {
		var d = new Date();
		var eventLoopEnd = d.getTime();
		var eventLoopDuration = eventLoopEnd - eventLoopBegin;
		//document.title = eventLoopDuration; // for debugging performance

		if (window.timeoutEventLoop) {
			clearTimeout(window.timeoutEventLoop);
		}

		if (100 < eventLoopDuration) {
			// if loop went longer than 100ms, run every 3 seconds or more
			eventLoopDuration = eventLoopDuration * 30;
		} else {
			// otherwise run every 1 second
			eventLoopDuration = 1000;
		}
		//document.title = eventLoopDuration; // for debugging performance

		window.timeoutEventLoop = setTimeout('EventLoop()', eventLoopDuration);
	}
} // EventLoop()

function UrlExists(url) { // checks if url exists
// todo use async
// todo how to do pre-xhr browsers?
    //alert('DEBUG: UrlExists(' + url + ')');

	if (window.XMLHttpRequest) {
	    //alert('DEBUG: UrlExists: window.XMLHttpRequest check passed');

		var http = new XMLHttpRequest();
		http.open('HEAD', url, false);
		//http.timeout = 5000; //#xhr.timeout
		http.send();
		var httpStatusReturned = http.status;

		//alert('DEBUG: UrlExists: httpStatusReturned = ' + httpStatusReturned);

		return (httpStatusReturned == 200);
	}
}
//
//function UrlExists2(url, callback) { // checks if url exists
//// todo use async and callback
//// todo how to do pre-xhr browsers?
//    //alert('DEBUG: UrlExists(' + url + ')');
//
//	if (window.XMLHttpRequest) {
//	    //alert('DEBUG: UrlExists: window.XMLHttpRequest check passed');
//
//        var xhttp = new XMLHttpRequest();
//        xhttp.onreadystatechange = function() {
//    if (this.readyState == 4 && this.status == 200) {
//       // Typical action to be performed when the document is ready:
//       document.getElementById("demo").innerHTML = xhttp.responseText;
//    }
//};
//xhttp.open("GET", "filename", true);
//xhttp.send();
//
//
//
//		var http = new XMLHttpRequest();
//		http.open('HEAD', url, false);
//		http.send();
//		var httpStatusReturned = http.status;
//
//		//alert('DEBUG: UrlExists: httpStatusReturned = ' + httpStatusReturned);
//
//		return (httpStatusReturned == 200);
//	}
//}

function DisplayStatus(status) {
	if (document.getElementById) {
		var statusBar = document.getElementById('status');

	}
}

function DownloadAsTxt(filename, text) {
    var element = document.createElement('a');

    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
    element.setAttribute('download', filename);

    element.style.display = 'none';
    document.body.appendChild(element);

    element.click();

    document.body.removeChild(element);
}


function displayNotification (strMessage, thisButton) { // adds notificatin to page
// used for loading indicator bar (to top of page, depending on style)
// also used for "creating profile" and "already voted" notifications
	var spanNotification = document.createElement('span');
	spanNotification.setAttribute('class', 'notification');
	spanNotification.setAttribute('role', 'alert');
	spanNotification.setAttribute('onclick', 'if (this.remove) { this.remove() } return false;');
	spanNotification.innerHTML = strMessage;

	if (thisButton) {
		thisButton.parentNode.appendChild(spanNotification);
		thisButton.after(spanNotification);
	} else {
		document.body.appendChild(spanNotification);
	}
} // displayNotification()

function newA (href, target, innerHTML, parent) { // makes new a element and appends to parent
	var newLink = document.createElement('a');
	if (href) { newLink.setAttribute('href', href); }
	if (target) { newLink.setAttribute('target', target); }
	if (innerHTML) { innernewLink.setAttribute('innerHTML', innerHTML); }
	parent.appendChild(newLink);
	return newLink;
}

function CollapseWin (t) { // collapses or expands window based on t's caption
// t is presumed to be clicked element's this, but can be any other element
// if t's caption is 'v', window is re-expanded
// if 'x' (or anything else) collapses window
// this is done by navigating up until a table is reached
// and then hiding the first class=content element within
// presumably a TR but doesn't matter really because SetElementVisible() is used
// pretty basic, but it works.
	if (t.innerHTML) {
		if (t.firstChild.nodeName == 'FONT') {
			// small hack in case link has a font tag inside
			// the font tag is typically used to style the link a different color for older browsers
			t = t.firstChild;
		}
		var newVisible = 'initial';
		if (t.innerHTML == '}-{') { //#collapseButton
			t.innerHTML = '{-}'; // //#collapseButton
		} else {
			t.innerHTML = '}-{'; //#collapseButton
			newVisible = 'none';
		}
		if (t.parentElement) {
			var p = t;
			while (p.nodeName != 'TABLE') {
				p = p.parentElement;
				if (p.getElementsByClassName) {
					var content = p.getElementsByClassName('content');
					if (content.length) {
						SetElementVisible(content[0], newVisible);
						return false;
					}
				}
			}
		}
	}
	return true;
} // CollapseWin()

//function ChangeInputToTextarea (input) { // called by onpaste
////#input_expand_into_textarea
//	//#todo more sanity
//	if (!input) {
//		return '';
//	}
//
//	if (document.createElement) {
//		var parent = input.parentElement;
//		var textarea = document.createElement('textarea');
//		var cols = input.getAttribute('cols');
//		var name = input.getAttribute('name');
//		var id = input.getAttribute('id');
//		var rows = 5;
//		var width = cols + 'em';
//
//		textarea.setAttribute('name', name);
//		textarea.setAttribute('id', id);
//		textarea.setAttribute('cols', cols);
//		textarea.setAttribute('rows', rows);
//		//textarea.style.width = width;
//		textarea.innerHTML = input.value;
//
//		//parent.appendChild(t);
//		parent.insertBefore(textarea, input.nextSibling);
//		input.style.display = 'none';
//
//		textarea.focus();
//		textarea.selectionStart = textarea.innerHTML.length;
//		textarea.selectionEnd = textarea.innerHTML.length;
//
//		if (window.inputToChange) {
//			window.inputToChange = '';
//		}
//	}
//
//	return true;
//}

//
//function ConvertSubmitsToButtonsWithAccessKey (parent) {
//	if (!parent) {
//		//alert('DEBUG: ConvertSubmitsToButtons: warning: sanity check failed');
//		return '';
//	}
//
//	if (parent.getElementsByClassName) {
//		var buttons = parent.getElementsByClassName('btnSubmit');
//		// convert each submit to button with accesskey
//	} else {
//		//todo
//	}
//	return ''
//} // ConvertSubmitsToButtonsWithAccessKey()

// == end utils.js