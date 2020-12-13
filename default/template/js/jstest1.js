// begin jstest1.js

function RunTest() {
	//alert('DEBUG: RunTest() begins');

	//alert('DEBUG: Looking for document.getElementById...');


	if (window.navigator) {
		//alert('DEBUG: window.navigator was true, looking for navigator.language and navigator.userAgent');

		document.frmTest.txtNavigatorUserAgent.value = navigator.userAgent;
		document.frmTest.txtNavigatorLanguage.value = navigator.language;
	}

	var d = new Date();
	document.frmTest.comment.value += (' E' + d.getTime()) + ' ';

	// this is the most basic syntax for this file
	// for brevity, the rest of the tests are done with !!foo.bar syntax
	// i have not seen this cause an issue so far, it's very basic js
	// if it's ever a problem, can be changed to this syntax
	// even opera 3.62 is ok with it,
	if (document.getElementById) {
		document.frmTest.txtDocumentGetElementById.value = 'true';
	} else {
		document.frmTest.txtDocumentGetElementById.value = 'false';
	}


	//alert('DEBUG: Looking for document.getElementsByClassName...');
	document.frmTest.txtDocumentGetElementsByClassName.value = !!document.getElementsByClassName;

	//alert('DEBUG: Looking for window.localStorage...');
	document.frmTest.txtWindowLocalStorage.value = !!window.localStorage;

	//alert('DEBUG: Looking for window.Promise...');
	document.frmTest.txtWindowPromise.value = !!window.Promise;

	//alert('DEBUG: Looking for window.unescape...');
	document.frmTest.txtWindowUnescape.value = !!window.unescape;

	//alert('DEBUG: Looking for window.XMLHttpRequest...');
	document.frmTest.txtWindowXmlHttpRequest.value = !!window.XMLHttpRequest;

	if (navigator.userAgent.indexOf('Opera 3.') != -1) {
		//alert('DEBUG: Skipping String.fromCharCode, Opera 3.');
		document.frmTest.txtStringFromCharCode.value = 'skipped';
	} else {
		//alert('DEBUG: Looking for String.fromCharCode...');
		document.frmTest.txtStringFromCharCode.value = !!String.fromCharCode;
	}

	//alert('DEBUG: Looking for Date.getMilliseconds...');
	var now = new Date();
	document.frmTest.txtDateGetMilliseconds.value = !!now.getMilliseconds;

	//alert('DEBUG: Looking for window.history...');
	document.frmTest.txtWindowHistory.value = !!window.history;

	//alert('DEBUG: Looking for window.setTimeout...');
	document.frmTest.txtWindowSetTimeout.value = !!window.setTimeout;

	//alert('DEBUG: Testing window.setTimeout(...)...');
	document.frmTest.txtWindowSetTimeoutReturn.value = 'false';
	//alert('DEBUG: Calling window.setTimeout("setTimeoutReturn()", 10);');
    window.setTimeout('setTimeoutReturn()', 500);

	//#todo remove this probably
	if (navigator.userAgent.indexOf('MSIE 6.') != -1 || navigator.userAgent.indexOf('MSIE 5.5') != -1) {
	    //alert('DEBUG: Skipping navigator.javaEnabled, MSIE 6./5.5');
	    document.frmTest.txtStringFromCharCode.value = 'skipped';
	} else {
        //alert('DEBUG: Looking for navigator.javaEnabled...');
        document.frmTest.txtNavigatorJavaEnabled.value = !!navigator.javaEnabled ? (navigator.javaEnabled() ? 'true' : 'false') : 'undefined';
    }

	//alert('DEBUG: Looking for document.layers...');
	document.frmTest.txtDocumentLayers.value = !!document.layers;

	//alert('DEBUG: Looking for document.all...');
	document.frmTest.txtDocumentAll.value = !!document.all;

	//alert('DEBUG: Looking for window.opener...');
	document.frmTest.txtWindowOpener.value = window.opener;

	document.frmTest.comment.value += (' E' + d.getTime()) + ' ';

	//alert('DEBUG: Finished, returning.');
	return false;
}

function setTimeoutReturn() {
    //alert('DEBUG: setTimeoutReturn()');
	document.frmTest.txtWindowSetTimeoutReturn.value = 'true';
}

// end jstest1.js