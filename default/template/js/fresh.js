// == begin fresh.js
var freshClient;
//
//function ReplacePageWithNewContent () {
//	window.location.replace(window.newPageLocation);
//	document.open();
//	document.write(window.newPageContent);
//	document.close();
//
//	return 0;
//}
//
//function StoreNewPageContent () {
//	var xmlhttp = window.xmlhttp2;
//
//	if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
//		//alert('DEBUG: PingUrlCallbackReplaceCurrentPage() found status 200');
//		window.newPageContent = xmlhttp.responseText;
//		window.newPageLocation = xmlhttp.responseURL;
//
//		//window.location.replace(xmlhttp.responseURL);
////		document.open();
////		document.write(xmlhttp.responseText);
////		document.close();
//	}
//}
//
//function FetchNewPageContent (url) {
//	if (window.XMLHttpRequest) {
//		//alert('DEBUG: PingUrl: window.XMLHttpRequest was true');
//
//		var xmlhttp;
//		if (window.xmlhttp2) {
//			xmlhttp = window.xmlhttp2;
//		} else {
//			window.xmlhttp2 = new XMLHttpRequest();
//			xmlhttp = window.xmlhttp2;
//		}
//        xmlhttp.onreadystatechange = window.StoreNewPageContent;
//        xmlhttp.open("GET", url, true);
//		xmlhttp.setRequestHeader('Cache-Control', 'no-cache');
//        xmlhttp.send();
//
//        return false;
//	}
//}


function freshCallback() { // callback for requesting HEAD for current page
//alert('DEBUG: freshCallback() this.readyState = ' + this.readyState);

//	if (1 || this.readyState == this.HEADERS_RECEIVED) { // headers received -- what we've been waiting for
	if (
		this.readyState == this.HEADERS_RECEIVED ||
		this.status == 200
	) { // headers received -- what we've been waiting for
		// document.title = 'DEBUG: callback received 200';
	    //alert('DEBUG: freshCallback() this.readyState == this.HEADERS_RECEIVED');

		var eTag = freshClient.getResponseHeader("ETag"); // etag header contains page 'fingerprint'

		//alert('DEBUG: eTag = ' + eTag);

		if (eTag) { // if ETag header has a value
			if (window.myOwnETag) {
				if (eTag != window.myOwnETag) {
					if (eTag == window.lastEtag) { // if it's equal to the one we saved last time
						// no new change change
					} else {
						window.lastEtag = eTag;

						var ariaAlert;
						ariaAlert = document.getElementById('ariaAlert');
						if (!ariaAlert) {
							ariaAlert = document.createElement('p');
							ariaAlert.setAttribute('role', 'alert');
							ariaAlert.setAttribute('id', 'ariaAlert');
							ariaAlert.innerHTML = 'Page has changed. ';

							var a = document.createElement('a');
							a.setAttribute('href', '#');
							a.setAttribute('onclick', 'location.reload()');
							a.innerHTML = 'Reload';
							ariaAlert.appendChild(a);

							//document.body.appendChild(ariaAlert);
							document.body.insertBefore(ariaAlert, document.body.firstChild);
							//window.newPageContent =
							//FetchNewPageContent(window.mypath + '?' + new Date().getTime());
						} else {
							ariaAlert.innerHTML = ariaAlert.innerHTML + '+';
						}

						if (document.title.substring(0,2) != '! ') {
							document.title = '! ' + document.title;
						}

						if (window.freshTimeoutId) {
							clearTimeout(window.freshTimeoutId);
						}
					} // lastEtag also didn't match
				} // eTag != window.myOwnETag
				else {
					//document.title = 'freshCallback: x ' + window.myOwnETag + ';' + new Date().getTime();

					if (window.freshTimeoutId) {
						clearTimeout(window.freshTimeoutId);
					}
					window.freshTimeoutId = setTimeout('CheckIfFresh()', 15000);
				}
			} // if (window.myOwnETag)
			else {
				window.myOwnETag = eTag;
			}
		} // if (eTag) // ETag header has value
	} // status == 200
} //freshCallback()

function CheckIfFresh() {
	//document.title = 'CheckIfFresh: ' + new Date().getTime();

	var xhr = null;
	if (window.XMLHttpRequest){
    	xhr = new XMLHttpRequest();
    }
    else {
    	if (window.ActiveXObject) {
    		xhr = new ActiveXObject("Microsoft.XMLHTTP");
		}
    }


	if (xhr) {
		var mypath = window.mypath;

		if (!mypath) {
			mypath = window.location;
			window.mypath = mypath;
		}

		freshClient = xhr;
		//freshClient.open("HEAD", mypath + '?' + new Date().getTime(), true);
		freshClient.open("HEAD", mypath, true);
    	freshClient.timeout = 5000;
		freshClient.setRequestHeader('Cache-Control', 'no-cache');
		freshClient.onreadystatechange = freshCallback;

		freshClient.send();
	}
}

if (window.GetPrefs) {
	var needNotify = GetPrefs('notify_on_change') || 0;
	if (needNotify == 1) { // check value of notify_on_change preference
		CheckIfFresh();
	}
}

//alert('DEBUG: fresh.js');

// == end fresh.js