// == begin clock/epoch.js

var timeoutClock;

function setClock() {
	if (document.frmTopMenu) {
		if (document.frmTopMenu.txtClock) {
			if (document.frmTopMenu.txtClock.value) {
				var d = new Date();
				var n = d.getTime();
				n = Math.ceil(n / 1000);

				document.frmTopMenu.txtClock.value = n;

				if (document.frmTopMenu.txtClock.style) {
					document.frmTopMenu.txtClock.style.border = 0;
					//document.frmTopMenu.txtClock.setAttribute('size', 10);
				}
			}
		}
	}

	timeoutClock = window.setTimeout('setClock()', 500);
}

timeoutClock = window.setTimeout('setClock()', 500);

// == end clock/epoch.js