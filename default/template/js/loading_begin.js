// begin loading_begin.js

var loadingIndicatorWaitToShowMin = 500;
var loadingIndicatorWaitToHideMin = 500;

function addLoadingIndicator (strMessage) { // adds loading indicator bar (to top of page, depending on style)
	if (!strMessage) {
		strMessage = 'Loading...';
	}

	var spanLoadingIndicator = document.createElement('span');
	spanLoadingIndicator.setAttribute('id', 'spanLoadingIndicator');
	spanLoadingIndicator.innerHTML = strMessage;
	document.body.appendChild(spanLoadingIndicator);
} // addLoadingIndicator()

if (document.createElement) {
	var d = new Date();
	var loadingIndicatorStart = d.getTime() * 1;
	var gt = unescape('%3E');

//	var loadingIndicatorloadCounter = 0;
	var loadingIndicator = document.createElement('span');
	if (loadingIndicator) {
		loadingIndicator.setAttribute('id', 'loadingIndicator');
		loadingIndicator.innerHTML = 'Loading...';
		document.body.appendChild(loadingIndicator);
	}
}
// end loading_begin.js
