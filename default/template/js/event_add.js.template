// == begin event_add.js
function UpdateTimeString() {
    //alert('DEBUG: UpdateTimeString()');

	var year = document.forms['addevent'].year.value;
	var month = document.forms['addevent'].month.value;
	var day = document.forms['addevent'].day.value;
	var hour = document.forms['addevent'].hour.value;
	var minute = document.forms['addevent'].minute.value;
	var am_pm = document.forms['addevent'].am_pm.value;

	if (month < 10) {
		month = '0' + month;
	}

	if (day < 10) {
		day = '0' + day;
	}

	if (am_pm == 1) {
		hour = parseInt(hour, 10) + 12;
	}

	if (hour < 10) {
		hour = '0' + hour;
	}

	if (minute < 10) {
		minute = '0' + minute;
	}

	document.forms['addevent'].date_yyyy.value = year + '-' + month + '-' + day + ' ' + hour + ':' + minute;

	var d = new Date(year + '-' + month + '-' + day + ' ' + hour + ':' + minute);
	var dd = d.getTime();
	dd = Math.ceil(dd / 1000);

	document.forms['addevent'].date_epoch.value = dd;
}
// == end event_add.js