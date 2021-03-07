/* dragging.js */
// allows dragging of boxes on page with the mouse pointer

/*
	known issues:
	* problem: syntax errors on older browsers like netscape
	  solution: remove nested function declarations
	* problem: no keyboard alternative at this time
	  solution: somehow allow moving through windows and moving them with keyboard
	* problem: slow and janky, needs more polish
	  solution: optimizations
*/

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

window.draggingZ = 0; // keeps track of the topmost box's zindex
// incremented whenever dragging is initiated, that way element pops to top

function dragElement (elmnt, header) {
	//alert('DEBUG: dragElement');

	var pos1 = 0, pos2 = 0, pos3 = 0, pos4 = 0;
	if (header) {
		// if present, the header is where you move the DIV from:
		header.onmousedown = dragMouseDown;
	} else {
		// otherwise, move the DIV from anywhere inside the DIV:
		elmnt.onmousedown = dragMouseDown;
	}

	// set element's position based on its initial box model position
	var rect = elmnt.getBoundingClientRect();
	elmnt.style.position = 'absolute';
	elmnt.style.top = (rect.top) + "px";
	elmnt.style.left = (rect.left) + "px";

    //console.log(rect.top, rect.right, rect.bottom, rect.left);
	//elmnt.style.position = 'absolute';
	//elmnt.style.z-index = '9';

	function dragMouseDown(e) {
		//alert('DEBUG: dragMouseDown');
		elmnt.style.zIndex = ++window.draggingZ;

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
		//alert('DEBUG: elementDrag');
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
		//alert('DEBUG: closeDragElement');

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
						//elements[i].style.top = GetPrefs(elId.innerHTML + '.style.top') || elId.style.top;
						//elements[i].style.left = GetPrefs(elId.innerHTML + '.style.left') || elId.style.left;
					} else {
						//alert('DEBUG: DraggingInit: elId is false');
					}
				}
			}
		}
	}
}

function DraggingCascade () {
	//alert('DEBUG: DraggingCascade()');
	
	var titlebarHeight = 0;

	var curTop = 55;
	var curLeft = 5;
	var curZ = 0;

	var elements = document.getElementsByClassName('dialog');
	for (var i = 0; i < elements.length; i++) {
	// for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		// walking backwards is necessary to preserve the element positioning on the page
		// once we remove the element from the page flow, all the other elements reflow to account it
		// if we walk forwards here, all the elements will end up in the top left corner

		var allTitlebar = elements[i].getElementsByClassName('titlebar');
		var firstTitlebar = allTitlebar[0];

		var allMenubar = elements[i].getElementsByClassName('menubar');
		var firstMenubar = allMenubar[0];

		titlebarHeight = 30;

		if (firstMenubar) {
			elements[i].style.zIndex = 1337;
		} else {
			if (firstTitlebar && firstTitlebar.getElementsByTagName) {
				// dragElement(elements[i], firstTitlebar);
				var elId = firstTitlebar.getElementsByTagName('b');
				elId = elId[0];

				elements[i].style.top = curTop + 'px';
				elements[i].style.left = curLeft +'px';
				elements[i].style.zIndex = curZ;

				curZ++;
				curTop += titlebarHeight;
				curLeft += titlebarHeight;
			}
		}
	}
} // DraggingCascade()

function DraggingInit (doPosition) {
// InitDrag { DragInit {
// initialize all class=dialog elements on the page to be draggable

	//alert('DEBUG: DraggingInit');

	if (!document.getElementsByClassName) {
		// feature check
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
	// for (var i = 0; i < elements.length; i++) {
	for (var i = elements.length - 1; 0 <= i; i--) { // walk backwards for positioning reasons
		// walking backwards is necessary to preserve the element positioning on the page
		// once we remove the element from the page flow, all the other elements reflow to account it
		// if we walk forwards here, all the elements will end up in the top left corner

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
	}
} // DraggingInit()

/* / dragging.js */