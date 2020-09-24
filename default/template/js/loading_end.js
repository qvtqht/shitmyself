// begin loading_end.js

if (!loadingIndicator) {
	if (document.getElementById) {
		loadingIndicator = document.getElementById('loadingIndicator');
	}
}

function HideLoadingIndicator() {
	if (window.loadingIndicatorShowTimeout) {
		clearTimeout(loadingIndicatorShowTimeout);
	}

	var dd = new Date();
	//document.title = dd + ' ' + window.openPgpJsLoadBegin + ' ' + !!window.openpgp;

	var loadingIndicatorEnd = dd.getTime() * 1;
	var loadingIndicatorDuration = (loadingIndicatorEnd * 1) - (loadingIndicatorStart * 1);
	var loadingIndicatorDurationAvg = ((loadingIndicatorDuration * 1) + (loadingIndicatorLastLoadTime * 1)) / 2;

	if (window.localStorage) {
		localStorage.setItem('last_load_time', loadingIndicatorDurationAvg);
	}

	loadingIndicator.innerHTML = 'Finished! You meditated for ' + (Math.floor(loadingIndicatorDuration / 10) / 100) + ' seconds';
	loadingIndicator.style.backgroundColor = '#00ff00';

	var loadingIndicatorHideTimeout = loadingIndicatorDuration / 5;
	if (20000 < loadingIndicatorHideTimeout) {
		loadingIndicatorHideTimeout = 20000;
	}
	if (loadingIndicatorHideTimeout < 5000) {
		loadingIndicatorHideTimeout = 5000;
	}

	setTimeout('if (loadingIndicator) { loadingIndicator.style.display = "none"; }', loadingIndicatorHideTimeout * 1.6);
	// } else {
	// 	if (loadingIndicator) { loadingIndicator.style.display = 'none' }
	// }
}

function WaitForOpenPgp() {
	if (window.openPgpJsLoadBegin && !!window.openpgp) {
		HideLoadingIndicator();
	} else {
		setTimeout('WaitForOpenPgp()', 500);
	}
}

if (window.loadingIndicator) {
	// #todo this should go into body.onload. but we are already injecting that event somewhere else.
	if (window.openPgpJsLoadBegin && !!window.openpgp) {
		loadingIndicator.innerHTML = 'Finished loading page. Loading library...';
		setTimeout('WaitForOpenPgp()', 500);
	} else {
	 	HideLoadingIndicator();
	}
}

// end loading_end.js
