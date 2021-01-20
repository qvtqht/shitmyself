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
	//alert('debug: OnLoadEverything() begins');

	if (window.setClock) {
		window.eventLoopSetClock = 1;
		setClock();
	}
	if (window.ItsYou) {
		ItsYou();
	}
	if (window.ShowTimestamps) {
		window.eventLoopShowTimestamps = 1;
	}
	if (window.SettingsOnload) {
		SettingsOnload();
	}
	if (window.ProfileOnLoad) {
		ProfileOnLoad();
	}
	if (window.WriteOnload) {
		WriteOnload();
	}
	if (window.DraggingInit) {
		DraggingInit();
	}
	if (window.ShowAdvanced) {
		window.eventLoopShowAdvanced = 1;
		ShowAdvanced(0);
	}
	if (
		(
			window.location.href.indexOf('write') != -1 ||
			window.location.hash.indexOf('reply') != -1
		) &&
		document.compose &&
		document.compose.comment &&
		document.compose.comment.focus
	) {
		document.compose.comment.focus();
	}

	if (window.searchOnload) {
		searchOnload();
	}
	if (window.UploadAddImagePreviewElement) {
		UploadAddImagePreviewElement();
	}
	if ((window.location.href.indexOf('search') != -1) && document.search.q) {
		document.search.q.focus();
	}

	if (window.HideLoadingIndicator) {
		HideLoadingIndicator();
	}

	// everything is set now, start event loop
	//

	if (window.EventLoop) {
		if (window.CheckIfFresh) {
			window.eventLoopFresh = 1;
		}
		window.eventLoopEnabled = 1
		EventLoop();
	}
} // OnLoadEverything()

function EventLoop () { // for calling things which need to happen on a regular basis
// sets another timeout for itself when done
// replaces several independent timeouts
// #backlog add secondary EventLoopWatcher timer which ensures this one runs when needed
	//alert('debug: EventLoop');
	var d = new Date();
	var eventLoopBegin = d.getTime();

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
		if (t.innerHTML == '[show]') {
			t.innerHTML = '[hide]';
			// t.innerHTML = '[up]';
		} else {
			t.innerHTML = '[show]';
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