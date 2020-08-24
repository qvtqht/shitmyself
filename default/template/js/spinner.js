// begin spinner.js

var spinnerButton;
var spinnerTimer;

function spinButton() {
    //alert('DEBUG: spinButton()');

    if (spinnerButton) {
        //alert('DEBUG: spinButton() spinnerButton');

        if (spinnerButton.value == '01010') {
            spinnerButton.value = '10101';
        } else {
            spinnerButton.value = '01010';
        }
    }
//

    spinnerTimer = setTimeout('spinButton(0)', 500);
}

// end spinner.js