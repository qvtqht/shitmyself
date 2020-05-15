// == begin clock/24hour.js

var timeoutClock;

function setClock() {
	if (document.frmTopMenu) {
		if (document.frmTopMenu.txtClock) {
			if (document.frmTopMenu.txtClock.value) {
                var now = new Date();
                var hours = now.getHours();
                var minutes = now.getMinutes();
                var seconds = now.getSeconds();

                if (hours < 10) {
                    hours = '0' + '' + hours;
                }
                if (minutes < 10) {
                    minutes = '0' + '' + minutes;
                }
                if (seconds < 10) {
                    seconds = '0' + '' + seconds;
                }

                timeValue = hours + ':' + minutes + ':' + seconds;

                document.frmTopMenu.txtClock.value = timeValue;
            }
		}
	}

	timeoutClock = window.setTimeout('setClock()', 50);
}

timeoutClock = window.setTimeout('setClock()', 50);

// == end clock/24hour.js