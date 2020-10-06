// begin back_to_top_button.js
function showBackToTop () { // show or hide "back to top" button depending on vertical scroll state
    var pageOffset = document.body.scrollTop;

    if (100 < pageOffset) {
    	if (window.showBackToTopLastAction != 1) {
//			var colorBody = document.body.style.backgroundColor || document.body.getAttribute('bgcolor'));
//			var colorButton = document.getElementById('aBackToTop').style.backgroundColor;
//
//			setTimeout("document.getElementById('aBackToTop').style.backgroundColor = '#002000'", 250);
//			setTimeout("document.getElementById('aBackToTop').style.backgroundColor = '#004000'", 500);
//			setTimeout("document.getElementById('aBackToTop').style.backgroundColor = '#006000'", 750);
//			setTimeout("document.getElementById('aBackToTop').style.backgroundColor = '#008000'", 1000);

			document.getElementById('aBackToTop').style.visibility = 'visible';
			window.showBackToTopLastAction = 1;
		}
    } else {
    	if (window.showBackToTopLastAction != 0) {
        	document.getElementById('aBackToTop').style.visibility = 'hidden';
        	window.showBackToTopLastAction = 0;
		}
    }

    return true;
} // showBackToTop()

if (document.getElementById) { // enable window.onscroll if getElementById exists
    window.onscroll = window.showBackToTop;
    showBackToTop();
}
// end back_to_top_button.js