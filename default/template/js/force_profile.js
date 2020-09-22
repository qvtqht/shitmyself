// == begin force_profile.js

// when this file is included, it will force the user to the profile page
// if they are not registered

if (window.getUserFp) {
	if (!getUserFp()) {
		var url = window.location.toString();

		// todo rewrite this to be more compatible
		if (document.getElementById) { // not a good feature check here
			var filename = url.split('/').pop().split('?').shift();

			if (filename != 'profile.html') {
				window.location = '/profile.html';
			}
		}
	}
}
// == end force_profile.js