// puzzle.js

if (document.createElement && document.head) {
// include sha512.js library instead of embedding it in page
// because it's big and contains (gt) characters
// and because it is large
	var script = document.createElement('script');
	script.src = '/sha512.js';
	script.async = false; // This is required for synchronous execution
	document.head.appendChild(script);
}

function doSolvePuzzle () { // solves puzzle
// called from a timeout set by solvePuzzle()
	var fp = '0000000000000000';
	if (window.getUserFp) {
		fp = getUserFp();
	}
	// user's fp or default to 000

	var i = 0; // counts iterations
	var done = 0; // done status

	var d = new Date();
	var epoch = d.getTime();
	epoch = Math.ceil(epoch / 1000); // current time in epoch format

	var r = 0 + ''; // stores random number as string
	var lookingFor = '1337'; // required hash prefix
	var lookingForLength = lookingFor.length;
	var cycleLimit = 1000000; // give up after this many tries
	var puzzle = ''; // finished puzzle
	var hash = ''; // hash of puzzle

	while(!done) {
		// look for a puzzle which fits criteria
		i = i + 1; // counter
		r = Math.random() + '';
		puzzle = fp + ' ' + epoch + ' ' + r;
		hash = hex_sha512(puzzle);
		if (hash.substring(0, lookingForLength) == lookingFor) {
			// match found
			done = 1;
		}
		if (cycleLimit < i) {
			// give up
			done = 2;
		}
	} // while(!done) -- solving puzzle

	// add to compose form, sign, and submit
	var txtComment = document.compose.comment;
	if (txtComment && window.solvePuzzle) {
		var puzzleResult = '';
		if (done == 1) {
			puzzleResult = puzzle;
		} else {
			puzzleResult = 'puzzle not solved, even after ' + i + ' tries';
		}
		if (txtComment.value.substr(txtComment.value.length - 2, 2) == "\n\n") {
			txtComment.value += puzzleResult;
		} else {
			if (txtComment.value.substr(txtComment.value.length - 1, 1) == "\n") {
				txtComment.value += "\n" + puzzleResult;
			} else {
				txtComment.value += "\n\n" + puzzleResult;
			}
		}
	}
	var btnSolvePuzzle = document.getElementById('btnSolvePuzzle');
	if (window.signMessage) {
		if (btnSolvePuzzle) {
			btnSolvePuzzle.value = 'Signing...';
		}
		signMessage();
	}
	if (window.writeSubmit) {
		writeSubmit();
		if (btnSolvePuzzle) {
			btnSolvePuzzle.value = 'Sending...';
		}
	}
} // doSolvePuzzle()

function solvePuzzle (t) { // t = button pressed ; begins puzzle solving process and indicates to user
// done with timeout to give button a chance to change caption before pegging cpu

	if (!window.hex_sha512 || !window.doSolvePuzzle) {
		// required function is missing
		return true;
	}
	if (t) {
		// update button caption
		t.value = 'Solving...';
	}

	// set timeout to solve puzzle
	var timeoutSolvePuzzle = setTimeout('doSolvePuzzle()', 500);

	return false; // do not let the calling form submit, doSolvePuzzle() will do it
} // solvePuzzle()

// / puzzle.js
