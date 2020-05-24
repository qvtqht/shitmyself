// begin loading_end.js

if (!a383) {
	if (document.getElementById) {
		a383 = document.getElementById('a383');
	}
}

function HideLoadingIndicator() {
	if (window.a383showTimeout) {
		clearTimeout(a383showTimeout);
	}

	var a383dd = new Date();
	//document.title = a383dd + ' ' + window.openPgpJsLoadBegin + ' ' + !!window.openpgp;

	var a383end = a383dd.getTime() * 1;
	var a383duration = a383end*1 - a383start*1;
	var a383durationAvg = ((a383duration * 1) + (a383lastLoadTime * 1)) / 2;

	if (window.localStorage) {
		localStorage.setItem('last_load_time', a383durationAvg );
	}

	a383.innerHTML = 'Finished! You meditated for ' + (Math.floor(a383duration / 1000)) + 's.';
	a383.style.backgroundColor = '#00ff00';

	var a383hideTimeout = a383duration / 5;
	if (5000 < a383hideTimeout) {
		a383hideTimeout = 5000;
	}
	if (a383hideTimeout < 500) {
		a383hideTimeout = 0;
	}

	if (a383hideTimeout) {
		setTimeout('if (a383) { a383.style.backgroundColor = "#00c000"; }', a383hideTimeout);
		setTimeout('if (a383) { a383.style.backgroundColor = "#008000"; a383.style.color = "#00c000"; }', a383hideTimeout * 1.1);
		setTimeout('if (a383) { a383.style.backgroundColor = "#000000"; a383.style.color = "#00ff00"; }', a383hideTimeout * 1.2);
		setTimeout('if (a383) { a383.style.color = "#00c000"; }', a383hideTimeout * 1.3);
		setTimeout('if (a383) { a383.style.color = "#008000"; }', a383hideTimeout * 1.4);
		setTimeout('if (a383) { a383.style.color = "#004000"; }', a383hideTimeout * 1.5);
		setTimeout('if (a383) { a383.style.display = "none"; }', a383hideTimeout * 1.6);
	} else {
		if (a383) { a383.style.display = 'none' }
	}
}

function WaitForOpenPgp() {
	if (window.openPgpJsLoadBegin && !!window.openpgp) {
		HideLoadingIndicator();
	} else {
		setTimeout('WaitForOpenPgp()', 500);
	}
}

if (window.a383) { // #todo this could go into body.onload. but we are already injecting that event somewhere else.
	if (window.openPgpJsLoadBegin && !!window.openpgp) {
		a383.innerHTML = 'Finished loading page. Loading library...';
		setTimeout('WaitForOpenPgp()', 500);
	} else {
	 	HideLoadingIndicator();
	}
}

// end loading_end.js
