// begin loading_end.js

function HideLoadingIndicator () {
	if (!document.getElementById) {
		return '';
	}

	var loadingIndicator = window.loadingIndicator;

	if (!loadingIndicator) {
		if (document.getElementById) {
			loadingIndicator = document.getElementById('loadingIndicator');
		}
	}

	if (window.loadingIndicatorShowTimeout) {
		clearTimeout(loadingIndicatorShowTimeout);
	}

	loadingIndicator.innerHTML = 'Ready.';
	loadingIndicator.style.backgroundColor = '$colorHighlightAdvanced';

	window.loadingIndicator = loadingIndicator;

	setTimeout('if (window.loadingIndicator) { window.loadingIndicator.style.display = "none"; }', 3000); //#todo
	// } else {
	// 	if (loadingIndicator) { loadingIndicator.style.display = 'none' }
	// }
	return '';
} // HideLoadingIndicator()

function WaitForOpenPgp () {
	//alert('debug: WaitForOpenPgp()');
	var d = new Date();
	if (window.openPgpJsLoadBegin && window.openpgp) {
		HideLoadingIndicator();
	} else {
		setTimeout('if (window.WaitForOpenPgp) { WaitForOpenPgp() }', 500);
	}
} // WaitForOpenPgp()

if (!window.OnLoadEverything && window.HideLoadingIndicator) {
	HideLoadingIndicator();
}

// end loading_end.js
