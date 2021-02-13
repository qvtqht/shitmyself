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
		document.getElementById &&
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
						var freshUserWantsReload = 0;  // templated
						if (freshUserWantsReload) {
							// user wants reload
							//alert('DEBUG: user wants automatic page reload');
							location.reload();
						} else {
							// user doesn't want reload, just show notification
							//alert('DEBUG: user does not want automatic page reload, notify');
							window.lastEtag = eTag;

							var ariaAlert;
							ariaAlert = document.getElementById('ariaAlert');

							if (!ariaAlert) {
								//alert('DEBUG: ariaAlert created successfully');
								ariaAlert = document.createElement('p');
								ariaAlert.setAttribute('role', 'alert');
								ariaAlert.setAttribute('id', 'ariaAlert');
								ariaAlert.style.zIndex = '1337'; //#todo

								var txtUpdated = document.createTextNode('Page updated ');
								ariaAlert.appendChild(txtUpdated);

								//document.body.appendChild(ariaAlert);
								document.body.insertBefore(ariaAlert, document.body.firstChild);
								//window.newPageContent =
								//FetchNewPageContent(window.mypath + '?' + new Date().getTime());

								//ariaAlert.innerHTML = ariaAlert.innerHTML + '+';
								var d = new Date();
								var n = d.getTime();
								n = Math.ceil(n / 1000);

								var space = document.createElement('span');
								space.innerHTML = ' ';
								ariaAlert.appendChild(space);

								var a = document.createElement('a');
								a.setAttribute('id', 'freshAria');
								a.setAttribute('href', '#');
								a.setAttribute('onclick', 'location.reload()');
								ariaAlert.appendChild(a);

								var newTs = document.createElement('span');
								newTs.setAttribute('class', 'timestamp');
								newTs.setAttribute('epoch', n);
								newTs.setAttribute('id', 'freshTimestamp');
								newTs.innerHTML = 'just now!';
								a.appendChild(newTs);

								if (1) { // fresh_reuse_timestamp
									// reuse timestamp widget instead of adding new one
									var d = new Date();
									var n = d.getTime();
									n = Math.ceil(n / 1000);

									var newTs = document.getElementById('freshTimestamp');
									if (newTs) {
										newTs.setAttribute('epoch', n);
										newTs.innerHTML = 'just now!';
									}
								} else { // add new floatie
									var d = new Date();
									var n = d.getTime();
									n = Math.ceil(n / 1000);

									var a = document.getElementById('freshAria');
									var space = document.createElement('span');
									space.innerHTML = ' ';
									a.appendChild(space);
									var newTs = document.createElement('span');
									newTs.setAttribute('class', 'timestamp');
									newTs.setAttribute('epoch', n);
									a.appendChild(newTs);
									newTs.innerHTML = 'just now!';
								}
							} // ariaAlert

							if (document.title.substring(0,2) != '! ') {
								document.title = '! ' + document.title;
							}

							if (window.freshTimeoutId) {
								clearTimeout(window.freshTimeoutId);
							}
							window.eventLoopFresh = 0;
						} // NOT freshUserWantsReload
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

	return true;
} //freshCallback()

function CheckIfFresh () {
	var d = new Date();
	//alert('debug: CheckIfFresh: ' + d.getTime());

	var freshCheckRecent = window.freshCheckRecent;
	if (freshCheckRecent) {
		//alert('debug: CheckIfFresh: freshCheckRecent = ' + freshCheckRecent);
		var d = new Date();
		var curTime = d.getTime();
		if (curTime < freshCheckRecent + 3000) {
			return true;
		}
	}
	//alert('debug: CheckIfFresh: checkpoint passed');

	var d = new Date();
	window.freshCheckRecent = d.getTime();

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

		if (0 && mypath.toString().indexOf('?') == -1) {
			// this ensures no caching, but may cause other problems
			freshClient.open("HEAD", mypath + '?' + d.getTime(), true);
		} else {
			freshClient.open("HEAD", mypath, true);
		}

    	//freshClient.timeout = 5000; //#xhr.timeout
		freshClient.setRequestHeader('Cache-Control', 'no-cache');
		freshClient.onreadystatechange = freshCallback;

		freshClient.send();
	}

	return true;
} // CheckIfFresh()
//
//if (window.GetPrefs) {
//	var needNotify = (GetPrefs('notify_on_change') ? 1 : 0);
//	if (needNotify == 1) { // check value of notify_on_change preference
//		if (window.EventLoop) {
//			EventLoop();
//		} else {
//			CheckIfFresh();
//		}
//	}
//}

//alert('DEBUG: fresh.js');

// == end fresh.js