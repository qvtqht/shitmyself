<?php
/*
	php shim for accepting submissions
	proxies post.html if admin/php/enabled is on
*/

//error_reporting(E_ALL);

$postPhpStartTime = time();

include_once('utils.php');

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

$redirectUrl = ''; // where we're going after this is all over

function GetItemPlaceholderPage ($comment) { // generate temporary placeholder page for comment

	// escape comment for output as html
	$commentHtml =
		nl2br(
			str_replace(
				'  ',
				' &nbsp;',
				htmlspecialchars(
					wordwrap(
						trim($comment),
						80,
						' ',
						true
					),
					ENT_QUOTES|ENT_SUBSTITUTE,
					"UTF-8"
				)
			),
			0
		)
	;

	// template for temporary placeholder for html file
	// overwritten later by update.pl
	$commentHtmlTemplate = GetTemplate('item_processing.template');

	// get theme name from config and associated background and foreground colors
	$themeName = trim(GetConfig('html/theme'));
	WriteLog('$themeName = ' . $themeName);
	// color values
	$colorWindow = GetConfig('theme/' . $themeName . '/color/window');
	$colorText = GetConfig('theme/' . $themeName . '/color/text');
	WriteLog('$colorWindow = ' . $colorWindow);
	WriteLog('$colorText = ' . $colorText);

	// replace placeholders with colors in template
	$commentHtmlTemplate = str_replace('$colorWindow', $colorWindow, $commentHtmlTemplate);
	$commentHtmlTemplate = str_replace('$colorText', $colorText, $commentHtmlTemplate);

	// insert html-ized comment into template
	$commentHtmlTemplate = str_replace('$commentHtml', $commentHtml, $commentHtmlTemplate);

	// here we do gpg stuff, it's nothing for now
	//$gpgStuff = GpgParse($filePath);##
	//WriteLog('$gpgStuff: ' . print_r($gpgStuff, 1));##
//	$commentHtmlTemplate .= print_r(GpgParse($filePath), 1);

	$pageTemplate = $commentHtmlTemplate;

	return $pageTemplate;
}

