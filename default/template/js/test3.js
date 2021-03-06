<HEAD>
<SCRIPT LANGUAGE="JavaScript">
<!--
var timerID = null;
var timerRunning = false;
var clockStyle = 2;
// 0 = epoch time
// 1 = am/pm
// 2 = union square

function stopclock(){
	if(timerRunning) {
		clearTimeout(timerID);
	}
	timerRunning = false;
}

function startclock(){
	// Make sure the clock is stopped
	stopclock();
	showtime();
}

function showtime() {
	var timeValue = '';

	if (clockStyle == 1) {
	    // am/pm

		var now = new Date();
		var hours = now.getHours();
		var minutes = now.getMinutes();
		var seconds = now.getSeconds();
		var timeValue = "" + ((hours > 12) ? hours - 12 : hours);
		timeValue += ((minutes < 10) ? ":0" : ":") + minutes;
		timeValue += ((seconds < 10) ? ":0" : ":") + seconds;
		timeValue += (hours >= 12) ? " P.M." : " A.M.";
	}

	if (clockStyle == 0) {
	    // epoch time

		var d = new Date();
		var n = d.getTime();
		n = Math.ceil(n/1000);
		timeValue = n;
	}

	if (clockStyle == 2) {
	    // union

		var now = new Date();
		var hours = now.getHours();
		var minutes = now.getMinutes();
		var seconds = now.getSeconds();

		var milliseconds = '000';
		if (now.getMilliseconds) {
			milliseconds = now.getMilliseconds();
		} else if (Math.floor && Math.random) {
			milliseconds = Math.floor(Math.random() * 999);
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
	}

	document.clock.face.value = timeValue;
	timerID = setTimeout("showtime()", 1000);
	timerRunning = true;
}
//-->
</SCRIPT>

<style type="text/css">
<!--
input {
	font-family: monospace;
	font-size: 16pt;
	color: #ffaa44;
	background-color: black;
	text-align: center;
	border: 2pt solid black;
}
// -->
</style>

</HEAD>

<BODY onLoad="startclock()">
<FORM NAME="clock" onSubmit="0">
   <INPUT TYPE="text" NAME="face" SIZE=20 VALUE ="">

   <BR>

   <INPUT TYPE="button" VALUE="Start" onClick="startclock()">
   <INPUT TYPE="button" VALUE="Stop" onClick="stopclock()">
</FORM>
</BODY>