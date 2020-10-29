// == begin utils.js

// begin html escape hack (credit stacko)
// todo make this work without createElement
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
			window.location.href.indexOf('write') != -1 || // write is in location
			window.location.hash.indexOf('reply') != -1 // #reply hash at end of url
		) &&
		document.compose &&
		document.compose.comment &&
		document.compose.comment.focus
	) {
		//#todo only if url ends with #reply
		document.compose.comment.focus();
	}

	if (window.EventLoop) {
		if (window.CheckIfFresh) {
			window.eventLoopFresh = 1;
		}
		window.eventLoopEnabled = 1
		EventLoop();
	}
	
	var loadingIndicator;
	if (!loadingIndicator) {
		if (document.getElementById) {
			loadingIndicator = document.getElementById('loadingIndicator');
		}
	}
	if (window.searchOnload) {
		searchOnload();
	}
	if ((window.location.href.indexOf('search') != -1) && document.search.q) {
		document.search.q.focus();
	}
	if (loadingIndicator) {
		// #todo this should go into body.onload. but we are already injecting that event somewhere else.
		if (window.openPgpJsLoadBegin && !!window.openpgp) {
			loadingIndicator.innerHTML = 'Finished loading page. Loading library...';
			setTimeout('WaitForOpenPgp()', 500);
		} else {
			if (window.HideLoadingIndicator) {
				HideLoadingIndicator();
			}
		}
	}
}

function EventLoop () { // (currently unused) for calling things which need to happen on a regular basis
// sets another timeout for itself when done
// replaces several independent timeouts
// #todo add accounting for different intervals?
// #todo add secondary EventLoopRestore timer which ensures this one runs when needed
	//alert('debug: EventLoop');
	var d = new Date();
	var eventLoopBegin = d.getTime();

	if (window.eventLoopShowTimestamps && window.ShowTimestamps) {
		if (13000 < (eventLoopBegin - window.eventLoopShowTimestamps)) {
			ShowTimestamps();
			window.eventLoopShowTimestamps = eventLoopBegin;
		} else {
			// do nothing
		}
	}

	if (window.eventLoopShowAdvanced && window.ShowAdvanced) {
		ShowAdvanced();
	}

	if (window.eventLoopFresh && window.CheckIfFresh) {
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
			// #todo does this work?
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


function displayNotification (strMessage, thisButton) { // adds loading indicator bar (to top of page, depending on style)
	var spanNotification = document.createElement('span');
	spanNotification.setAttribute('class', 'notification');
	spanNotification.innerHTML = strMessage;

	if (thisButton) {
		thisButton.parentNode.appendChild(spanNotification); //#todo figure out why this doesn't actually work
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


// == end utils.js