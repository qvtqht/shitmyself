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
	// $gpgStuff = GpgParse($filePath);##
	// WriteLog('$gpgStuff: ' . print_r($gpgStuff, 1));##
	// $commentHtmlTemplate .= print_r(GpgParse($filePath), 1);

	$pageTemplate = $commentHtmlTemplate;

	return $pageTemplate;
} # GetItemPlaceholderPage()

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

	}
	elseif (strtolower($comment) == 'stop' && GetConfig('admin/token/stop')) {
		$stopTime = time();
		$stopTimeConfig = GetConfig('admin/stop');
		if ($stopTimeConfig > $stopTime) {
			$stopTime = $stopTimeConfig;
		}
		$stopTime += 30;
		PutConfig('admin/stop', $stopTime);
		if ($stopTime > time()) {
			print("Stop request received. Users without cookie won't be able to post for " . ($stopTime - time()) . ' seconds.');
		}
	}
	else {
		if ($replyTo && !preg_match('/\>\>' . $replyTo . '/', $comment)) {
			// note that the regex does have a / at the end, it's after $replyTo
			$comment .= "\n\n" . $replyToToken;
		}

		$newFileHash = ProcessNewComment($comment, $replyTo);
		// path for client's (browser's) path to html file
		$fileUrlPath = '/' . GetHtmlFilename($newFileHash);

		if (!$redirectUrl && strpos($comment, 'PUBLIC KEY BLOCK')) {
			WriteLog('post.php: strpos($comment, PUBLIC KEY BLOCK)');
			// if user is submitting a public key, chances are
			// they just registered, so lazily redirect them
			// to the profile page instead.
			// #todo relative url support
			// #todo better flow for registration -> profile page
			// #todo sometimes $newFileHash doesn't exist
			// #todo this is a very naive way to figure out user id

			$finishTime = time() - $postPhpStartTime;
			WriteLog('post.php: $newFileHash = ' . $newFileHash);
			$newFileHtmlPath = GetHtmlFilename($newFileHash);

			if (file_exists($newFileHtmlPath)) {
				WriteLog('file_exists($newFileHtmlPath)');

                // naive
				$profileId = preg_match(
					'/[0-9A-F]{16}/',
					file_get_contents(
						$newFileHtmlPath
					),
					$matches
				);

				WriteLog('post.php: $profileId = ' . print_r($profileId, 1) . '; $matches = ' . print_r($matches, 1));

				if ($profileId) {
					$profileId = $matches[0];
				} else {
					$profileId = 0;
				}
				WriteLog('post.php: $profileId = ' . $profileId);
				if ($profileId) {
					MakePage($profileId);
					$redirectUrl = '/author/' . $profileId . '/index.html';
				} else {
					$redirectUrl = $fileUrlPath;
				}
				WriteLog('post.php: $redirectUrl = ' . $redirectUrl);
				
				if (file_exists('.' . $redirectUrl)) {
					RedirectWithResponse(
						$redirectUrl,
						"Success! Profile created! <small>in $finishTime"." seconds</small>"
					);
				} else {
					WriteLog("post.php: getcwd() = " . getcwd());
					WriteLog("post.php: file missing, no redirect: " . '.' . $redirectUrl);
				}

				WriteLog('post.php: ... continue after redirect? sadface');
			} else {
				WriteLog('post.php: file_exists($newFileHtmlPath) FALSE');
			}
		} # strpos($comment, 'PUBLIC KEY BLOCK')

		if ($replyTo && !$returnTo) {
			$returnTo = $replyTo;
		}

		if ($returnTo) {
			WriteLog('post.php: $returnTo = ' . $returnTo);
			// $returnTo specifies page/item to return to instead of submitted item
			$returnToHtmlPath = './' . GetHtmlFilename($returnTo); // path for parent html file

			if (file_exists($returnToHtmlPath)) {
				// path for client's (browser's) path to html file
				$returnToUrlPath = '/' . GetHtmlFilename($returnTo);
				$newItemAnchor = substr($newFileHash, 0, 8);
				$finishTime = time() - $postPhpStartTime;

				if (GetConfig('admin/php/lazy_page_generation')) {
					WriteLog('post.php: $returnTo and lazy_page_generation leads to unlink($returnToHtmlPath = ' . $returnToHtmlPath . ')');
					unlink($returnToHtmlPath);
				}

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
	} # regular comment, not 'update' or 'stop'
} # comment

#######################################
$html = file_get_contents('post.html');
#######################################

if (isset($fileUrlPath) && $fileUrlPath) {
	if (file_exists('../config/template/php/just_posted.template')) {
		$postedMessage = file_get_contents('../config/template/php/just_posted.template');
	}
	elseif (file_exists('../default/template/php/just_posted.template')) {
		copy ('../default/template/php/just_posted.template', '../config/template/php/just_posted.template');
		$postedMessage = file_get_contents('../default/template/php/just_posted.template');
	}
	else {
		$postedMessage = 'Look around and you may see it somewhere.';
	}

	$postedMessage = str_replace('$fileUrlPath', $fileUrlPath, $postedMessage);

	$html = str_replace('<!-- submitted_text -->', $postedMessage, $html);
}

if (!$redirectUrl && $fileUrlPath) {
	$finishTime = time() - $postPhpStartTime;

	if (!isset($redirectMessage)) {
		$redirectMessage = "Success! Item posted. <small class=advanced> in $finishTime"."s</small>";
	}

	$itemPostedServerResponse = $redirectMessage;
	//$itemPostedServerResponse .= ' <a href=/write.html>Another</a>'; // has bugs, doesn't always work

	RedirectWithResponse($fileUrlPath, $itemPostedServerResponse);
}

if (GetConfig('admin/php/debug')) {
    $html = str_replace('</body>', WriteLog('') . '</body>', $html);
}

print($html);