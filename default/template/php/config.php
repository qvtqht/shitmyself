<?php
/* php/config.php */


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
echo "<br>legend<br><font color=red>*</font> - never looked up (only present in default/)<br><b>*</b>default - has been looked up with GetConfig, value is the same as in default<br><b>*</b><b>changed</b> - has been looked up with GetConfig, value is different from default<br><hr><br>";

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
	if (strpos($d, 'template') === false) {
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