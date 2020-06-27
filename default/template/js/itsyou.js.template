// == begin itsyou.js

if (window.localStorage && document.getElementById) {
	var myFp = localStorage.getItem('fingerprint');

	if (window.location.pathname == '/author/' + myFp + '/' || window.location.pathname == '/author/' + myFp + '/index.html') {
		var itsYou = document.getElementById('itsyou');
		itsYou.innerHTML = 'This is you!';
	}
} else {
	//alert('DEBUG: need fallback for older browsers here');
}

// == end itsyou.js