function ProcessNewComment ($comment, $replyTo) { // saves new comment to .txt file and calls indexer
	$hash = ''; // hash of new comment's contents
	$fileUrlPath = ''; // path file should be stored in based on $hash

	WriteLog('ProcessNewComment(...)');

	if (isset($comment) && $comment) {
		WriteLog('ProcessNewComment: $comment exists');

		// remember current working directory, we'll need it later
		$pwd = getcwd();
		WriteLog('$pwd = ' . $pwd);

		// script directory is one level up from current directory,
		// which we expect to be called "html"
		$scriptDir = GetScriptDir();
		WriteLog('$scriptDir = ' . $scriptDir);

		// $txtDir is where the text files live, in html/txt
		$txtDir = $pwd . '/txt/';
		WriteLog('$txtDir = ' . $txtDir);

		// $htmlDir is the same as current directory
		$htmlDir = $pwd . '/';
		WriteLog('$htmlDir = ' . $htmlDir);

		// find hash of the comment text
		// it will not be the same as sha1 of the file for some mysterious reason, #todo
		// but we will use it for now.
		$hash = sha1($comment);
		WriteLog('$comment = ' . $comment); 
		WriteLog('$hash = ' . $hash);

		// generate a temporary filename based on the temporary hash
		$fileName = $txtDir . $hash . '.txt';
		WriteLog('$fileName = ' . $fileName);

		// standard signature separator
		$signatureSeparator = "\n-- \n";

		if (GetConfig('admin/http_auth/enable') && isset($_SERVER['PHP_AUTH_USER']) && GetConfig('admin/logging/record_http_auth_username')) {
			WriteLog('Recording http auth username... $_SERVER[PHP_AUTH_USER]: ' . $_SERVER['PHP_AUTH_USER']);
			// record user's http-auth username if we're doing that and it exists
			if ($_SERVER['PHP_AUTH_USER']) {
				$comment .= $signatureSeparator;
				$signatureSeparator = "\n";

				$comment .= 'Authorization: ' . $_SERVER['PHP_AUTH_USER'];
			}
		} else {
			WriteLog('NOT recording http auth username...');
		}

		if (GetConfig('admin/logging/record_cookie') && isset($_COOKIE['cookie']) && $_COOKIE['cookie']) {
			// if there's a cookie variable and cookie logging is enabled
			if (index($comment, 'PGP SIGNED MESSAGE') == -1 || GetConfig('admin/logging/record_cookie_when_signed')) {
				// don't add cookie if message appears signed. this is a temporary measure to mitigate duplicate messages
				// because access.pl doesn't know how to save cookies yet. record_cookie_when_signed=0 by default

				$comment .= $signatureSeparator;
				$signatureSeparator = "\n";

				$comment .= 'Cookie: ' . $_COOKIE['cookie'];
			}
		}

		if (GetConfig('admin/logging/record_http_host') && $_SERVER['HTTP_HOST']) {
			// record host if it's enabled
			$comment .= $signatureSeparator;
			$signatureSeparator = "\n";

			$comment .= 'Host: ' . $_SERVER['HTTP_HOST'];
		}


		// save the file as ".tmp" and then rename
		file_put_contents($fileName . '.tmp', $comment);
		rename($fileName . '.tmp', $fileName);

		WriteLog('ProcessNewComment: file_get_contents(' . $fileName . '):');
		WriteLog(file_get_contents($fileName));

		// now we can get the "proper" hash,
		// which is for some reason different from sha1($comment), as noted above
		$hash = GetFileHash($fileName);
		WriteLog('ProcessNewComment: $hash = ' . $hash);

		// hash-named files are stored under /ab/cd/ two-level directory prefix
		{ // create prefix subdirectories under txt/
			if (!file_exists($txtDir . substr($hash, 0, 2))) {
				mkdir($txtDir . substr($hash, 0, 2));
			}

			if (!file_exists($txtDir . substr($hash, 0, 2) . '/' . substr($hash, 2, 2))) {
				mkdir($txtDir . substr($hash, 0, 2) . '/' . substr($hash, 2, 2));
			}
		}
		{ // create prefix subdirectories under ./ (html/)
			if (!file_exists('./' .substr($hash, 0, 2))) {
				mkdir('./' . substr($hash, 0, 2));
			}

			if (!file_exists('./' . substr($hash, 0, 2) . '/' . substr($hash, 2, 2))) {
				mkdir('./' . substr($hash, 0, 2) . '/' . substr($hash, 2, 2));
			}
		}

		// path for new txt file
		$filePath =
			$txtDir .
			substr($hash, 0, 2) .
			'/' .
			substr($hash, 2, 2) .
			'/' .
			$hash . '.txt'
		;


		// path for new html file
		$fileHtmlPath = './' . GetHtmlFilename($hash);

		// path for client's (browser's) path to html file
		$fileUrlPath = '/' . GetHtmlFilename($hash);

		// save new post to txt file
		file_put_contents($filePath, $comment);
		// this could probably just be a rename() #todo

		// check if html file already exists. if it does, leave it alone
		if (!file_exists($fileHtmlPath)) {
			$commentHtmlTemplate = GetItemPlaceholderPage($comment);

			// store file
			WriteLog("file_put_contents($fileHtmlPath, $commentHtmlTemplate)");

			file_put_contents($fileHtmlPath, $commentHtmlTemplate);
		}

		if (isset($_SERVER['HTTP_REFERER']) && $_SERVER['HTTP_REFERER']) {
			$referer = $_SERVER['HTTP_REFERER'];

			// #todo uncomment this once this script is working
	//		header('Location: ' . $referer);
		} else {
			// #todo uncomment this once this script is working
	//		header('Location: /write.html');
		}

		WriteLog(' $fileUrlPath = ' . $fileUrlPath);
	}

	if (GetConfig('admin/php/post/update_item_on_post')) {
		WriteLog('ProcessNewComment: admin/php/post/update_item_on_post is TRUE');

		WriteLog("cd .. ; ./update.pl \"$filePath\"");
		WriteLog(`cd .. ; ./update.pl "$filePath"`);

		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}

		if (isset($replyTo) && $replyTo) {
			WriteLog("\$replyTo = $replyTo");
			if (IsItem($replyTo)) {
				WriteLog("cd .. ; ./pages.pl \"$replyTo\"");
				WriteLog(`cd .. ; ./pages.pl "$replyTo"`);

				if ($pwd) {
					WriteLog("cd $pwd");
					WriteLog(`cd $pwd`);
				}
			}
		} else {
			WriteLog("\$replyTo not found");
		}
	} else {
		WriteLog('ProcessNewComment: admin/php/post/update_item_on_post is FALSE');
	}

	if (GetConfig('admin/php/post/update_all_on_post')) {
		WriteLog('ProcessNewComment: admin/php/post/update_all_on_post is TRUE');

		WriteLog("cd .. ; ./update.pl --all");
		WriteLog(`cd .. ; ./update.pl --all`);

		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}
	} else {
		WriteLog('ProcessNewComment: admin/php/post/update_all_on_post is FALSE');

		if (GetConfig('admin/php/post/update_on_post')) {
			WriteLog('ProcessNewComment: admin/php/post/update_on_post is TRUE');

			WriteLog("cd .. ; ./update.pl");
			WriteLog(`cd .. ; ./update.pl`);

			if ($pwd) {
				WriteLog("cd $pwd");
				WriteLog(`cd $pwd`);
			}
		} else {
			WriteLog('ProcessNewComment: admin/php/post/update_on_post is FALSE');
		}
	}

	//return $fileUrlPath;
	return $hash;
} // ProcessNewComment

