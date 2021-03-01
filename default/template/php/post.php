<?php
/*
	php shim for accepting submissions
	proxies post.html if admin/php/enabled is on
*/

//error_reporting(E_ALL);

include_once('utils.php');

$AllVars = array();
function setvar($name, $value) {
	global $AllVars;
	WriteLog('setvar: ' . $name);
	if (array_key_exists($name, $AllVars)) {
		$AllVars[$name] = $value;
	} else {
		WriteLog('setvar: warning: tried to set variable which not initialized: ' . $name);
	}
}
function getvar($name) {
	global $AllVars;
	WriteLog('getvar: ' . $name);
	if (array_key_exists($name, $AllVars)) {
		return $AllVars[$name];
	} else {
		WriteLog('getvar: warning: tried to get variable which not initialied: ' . $name);
	}
}
function makevar($name) {
	global $AllVars;
	WriteLog('makevar: ' . $name);
	if (array_key_exists($name, $AllVars)) {
		WriteLog('makevar: warning: tried to make variable which already initialized: ' . $name);
	} else {
		$AllVars[$name] = '';
	}
	if (!array_key_exists($name, $AllVars)) {
		WriteLog('makevar: warning: just made variable, but it is not initialized: ' . $name);
	}
}

makevar('postPhpStartTime');
setvar('postPhpStartTime', time()); // remember begin time so that we know how long it takes

{ # if the emergency brake has been pulled, posting is not allowed
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
} # emergency brake

$redirectUrl = ''; // stores location to redirect to when done

