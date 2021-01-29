<?php
/* php/config.php */

include_once('utils.php');

function index ($string, $needle) { // emulates perl's index(), returning -1 instead of false
	$strpos = strpos($string, $needle);
	if ($strpos === false) {
		return -1;
	} else {
		return $strpos;
	}
}

echo(time());

echo "<br><hr><br>";
echo "<br>Below is set of local config which differs from defaults<br>";
echo "<br>You can copy and paste this into Write form of your own site, sign it, and post as Operator.";
echo "<br><hr><br>";

$default = explode("\n", `find ../default`);
$config = explode("\n", `find ../config`);

$configLookup = array();

foreach ($config as $c) {
	$c = str_replace('../config/', '', $c);
	$configLookup[$c] = 1;

	$configValue[$c] = file_exists('../config/' . $c) ? trim(file_get_contents('../config/' . $c)) : '';
	$defaultValue[$c] = file_exists('../default/' . $c) ? trim(file_get_contents('../default/' . $c)) : '';
}

foreach ($default as $d) {
	if (index($d, 'secret') != -1) {
		$d = str_replace('../default/', '', $d);

//		print (isset($configLookup[$d]) ? $configLookup[$d] : '');

		if (isset($configLookup[$d])) {
			//print ('<b>+</b>');
			if ($configValue[$d] == $defaultValue[$d]) {
				//print 'default';
			} else {
				print "config ";
				print $d;
				print ' ';
				print htmlspecialchars(trim($configValue[$d]));
				print "<br>";
			}
		}

	}
}

/* / php/config.php */