$fileUrlPath = '';
$replyTo = '';
$replyToToken = '';
$returnTo = '';

if ($_POST) {
	WriteLog('$_POST');

	if (isset($_POST['comment'])) {
		$comment = $_POST['comment'];
	}
	
	if (isset($_POST['replyto']) && $_POST['replyto']) {
		$replyTo = $_POST['replyto']; 
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_POST['returnto']) && $_POST['returnto']) {
		$returnTo = $_POST['returnto'];
	}
}

if ($_GET) {
	WriteLog('$_GET');

	WriteLog(print_r($_GET, 1));

	if (isset($_GET['comment'])) {
		$comment = $_GET['comment'];
	} else {
		if (isset($_GET['txtClock'])) {
			$comment = $_GET['txtClock'];
		} else {
			if (isset($_GET['?comment'])) {
				$comment = $_GET['?comment'];
			} else {
				if (isset($_GET['?txtClock'])) {
					$comment = $_GET['?txtClock'];
				} else {
					$comment = '';
				}
			}
		}
	}

	if (isset($_GET['replyto']) && $_GET['replyto']) {
		$replyTo = $_GET['replyto']; 
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_GET['returnto']) && $_GET['returnto']) {
		$returnTo = $_GET['returnto'];
	}
}

if (isset($comment) && $comment) {
	if ($comment == 'Update') {
		$updateStartTime = time();

		DoUpdate();
		$fileUrlPath = '';

		$updateFinishTime = time();

		$updateDuration = $updateFinishTime - $updateStartTime;

		RedirectWithResponse('/stats.html', "Update finished! <small>in $updateDuration"."s</small>");
	} elseif (strtolower($comment) == 'stop') {
		$stopTime = time();
		$stopTimeConfig = GetConfig('admin/stop');
		if ($stopTimeConfig > $stopTime) {
			$stopTime = $stopTimeConfig;
		}
		$stopTime += 30;
		file_put_contents('../config/admin/stop', $stopTime); //#todo PutConfig()
		if ($stopTime > time()) {
			print("Stop request received. Users without cookie won't be able to post for " . ($stopTime - time()) . ' seconds.');
		}
	} else {
		if ($replyTo && !preg_match('/\>\>' . $replyTo . '/', $comment)) {
			// note that the regex does have a / at the end, it's after $replyTo
			$comment .= "\n\n" . $replyToToken;
		}

		$newFileHash = ProcessNewComment($comment, $replyTo);
		// path for client's (browser's) path to html file
		$fileUrlPath = '/' . GetHtmlFilename($newFileHash);

		if (!$redirectUrl && strpos($comment, 'PUBLIC KEY BLOCK')) {
			// if user is submitting a public key, chances are
			// they just registered, so lazily redirect them
			// to the profile page instead.
			// #todo relative url support
			// #todo better flow for registration -> profile page

			$finishTime = time() - $postPhpStartTime;


			$profileId = preg_match(
				'/[0-9A-F]{16}/',
				file_get_contents(
					GetHtmlFilename($newFileHash)
				),
				$matches
			);
			if ($profileId) {
				$profileId = $matches[0];
			} else {
				$profileId = 0;
			}
			if ($profileId) {
				//#todo add file exists check
				$redirectUrl = '/author/' . $profileId . '/index.html';
			} else {
				//#todo add file exists check
				$redirectUrl = $fileUrlPath;
//			} else {
				// profile.html
			}

			RedirectWithResponse($redirectUrl, "Success! Profile created! <small>in $finishTime"."s</small>");


//		    $redirectUrl = '/profile.html?message=' . $messagePublicKeyPosted;
//		    $redirectUrl = $fileUrlPath . '?message=' . $messagePublicKeyPosted;
		}

		if ($replyTo && !$returnTo) {
			$returnTo = $replyTo;
		}

		if ($returnTo) {
			$returnToHtmlPath = './' . GetHtmlFilename($returnTo); // path for parent html file

			if (file_exists($returnToHtmlPath)) {
				// path for client's (browser's) path to html file
				$returnToUrlPath = '/' . GetHtmlFilename($returnTo);

				$newItemAnchor = substr($newFileHash, 0, 8);

				$finishTime = time() - $postPhpStartTime;

				//$responseReplyPosted = StoreServerResponse("Success! Reply posted. <small>in $finishTime"."s</small>");

				//$redirectUrl = $returnToUrlPath . '?message=' . $responseReplyPosted . '&anchorto=' . $newItemAnchor;
				RedirectWithResponse($returnToUrlPath, "Success! Reply posted. <small>in $finishTime"."s</small>");
				// #todo add anchorto support ?

				// issue #1: not using RedirectWithResponse()
				// issue #2: ie does not like redirecting to a url with an anchor tag, because it tries to include that in the request
				// issue #3: mosaic doesn't like relative redirects, need to include own domain in return url

				//$redirectUrl = $returnToUrlPath . '?message=' . $responseReplyPosted . '&anchorto=' . $newItemAnchor . '#' . $newItemAnchor;
			}
		}
	}
}

