<?php

if ($_COOKIE) {
	print_r($_COOKIE);
}

if ($_GET && $_GET['setcookie']) {
	setcookie($_GET['setcookie'], 'abc');
}

if ($_GET && $_GET['unsetcookie']) {
	setcookie($_GET['unsetcookie'], '');
}
