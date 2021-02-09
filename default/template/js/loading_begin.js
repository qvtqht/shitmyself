// begin loading_begin.js

//var loadingIndicatorWaitToShowMin = 1500;
//var loadingIndicatorWaitToHideMin = 500;

function addLoadingIndicator (strMessage) { // adds loading indicator bar (to top of page, depending on style)
	//alert('DEBUG: addLoadingIndicator(' + strMessage + ')');
	if (strMessage == undefined || !strMessage) {
		//alert('DEBUG: strMessage = ' + strMessage);
		strMessage = 'Loading...';
	}
	//alert('DEBUG: addLoadingIndicator: strMessage = ' + strMessage);

	if (!document.createElement) {
		//alert('DEBUG: addLoadingIndicator: warning: no document.createElement');
		return '';
		// #todo improve compatibility here
	}

	var spanLoadingIndicator = document.createElement('span');
	//alert('DEBUG: addLoadingIndicator 1');
	spanLoadingIndicator.setAttribute('id', 'loadingIndicator');
	//alert('DEBUG: addLoadingIndicator 2');
	spanLoadingIndicator.innerHTML = strMessage;
	//alert('DEBUG: addLoadingIndicator 3');
	spanLoadingIndicator.zIndex = 1337;
	//alert('DEBUG: addLoadingIndicator 4');
	document.body.appendChild(spanLoadingIndicator);
	//alert('DEBUG: addLoadingIndicator 5');

} // addLoadingIndicator()

if (document.createElement) {
	//alert('DEBUG: loading_begin.js: createElement feature check PASSED!');
	var d = new Date();
	var loadingIndicatorStart = d.getTime() * 1;
	var gt = unescape('%3E');

	//var loadingIndicatorloadCounter = 0;
	addLoadingIndicator('Loading...');
} else {
	//alert('DEBUG: loading_begin.js: createElement feature check FAILED!');
}
// end loading_begin.js
