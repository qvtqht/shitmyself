// == begin pingback.js
function ReportSelfUrl() {
	var myUrl = window.location;
//	var myUrl = window.location.hostname + ':' + window.location.port;
	
	if (myUrl) {
//		document.images[0].src = '/favicon.ico?mydomain=' + myUrl;
	}
}

setTimeout('ReportSelfUrl()', 5000);
// == end pingback.js