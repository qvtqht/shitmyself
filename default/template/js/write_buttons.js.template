// == begin write_buttons.js

// if there's a user fingerprint,
// this checks for a place to put a "post as" or "reply as" button
// and if it exists, puts the button there
if (window.getUserFp) {
	if (document.getElementById && getUserFp() && document.createElement) {
		var sp = document.getElementById('signAndPost');
		var actName = 'Post as ';

		if (!sp) {
			sp = document.getElementById('replySignedContainer');
			actName = 'Sign as ';
		}

		actName = actName + getAvatar();

		if (sp) {
			var lblSignAs = document.createElement('label');
			lblSignAs.setAttribute('for', 'chkSignAs');

			var chkSignAs = document.createElement('input');
			//chkSignAs.setAttribute('name', 'signAs');
			chkSignAs.setAttribute('id', 'chkSignAs');
			chkSignAs.setAttribute('type', 'checkbox');
			chkSignAs.setAttribute('checked', 1);
			// this checkbox being checked means signMessage() is called in writeSubmit()

			lblSignAs.innerHTML = 'Sign as ' + getAvatar();

			lblSignAs.appendChild(chkSignAs);

			sp.appendChild(lblSignAs);

			////
			//	the [button] way, allowing formatting inside button
			//	if using color avatars, requiring button element instead of submit, would look like this:
			//			var btnSignReply = document.createElement('button');
			//			btnSignReply.setAttribute('onclick', "this.innerHTML = 'Meditate...'; if (window.signMessage) { signMessage(); }");
			//			btnSignReply.innerHTML = actName;

			////
			//	the <input type=submit way, more compatible
			//			var btnSignReply = document.createElement('input');
			//			btnSignReply.setAttribute('onclick', "this.value = 'Meditate...'; if (window.signMessage) { signMessage(); }");
			//			btnSignReply.setAttribute('value', actName);
			//			btnSignReply.setAttribute('type', 'submit');
			//
			//			sp.appendChild(btnSignReply);

			////
			// the old way
			//			var gt = unescape('%3E');
			// 			sp.innerHTML = '<button onclick=""' + gt + actName + getAvatar() + '</button' + gt;
		}
	}
}

// == end write_buttons.js