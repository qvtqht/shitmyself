// begin loading_begin.js

var loadingIndicatorWaitToShow = 3000;

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

	var loadingIndicatorloadCounter = 0;

	var loadingIndicator = document.createElement('span');
	if (loadingIndicator) {
		loadingIndicator.setAttribute('id', 'loadingIndicator');
		loadingIndicator.innerHTML = 'Loading...';
		document.body.appendChild(loadingIndicator);

		if (window.localStorage) {
			var loadingIndicatorLastLoadTime = localStorage.getItem('last_load_time');

			if (loadingIndicatorLastLoadTime && (loadingIndicatorWaitToShow < loadingIndicatorLastLoadTime)) {
				loadingIndicator.style.display = 'block';
			} else {
				loadingIndicator.style.display = 'none';
				var loadingIndicatorShowTimeout = setTimeout('loadingIndicator.style.display = "block"; localStorage.setItem(\'last_load_time\', 5000);', 1500);
			}
		} else {
			// #todo cookie-based?
		}

		var loadingIndicatorLightModeLink = window.location.pathname;
		if (loadingIndicatorLightModeLink == '/') {
			loadingIndicatorLightModeLink = '/index.html';
		}
		loadingIndicatorLightModeLink = loadingIndicatorLightModeLink + '?light=1';
		var loadingIndicatorExpandTimeout = setTimeout('loadingIndicator.innerHTML = loadingIndicator.innerHTML + \' <a href="' + loadingIndicatorLightModeLink + '"' + gt + 'Switch to light mode?</a' + gt + '.\';', 3000);
	}
}
// end loading_begin.js
