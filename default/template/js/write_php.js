// begin write_php.js

var intCommentOnChangeLastValue = 0;

function commentOnChange(t, formId) {
// changes form's method from get to post
// if comment's length is more than 1024
// and vice versa
//
// GET is more compatible and reliable
// POST allows longer messages
// 1024 is a relatively safe value
// some servers support up to 5-6K
//
// works down to netscape 3.04, but not 2.02
//
// also shows/hides warning message, lblWriteLengthWarning
// this part requires getElementById()

    //alert('DEBUG: commentOnChange() begin');

	if (intCommentOnChangeLastValue <= 1024 && t.value.length <= 1024) {
	    //alert('DEBUG: commentOnChange() intCommentOnChangeLastValue <= 1024 && t.value.length <= 1024, return');

		return '';
	}

	if (1024 < intCommentOnChangeLastValue && 1024 < t.value.length) {
	    //alert('DEBUG: commentOnChange() 1024 < intCommentOnChangeLastValue && 1024 < t.value.length, return');

		return '';
	}

	intCommentOnChangeLastValue = t.value.length;

	//alert('DEBUG: intCommentOnChangeLastValue = t.value.length = ' + t.value.length);

	var strFormMode;
	var strWarnDisplay;
	var strInnerHtml;

	//var gt = unescape('%3E');
    //var gt = '';
    var gt = unescape('%3E');

    //alert('DEBUG: gt: ' + gt);

	if (t.value.length <= 1024) {
	    //alert('DEBUG: setting form method to GET');
		strFormMode = 'GET';
		strWarnDisplay = 'none';
		strInnerHtml = 'Long message mode.<br' + gt;
	} else {
	    //alert('DEBUG: setting form method to POST');
		strFormMode = 'POST';
		strWarnDisplay = 'block';
		strInnerHtml = '';
	}

	if (document.forms && document.forms[formId] && document.forms[formId].method) {
		document.forms[formId].method = strFormMode;
//		var form = document.forms[formId];
//		if (form) {
//			form.method = strFormMode;
//		}
	}

	if (document.getElementById) {
//		var form = document.getElementById(formId);
//		if (form && form.setAttribute) {
//    		form.setAttribute('method', strFormMode);
//		}

		var warning = document.getElementById('lblWriteLengthWarning');
		if (warning) {
			warning.innerHTML = strInnerHtml;
			warning.style.display = strWarnDisplay;
		}
	}
}

// end write_php.js

