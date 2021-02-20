<?php

if (file_exists('utils.php')) {
	include_once('utils.php');
}

$stopTimeConfig = GetConfig('admin/stop');
if ($stopTimeConfig) {
	if ($stopTimeConfig > time()) {
		if (isset($_COOKIE['test'])) {
		} else {
			print 'Emergency brake has been pulled. Posting is temporarily offline to unregistered visitors.';
			exit;
		}
	}
}

$html = file_get_contents('write.html');

//if (function_exists('GetConfig') && GetConfig('admin/php/write_form_prefill_browser_survey')) {
if (isset($_GET['report']) && $_GET['report'] == 'client') {
	$debugInfo =
		(isset($_SERVER['HTTP_USER_AGENT']) ? htmlspecialchars($_SERVER['HTTP_USER_AGENT']) : '-') .
		"\n" .
		'Host: ' .
		(isset($_SERVER['HTTP_HOST']) ? htmlspecialchars($_SERVER['HTTP_HOST']) : '-') .
		"\n" .
		'Self: ' .
		(isset($_SERVER['PHP_SELF']) ? htmlspecialchars($_SERVER['PHP_SELF']) : '-') .
		"\n" .
		'Accept: ' .
		(isset($_SERVER['HTTP_ACCEPT']) ? htmlspecialchars($_SERVER['HTTP_ACCEPT']) : '-') .
		"\n" .
		'Encoding: ' .
		(isset($_SERVER['HTTP_ACCEPT_ENCODING']) ? htmlspecialchars($_SERVER['HTTP_ACCEPT_ENCODING']) : '-') .
		"\n" .
		'Language: ' .
		(isset($_SERVER['HTTP_ACCEPT_LANGUAGE']) ? htmlspecialchars($_SERVER['HTTP_ACCEPT_LANGUAGE']) : '-')
	;

	$html = str_replace('</textarea>', $debugInfo . '</textarea>', $html);
//	$html = $debugInfo;
}

//if (1 || isset($_GET['russian']) && $_GET['russian']) {
//    WriteLog('Found russian');
//    $html = str_replace('<textarea', '<textarea onkeydown="if (window.translitKey) { translitKey(event, this); } else { return true; }"', $html);
//}


//print($html);