function GetItemPlaceholderPage ($comment) { # generate temporary placeholder page for comment
# this page is typically overwritten later by the proper page generator
# but this gives us somewhere to go if the generator fails for any reason
# and allows us to acknowledge message receipt to the user

	// escape comment for output as html
	$commentHtml =                             #todo make this more readable
		nl2br(                                 # replace \n with <br>
			str_replace(                       # preserve indentation
				'  ',
				' &nbsp;',
				htmlspecialchars(              # escape <>&"
					wordwrap(                  # wrap to 80 columns
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
	$commentHtmlTemplate = GetTemplate('html/item_processing.template');

	// get theme name from config and associated background and foreground colors
	$themeName = trim(GetConfig('html/theme'));
	WriteLog('$themeName = ' . $themeName);

	{ // color values
		$colorWindow = GetConfig('theme/' . $themeName . '/color/window');
		$colorText = GetConfig('theme/' . $themeName . '/color/text');

		WriteLog('GetItemPlaceholderPage: $colorWindow = ' . $colorWindow);
		WriteLog('GetItemPlaceholderPage: $colorText = ' . $colorText);

		// replace placeholders with colors in template
		$commentHtmlTemplate = str_replace('$colorWindow', $colorWindow, $commentHtmlTemplate);
		$commentHtmlTemplate = str_replace('$colorText', $colorText, $commentHtmlTemplate);
	}

	// insert html-ized comment into template
	$commentHtmlTemplate = str_replace('$commentHtml', $commentHtml, $commentHtmlTemplate);

	return $commentHtmlTemplate;
} # GetItemPlaceholderPage()

$fileUrlPath = '';     // path to new item's html page
$replyTo = '';         // id of item replied to (parent)
$replyToToken = '';    // token for specifying replied to item, item id with >> prefix
$returnTo = '';        // page to return to, can be different from new item's page

$strSourceUrl = '';    // source document's url, specified as s= parameter in GET
$strSourceTitle = '';  // source document's title, specified as t= parameter in GET

if ($_POST) { // if POST request, populate variables from $_POST
	WriteLog('post.php: $_POST');

	if (isset($_POST['comment'])) {
		$comment = $_POST['comment'];
	}
	
	if (isset($_POST['replyto']) && $_POST['replyto']) {
		$replyTo = $_POST['replyto']; 
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_POST['s']) && $_POST['s']) { // s=
		$strSourceUrl = $_POST['s'];
	}
	if (isset($_POST['t']) && $_POST['t']) { // t=
		$strSourceTitle = $_POST['t'];
	}
	
	if (isset($_POST['replyto']) && $_POST['replyto']) {
		$replyTo = $_POST['replyto'];
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_POST['returnto']) && $_POST['returnto']) {
		$returnTo = $_POST['returnto'];
	}
} // $_POST
elseif ($_GET) { // if GET request, populate variables from $_GET
	WriteLog('post.php: $_GET found');

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

	if (isset($_GET['s']) && $_GET['s']) { // s=
		$strSourceUrl = $_GET['s'];
	}
	if (isset($_GET['t']) && $_GET['t']) { // t=
		$strSourceTitle = $_GET['t'];
	}

	if (isset($_GET['replyto']) && $_GET['replyto']) {
		$replyTo = $_GET['replyto'];
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_GET['returnto']) && $_GET['returnto']) {
		$returnTo = $_GET['returnto'];
	}
} # $_GET
elseif ($_REQUEST) { // if HEAD request, populate variables from $_REQUEST
	WriteLog('post.php: $_REQUEST found: ' . print_r($_REQUEST, 1));

	if (isset($_REQUEST['comment'])) {
		$comment = $_REQUEST['comment'];
	} else {
		if (isset($_REQUEST['txtClock'])) {
			$comment = $_REQUEST['txtClock'];
		} else {
			if (isset($_REQUEST['?comment'])) {
				$comment = $_REQUEST['?comment'];
			} else {
				if (isset($_REQUEST['?txtClock'])) {
					$comment = $_REQUEST['?txtClock'];
				} else {
					$comment = '';
				}
			}
		}
	}

	if (isset($_REQUEST['s']) && $_REQUEST['s']) { // s=
		$strSourceUrl = $_REQUEST['s'];
	}
	if (isset($_REQUEST['t']) && $_REQUEST['t']) { // t=
		$strSourceTitle = $_REQUEST['t'];
	}

	if (isset($_REQUEST['replyto']) && $_REQUEST['replyto']) {
		$replyTo = $_REQUEST['replyto'];
		$replyToToken = '>>' . $replyTo;
	}

	if (isset($_REQUEST['returnto']) && $_REQUEST['returnto']) {
		$returnTo = $_REQUEST['returnto'];
	}
} # $_REQUEST

if (isset($comment) && $comment) {
	if ($comment == 'Update') { #duplicated in route.php
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
			// add >> token to comment if $replyTo is provided, but comment does not have token
			// note that the regex does have a / at the end, it's after $replyTo
			$comment .= "\n\n" . $replyToToken;
		}

		if ($strSourceUrl || $strSourceTitle) {
			WriteLog('post.php: found $strSourceUrl or $strSourceTitle');

			#todo sanity checks
			$addendum = '';
			$addendumHash = '';

			if ($strSourceUrl) {
				$addendum .= $strSourceUrl;
				$addendum .= "\n";
			}
			if ($strSourceTitle) {
				$addendum .= $strSourceTitle;
				$addendum .= "\n";
			}
			if ($addendum) {
				//if ($newFileHash) {
				//	$addendum = '>>' . $newFileHash . "\n" . $addendum;
				//}
				//$addendumHash = ProcessNewComment($addendum, '');
				$comment .= "\n\n";
				$comment .= $addendum;
			}
		} else {
			WriteLog('post.php: NOT found $strSourceUrl or $strSourceTitle');
		}

		$newFileHash = ProcessNewComment($comment, $replyTo); // process comment, get new file hash
		$fileUrlPath = '/' . GetHtmlFilename($newFileHash); // path for client's (browser's) path to html file

		if (isset($replyTo) && $replyTo) {
			WriteLog('post.php: $replyTo = ' . $replyTo);
			MakePage($replyTo);
		} else {
			WriteLog('post.php: $replyTo not found');
		}

		if (!$redirectUrl && strpos($comment, 'PUBLIC KEY BLOCK')) {
			WriteLog('post.php: strpos($comment, PUBLIC KEY BLOCK)');

			// if user is submitting a public key, chances are
			// they just registered, so lazily redirect them to the profile page instead.
			// #todo relative url support
			// #todo better flow for registration -> profile page
			// #todo sometimes $newFileHash doesn't exist (why?)
			// #todo improve on this very naive way to figure out user id

			$finishTime = time() - getvar('postPhpStartTime');
			WriteLog('post.php: $newFileHash = ' . $newFileHash);
			$newFileHtmlPath = GetHtmlFilename($newFileHash);

			if (file_exists($newFileHtmlPath)) {
				WriteLog('post.php: file_exists($newFileHtmlPath)');

                // naive user identifier finder
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
			// return to parent item's page if no other place to return to is specified
			$returnTo = $replyTo;
		}

		if ($returnTo) {
			WriteLog('post.php: $returnTo = ' . $returnTo);
			// $returnTo specifies page/item to return to instead of submitted item
			$returnToHtmlPath = './' . GetHtmlFilename($returnTo); // path for parent html file

			if (file_exists($returnToHtmlPath)) {
				// path for client's (browser's) path to html file
				$returnToUrlPath = '/' . GetHtmlFilename($returnTo); // #todo relativize option
				$newItemAnchor = substr($newFileHash, 0, 8);
				$finishTime = time() - getvar('postPhpStartTime');

				if (GetConfig('admin/php/lazy_page_generation')) {
					WriteLog('post.php: $returnTo and lazy_page_generation leads to unlink($returnToHtmlPath = ' . $returnToHtmlPath . ')');
					unlink($returnToHtmlPath);
				}

				//$responseReplyPosted = StoreServerResponse("Success! Reply posted. <small>in $finishTime"."s</small>");
				//$redirectUrl = $returnToUrlPath . '?message=' . $responseReplyPosted . '&anchorto=' . $newItemAnchor;

				RedirectWithResponse($returnToUrlPath, "Success! Reply posted. <small>in $finishTime"."s</small>");
				// #todo add anchorto support ?

				// issue #2: ie does not like redirecting to a url with an anchor tag, because it tries to include that in the request
				// issue #3: mosaic doesn't like relative redirects, need to include own domain in return url
			} # if (file_exists($returnToHtmlPath))
		} # $returnTo
	} # regular comment, not 'update' or 'stop'
} # $comment

if (isset($filePath) && $filePath) {
	WriteLog('post.php: $filePath = ' . ($filePath ? $filePath : 'FALSE') . '; index_file_on_post = ' . GetConfig('admin/php/post/index_file_on_post'));
} else {
	WriteLog('post.php: warning: $filePath is FALSE');
}


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
	$finishTime = time() - getvar('postPhpStartTime');

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
