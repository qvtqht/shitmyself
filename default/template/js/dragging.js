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
	elmnt.style.position = 'absolute';
//	elmnt.style.z-index = '9';



	function dragMouseDown(e) {
		e = e || window.event;
		e.preventDefault();
		// get the mouse cursor position at startup:
		pos3 = e.clientX;
		pos4 = e.clientY;
		document.onmouseup = closeDragElement;
		// call a function whenever the cursor moves:
		document.onmousemove = elementDrag;
	}

	function elementDrag(e) {
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

		if (elmnt.id) {
			if (window.SetPrefs) {
				SetPrefs(elmnt.id + '.style.top', elmnt.style.top);
				SetPrefs(elmnt.id + '.style.left', elmnt.style.left);
			}
		}
	}
}

function DraggingInit() {
// initializes all class=dialog elements on the page to be draggable
	var elements = document.getElementsByClassName('dialog');
//	for (var i = 0; i < elements.length; i++) {
	for (var i = elements.length - 1; 0 <= i; i--) {
		var allTitlebar = elements[i].getElementsByClassName('titlebar');
		var firstTitlebar = allTitlebar[0];

		dragElement(elements[i], firstTitlebar);

		if (elements[i].id && window.GetPrefs) {
			var elTop = GetPrefs(elements[i].id + '.style.top');
			var elLeft = GetPrefs(elements[i].id + '.style.left');

			if (elTop && elLeft) {
				elmnt.style.left = elLeft;
				elmnt.style.top = elTop;
			}
		} else {
			//alert('DEBUG: dragging.js: warning: id and/or GetPrefs() missing');
		}
	}
} // DraggingInit()

/* / dragging.js */