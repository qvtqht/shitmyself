// == begin itsyou.js

function ItsYou () { // tells user it is their profile
// looks for id=itsyou element on the page and sets its text
// this can potentially output via document.write for nn3 and friends #todo
//alert('debug: ItsYou() begins');
	if (window.localStorage && document.getElementById) {
		var myFp = localStorage.getItem('fingerprint');

		if (
			(window.location.pathname == '/author/' + myFp + '/') ||
			(window.location.pathname == '/author/' + myFp + '/index.html')
		) {
			var itsYou = document.getElementById('itsyou');
			itsYou.innerHTML = 'This is your profile!';
		}
	} else {
		//alert('debug: need fallback for older browsers here');
	}
} // ItsYou()

// == end itsyou.js