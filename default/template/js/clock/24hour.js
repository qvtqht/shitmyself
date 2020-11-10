// == begin clock/24hour.js

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

                if (!window.clockLastSec || window.clockLastSec != seconds) {
                	window.clockLastSec = seconds;

					if (window.clockColonState) {
						timeValue = hours + ':' + minutes;
						window.clockColonState = 0;
					} else {
						timeValue = hours + ' ' + minutes;
						window.clockColonState = 1;
					}

					if (document.frmTopMenu.txtClock.value != timeValue) {
						document.frmTopMenu.txtClock.value = timeValue;
					}
				}
            }
		}
	}
}

// == end clock/24hour.js