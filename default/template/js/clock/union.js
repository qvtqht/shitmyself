// == begin clock/union.js
function setClock () {
	if (document.frmTopMenu) {
		if (document.frmTopMenu.txtClock) {
			if (document.frmTopMenu.txtClock.value) {
                var now = new Date();
                var hours = now.getHours();
                var minutes = now.getMinutes();
                var seconds = now.getSeconds();

                var milliseconds = '000';
                if (now.getMilliseconds) {
                    milliseconds = now.getMilliseconds();
                } else if (Math.floor && Math.random) {
                    milliseconds = Math.floor(Math.random() * 999)
                }

                var hoursR = 23 - hours;
                if (hoursR < 10) {
                    hoursR = '0' + '' + hoursR;
                }
                var minutesR = 59 - minutes;
                if (minutesR < 10) {
                    minutesR = '0' + '' + minutesR;
                }
                var secondsR = 59 - seconds;
                if (secondsR < 10) {
                    secondsR = '0' + '' + secondsR;
                }

                if (milliseconds < 10) {
                    milliseconds = '00' + '' + milliseconds;
                } else if (milliseconds < 100) {
                    milliseconds = '0' + '' + milliseconds;
                }

                if (hours < 10) {
                    hours = '0' + '' + hours;
                }
                if (minutes < 10) {
                    minutes = '0' + '' + minutes;
                }
                if (seconds < 10) {
                    seconds = '0' + '' + seconds;
                }

                timeValue = hours + '' + minutes + '' + seconds + '' + milliseconds + '' + secondsR + '' + minutesR + '' + hoursR;
                document.frmTopMenu.txtClock.value = timeValue;
            }
		}
	}

} // setClock()

// == end clock/union.js