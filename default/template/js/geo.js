// == begin geo.js

function getPositionCallback(position) {
	if (document.getElementById) {
		var textbox = document.getElementById('comment');
		if (textbox) {
			textbox.innerHTML = textbox.innerHTML + '\n\n' + '[location]'; 
		}
	}
}

function insertGeo() {
	if (navigator.geolocation) {
		navigator.geolocation.getCurrentPosition(
			getPositionCallback
		);
	}
}

// == end geo.js