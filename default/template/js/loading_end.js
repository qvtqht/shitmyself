// begin loading_end.js

function HideLoadingIndicator () {
	if (!loadingIndicator) {
		if (document.getElementById) {
			loadingIndicator = document.getElementById('loadingIndicator');
		}
	}

	if (window.loadingIndicatorShowTimeout) {
		clearTimeout(loadingIndicatorShowTimeout);
	}

	loadingIndicator.innerHTML = 'Finished!';
	loadingIndicator.style.backgroundColor = '#00ff00';

	window.loadingIndicator = loadingIndicator;

	setTimeout('if (window.loadingIndicator) { window.loadingIndicator.style.display = "none"; }', 3000);
	// } else {
	// 	if (loadingIndicator) { loadingIndicator.style.display = 'none' }
	// }
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

// end loading_end.js
