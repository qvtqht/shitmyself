// == begin clock/indicator.js

// NOTE: this does not work for some reason yet
// it is not integrated either, this is an orphan file until this notice is removed

function setClock() {
	if (document.frmTopMenu) {
		if (document.frmTopMenu.txtClock) {
				document.frmTopMenu.txtClock.value = 'JavaScript!';

				if (document.frmTopMenu.txtClock.style) {
					document.frmTopMenu.txtClock.style.borderColor = 'green';
				}
			}
		}
	}
}

// == end clock/indicator.js