$html = file_get_contents('post.html');

if (isset($fileUrlPath) && $fileUrlPath) {
	if (file_exists('../config/template/php/just_posted.template')) {
		$postedMessage = file_get_contents('../config/template/php/just_posted.template');
	} elseif (file_exists('../default/template/php/just_posted.template')) {
		copy ('../default/template/php/just_posted.template', '../config/template/php/just_posted.template');
		$postedMessage = file_get_contents('../default/template/php/just_posted.template');
	} else {
		$postedMessage = '<a href="' . $fileUrlPath . '">See what you just posted.</a><br><br>';
	}

	$postedMessage = str_replace('$fileUrlPath', $fileUrlPath, $postedMessage); 
	
	$html = str_replace('<!-- submitted_text -->', $postedMessage, $html);
}

if (!$redirectUrl && $fileUrlPath) {
	$finishTime = time() - $postPhpStartTime;

	$itemPostedServerResponse = "Success! Item posted. <small class=advanced> in $finishTime"."s</small>";
	//$itemPostedServerResponse .= ' <a href=/write.html>Another</a>'; // has bugs, doesn't always work

	RedirectWithResponse($fileUrlPath, $itemPostedServerResponse);
}

if (GetConfig('admin/php/debug')) {
    $html = str_replace('</body>', WriteLog('') . '</body>', $html);
}
print($html);