// begin loading_begin.js

//var loadingIndicatorWaitToShowMin = 1500;
//var loadingIndicatorWaitToHideMin = 500;

function addLoadingIndicator (strMessage) { // adds loading indicator bar (to top of page, depending on style)
	//alert('DEBUG: addLoadingIndicator(' + strMessage + ')');
	if (!strMessage) {
		//alert('DEBUG: strMessage = ' + strMessage);
		strMessage = 'Meditate...';
	}
	//alert('DEBUG: addLoadingIndicator: strMessage = ' + strMessage);

	if (!document.createElement) {
		//alert('DEBUG: addLoadingIndicator: warning: no document.createElement');
		return '';
		// #todo improve compatibility here
	}

	//alert('DEBUG: addLoadingIndicator: sanity checks passed!');
	var spanLoadingIndicator = document.createElement('span');
	if (spanLoadingIndicator) {
		spanLoadingIndicator.setAttribute('id', 'loadingIndicator');
		spanLoadingIndicator.innerHTML = strMessage;
		spanLoadingIndicator.zIndex = 1337;
		document.body.appendChild(spanLoadingIndicator);
	}

	return '';

} // addLoadingIndicator()

if (document.createElement) {
	//alert('DEBUG: loading_begin.js: createElement feature check PASSED!');
	var d = new Date();
	var loadingIndicatorStart = d.getTime() * 1;
	var gt = unescape('%3E');

	//var loadingIndicatorloadCounter = 0;
	addLoadingIndicator('Meditate...');
} else {
	//alert('DEBUG: loading_begin.js: createElement feature check FAILED!');
}
// end loading_begin.js
