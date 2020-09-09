<?php

if ($_GET) {
	if ($_GET['q']) {
		$query = $_GET['q'];

		$query = strtolower($query);

		$query = preg_replace('/[^a-zA-Z0-9]/', ' ', $query);
		$query = str_replace('  ', ' ', $query);

		print $query;
	}
}