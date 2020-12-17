<?php
	include_once('./utils.php');

	$recentLog = `tail -n 99999 ./chat.txt`;

	if (isset($_GET) && isset($_GET['comment'])) {
		$comment = $_GET['comment'];
		$comment = trim($comment);

		if ($comment) {
			#todo sanitize #security
			$comment = str_replace("'", "", $comment);
			$comment = str_replace("\\", "\\\\", $comment);
			system('echo \''.$comment.'\' >> ./chat.txt');
		}

		header('Location: /quick.php?' . time());
		exit;
	}

	if (!$recentLog) {
		$recentLog = 'welcome to the chat!';
	}

	$table = '';
	$i = 0;
	foreach(array_reverse(explode("\n", trim($recentLog))) as $line) {
		$i++;

		$table .= '<tr><td>';

		#$table .=  '<input type=text name="box[' . $i .']" size=80 value="';
		$table .=  htmlspecialchars(trim($line));
		#$table .=  '">';

		$table .=  '</td></tr>';
	}

	//print '<style>*{font-size:x-small}</style>';
	print '<script>function sf(){document.sendit.comment.focus();var b=localStorage.getItem(\'handle\')||\'\';document.sendit.handle.value=b}</script>';
	print '<body bgcolor="#c0c0c0" onload="sf()">';
	print '<form name=sendit onsubmit="return jsonSubmit(document.sendit.comment.value);">';
	#print nl2br(htmlspecialchars($recentLog));
	print '<table width="95%" border=1 bordercolor="#808080" cellpadding=0 cellspacing=0>';
	print '<tr><td>';
	print '<input type=submit value="Send/Refresh">';
	print ' ';
	print '<input type=button value="Timestamp" onclick="var d = new Date(); document.sendit.comment.value+=d.toLocaleTimeString();">';
	print ' ';
	print '<a href=chat.txt>' . intval($i) . '</a>';
	print '<br>';
	print '<input name=comment type=text size=40 autofocus>';
	print ' ';
	print '<input name=handle type=text size=8 maxlength=16 onchange="localStorage.setItem(\'handle\', this.value);">';
	print '</td></tr>';

	print $table;

	print '</table>';
	print '</form>';
