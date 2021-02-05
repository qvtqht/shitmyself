/* dragging.js */
// props https://www.w3schools.com/howto/howto_js_draggable.asp

/*
		#mydiv {
    	  	position: absolute;
     		z-index: 9;
    	}
    	
    	#mydivheader {
    		this is just the titlebar
    	}
*/

function dragElement (elmnt, header) {
	var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;

	if (header) {
		// if present, the header is where you move the DIV from:
		header.onmousedown = dragMouseDown;
	} else {
		// otherwise, move the DIV from anywhere inside the DIV:
		elmnt.onmousedown = dragMouseDown;
	}

	var rect = elmnt.getBoundingClientRect();

	elmnt.style.position = 'absolute';
	elmnt.style.top = (rect.top) + "px";
	elmnt.style.left = (rect.left) + "px";

    //console.log(rect.top, rect.right, rect.bottom, rect.left);
	//elmnt.style.position = 'absolute';
	//elmnt.style.z-index = '9';

	function dragMouseDown(e) {
		e = e || window.event;
		e.preventDefault();
		// get the mouse cursor position at startup:
		pos3 = e.clientX;
		pos4 = e.clientY;

		document.onmouseup = closeDragElement;
		// call a function whenever the cursor moves:
		document.onmousemove = elementDrag;

		elmnt.style.zIndex++;
	}

	function elementDrag(e) {
		//document.title = pos1 + ',' + pos2 + ',' + pos3 + ',' + pos4;
		//document.title = e.clientX + ',' + e.clientY;
		//document.title = elmnt.offsetTop + ',' + elmnt.offsetLeft;
		e = e || window.event;
		e.preventDefault();
		// calculate the new cursor position:
		pos1 = pos3 - e.clientX;
		pos2 = pos4 - e.clientY;
		pos3 = e.clientX;
		pos4 = e.clientY;
		// set the element's new position:

		elmnt.style.top = (elmnt.offsetTop - pos2) + "px";
		elmnt.style.left = (elmnt.offsetLeft - pos1) + "px";
	}

	function closeDragElement() {
		// stop moving when mouse button is released:
		document.onmouseup = null;
		document.onmousemove = null;

		if (elmnt) {
			var allTitlebar = elmnt.getElementsByClassName('titlebar');
			var firstTitlebar = allTitlebar[0];

			if (firstTitlebar && firstTitlebar.getElementsByTagName) {
				var elId = firstTitlebar.getElementsByTagName('b');
				if (elId && elId[0]) {
					elId = elId[0];

					if (elId && elId.innerHTML.length < 31) {
						SetPrefs(elId.innerHTML + '.style.top', elmnt.style.top);
						SetPrefs(elId.innerHTML + '.style.left', elmnt.style.left);
		//				elements[i].style.top = GetPrefs(elId.innerHTML + '.style.top') || elId.style.top;
		//				elements[i].style.left = GetPrefs(elId.innerHTML + '.style.left') || elId.style.left;
					} else {
						//alert('DEBUG: DraggingInit: elId is false');
					}
				}
			}
			elmnt.style.zIndex++;
		}
//
//		if (elmnt.id) {
//			if (window.SetPrefs) {
//				SetPrefs(elmnt.id + '.style.top', elmnt.style.top);
//				SetPrefs(elmnt.id + '.style.left', elmnt.style.left);
//			}
//		}
	}
}

function DraggingInit (doPosition) {
// initializes all class=dialog elements on the page to be draggable
	if (!document.getElementsByClassName) {
		return '';
	}

	if (window.GetPrefs && !GetPrefs('draggable')) {
		//alert('DEBUG: DraggingInit: warning: GetPrefs(draggable) was false, returning');
		return '';
	}

	if (doPosition) {
		doPosition = 1;
	} else {
		doPosition = 0;
	}

	var elements = document.getElementsByClassName('dialog');
//	for (var i = 0; i < elements.length; i++) {
	for (var i = elements.length - 1; 0 <= i; i--) {
		var allTitlebar = elements[i].getElementsByClassName('titlebar');
		var firstTitlebar = allTitlebar[0];

		if (firstTitlebar && firstTitlebar.getElementsByTagName) {
			dragElement(elements[i], firstTitlebar);
			var elId = firstTitlebar.getElementsByTagName('b');
			elId = elId[0];
			if (doPosition && elId && elId.innerHTML.length < 31) {
				elements[i].style.top = GetPrefs(elId.innerHTML + '.style.top') || elements[i].style.top;
				elements[i].style.left = GetPrefs(elId.innerHTML + '.style.left') || elements[i].style.left;
			} else {
				//alert('DEBUG: DraggingInit: elId is false');
			}
		}


//		if (elements[i].id && window.GetPrefs) {
//			var elTop = GetPrefs(elements[i].id + '.style.top');
//			var elLeft = GetPrefs(elements[i].id + '.style.left');
//
//			if (elTop && elLeft) {
//				elmnt.style.left = elLeft;
//				elmnt.style.top = elTop;
//			}
//
//			//var elTop = window.elementPosCounter || 1;
//			//var elTop = GetPrefs(elements[i].id + '.style.top');
//			//window.elementPosCounter += elmnt.style.height;
//
//			//var elLeft = GetPrefs(elements[i].id + '.style.left') || 1;
//
//			//if (elTop && elLeft) {
//				//elmnt.style.left = elLeft;
//				//elmnt.style.top = elTop;
//			//}
//		} else {
//			//alert('DEBUG: dragging.js: warning: id and/or GetPrefs() missing');
//		}
//		//dragElement(elements[i], firstTitlebar);
	}
} // DraggingInit()

/* / dragging.js */