<?php

$cookie = 0;

include_once('utils.php');

// #technically all the commands stuff should be in profile.php

//	WriteLog(htmlspecialchars(nl2br(print_r($_GET))));

$responseSignedIn = 0;

if (isset($_GET['btnSignOut'])) {
	$_GET['request'] = 'Sign Out';
}

if (isset($_GET['btnRegister'])) {
	$_GET['request'] = 'Register';
}

if (isset($_GET['btnSignOut']) && $_GET['btnSignOut']) {
	// user requested to sign out

	// unset relevant cookies
	unsetcookie2('test');
	unsetcookie2('cookie');
	unsetcookie2('checksum');

	// redirect with signed out message
	RedirectWithResponse('/profile.html', 'Goodbye!');

	WriteLog('all cookies unset');
} # btnSignOut handler
else {
	if (isset($_COOKIE['test']) && $_COOKIE['test']) {
		WriteLog('test cookie found');

		$validCookies = array('cookie', 'checksum', 'test', 'light', 'show_advanced', 'beginner', 'show_admin');
		foreach ($_COOKIE as $cookieKey => $cookieValue) {
			if (in_array($cookieKey, $validCookies)) {
				// is ok
			} else {
				WriteLog('cookie.php: warning: unauthorized cookie was found and unset: ' . $cookieKey . ' = ' . $cookieValue);
				unsetcookie2($cookieKey);
			}
		}

		if (preg_match('/^[0-9A-F]{16}$/', $_COOKIE['test'])) { // #todo actual auth #knownCookieAuth
			WriteLog('test cookie override!');

			$cookie = $_COOKIE['test'];
			setcookie2('cookie', $cookie);

			$secret = GetConfig('admin/secret');
			if (!$secret) {
				WriteLog('cookie.php: $secret was false, making a new one');
				$secret = md5(time()); #todo #security
				PutConfig('admin/secret', $secret);
			}
			else {
				WriteLog('cookie.php: $secret was true');
			}

			$checksum = md5($cookie . '/' . $secret);
			setcookie2('checksum', $checksum);

			setcookie2('test', 1);

			$responseSignedIn = 1;
		} else {
			if (isset($_COOKIE['cookie']) && $_COOKIE['cookie']) {
				$cookie = $_COOKIE['cookie'];
			}

			if (isset($_COOKIE['checksum']) && $_COOKIE['checksum']) {
				$checksum = $_COOKIE['checksum'];
			}
		}

		WriteLog('$cookie = ' . (isset($cookie) ? $cookie : '(unset)') . '; $checksum= ' . (isset($checksum) ? $checksum : '(unset)'));

		$secret = GetConfig('admin/secret');

		if (!$cookie) {
			WriteLog('$cookie not found, creating new one...');

			$cookie = strtoupper(substr(md5(rand()), 16));
			$checksum = md5($cookie . '/' . $secret);

			setcookie2('cookie', $cookie);
			setcookie2('checksum', $checksum);

			$responseSignedIn = 1;
		}

		if (md5($cookie . '/' . $secret) != $checksum) {
			WriteLog('Checksum mis-match! Expected ' . md5($cookie . '/' . $secret) . ', found ' . $checksum);

			unset($cookie);
			unsetcookie2('cookie');
			unsetcookie2('checksum');
			unsetcookie2('test');

			RedirectWithResponse('/profile.html', 'Checksum mismatch detected. Please notify operator.');
		}

		if ($responseSignedIn) {
			RedirectWithResponse('/profile.html', 'Success! You have signed in.');
		}
	} // if (isset($_COOKIE['test']) && $_COOKIE['test'])
	else {
		if (isset($_GET['request']) && ($_GET['request'] == 'Register')) { // caution: $_GET['request'] may be set by code above
			setcookie2('test', '1');
			header('Location: /profile.html?' . time());
		}
	}
} # not btnSignout
//
// if (
// 	isset($_GET['theme'])
// 		&&
// 	($_GET['theme'] == 'chicago')
// ) {
// 	// test theme cookie
// 	setcookie2('theme', 'chicago');
// }