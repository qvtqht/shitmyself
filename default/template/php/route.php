<?php

// this fixes a crash bug in mosaic. it should not cause a problem anywhere else
// <_<     >_>      o_O      -_-     ^_^
header('Content-Type: text/html');
include_once('utils.php');

WriteLog('route.php begins');

//
//if (1/0) {
//    // disabled
//}

if (GetConfig('admin/php/route_random_update') && rand(1, 17) == 1) {
# randomly call DoUpdate() on page load
# may slow down user's experience, but site is more likely to be up to date
	if (function_exists('DoUpdate')) {
	    DoUpdate();
    }
}

function SetHtmlClock ($html) { // sets html clock on page if present
	WriteLog('SetHtmlClock()');
	$html = preg_replace('/id=txtClock value=\".+\"/', 'id=txtClock value="' . GetClockFormattedTime() . '"', $html);
    return $html;
}

function TrimPath ($string) { // Trims the directories AND THE FILE EXTENSION from a file path
# Should really be called GetFileNameWithoutPathAndExtension()
	while (index($string, "/") >= 0) {
		$string = substr($string, index($string, "/") + 1);
	}

	if (index($string, '.') >= 0) {
		$string = substr($string, 0, index($string, ".") + 0);
	}

	return $string;
} # TrimPath()

function TranslateEmoji ($html) { // replaces emoji with respective text
	WriteLog('TranslateEmoji()');

	// this could be optimized a lot. A LOT.

	$scriptDir = GetScriptDir();
	if ($scriptDir) {
		$emojiList = explode("\n", `find $scriptDir/config/string/emoji`);
		foreach ($emojiList as $emojiFile) {
			$emojiName = TrimPath($emojiFile);
			$emojiEmoji = GetFile($emojiFile);
			$html = str_replace($emojiEmoji, '[' . $emojiName . ']', $html);
		}
	}

//	$html = preg_replace('/id=txtClock value=\".+\"/', 'id=txtClock value="' . GetClockFormattedTime() . '"', $html);

    return $html;
}

function StripHeavyTags ($html) { // strips heavy tags from page replaces with basic ones
	WriteLog('StripHeavyTags()');

	$tags = array(
		'table', 'tr', 'td', 'th', 'span', 'fieldset', 'legend', 'font',
		'script', 'style', 'big'
	);

	{
		// this would be necessary if the br tags were not already there
		// may be useful in the future to do automated fixing-up of existing templates
		// then we can remove all those <br> tags from the templates and make them look neater

		// the substitutions below provide some reasonable replacements for the tags
		// each replacement, for debugging purposes, has an extra attribute like id1 or id5
		// these can be removed later once debugging is mostly finished

		$html = preg_replace('/\<\/a\>\<b\>/', '</a>; <b id1>', $html);
		$html = preg_replace('/\<\/b\>\<a\ /', '</b>; <a id2 ', $html);

		$html = preg_replace('/\<\/th\>/', '; ', $html);
		$html = preg_replace('/\<br\>\<\/td\>/', '; ', $html);
		$html = preg_replace('/\<\/td\>\<\/tr\>/', '<br>', $html);
		$html = preg_replace('/:\<\/td\>\<td\>/', ': ', $html);
		$html = preg_replace('/\<\/td\>/', '; ', $html);
		$html = preg_replace('/\<\/tr\>\<\/table\>/', '<br><hr>', $html);
		$html = preg_replace('/\<\/table\>/', '<br><hr>', $html);
		$html = preg_replace('/\<\/tr\>/', '<br>', $html);
		$html = preg_replace('/\<\/fieldset\>\<\/td\>/', '<br>', $html);
		$html = preg_replace('/\<\/fieldset\>/', '<br>', $html);
		$html = preg_replace('/\<\/legend\>/', '<br>', $html);
		$html = preg_replace('/\<\/a\>\<a/', '</a>; <a', $html);
		$html = preg_replace('/; ;/', '; ', $html);
	}

	foreach ($tags as $tag) {
		$html = preg_replace('/\<'.$tag.'[^>]+\>/', '', $html);
		//$html = preg_replace('/\<\/'.$tag.'\>/', '', $html);
		$html = str_replace('<'.$tag.'>', '', $html);
		$html = str_replace('</'.$tag.'>', '', $html);
	}

	return $html;
}

function StripComments ($html) { // strips html comments from html
	$html = preg_replace('/\<\!--[^>]+\>/', '', $html);

	return $html;
}

function CleanBodyTag ($html) { // removes all attributes from body tag in given html
	$html = preg_replace('/\<body[^>]+\>/', '<body>', $html);

	return $html;
}

function StripWhitespace ($html) { // strips extra whitespace from given html
//	while (preg_match('/[\t\n ]{2}'
	$html = str_replace("\t", ' ', $html);

	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);
	$html = str_replace("\n ", "\n", $html);

//
	$html = str_replace("\n", ' ', $html);

	$html = str_replace('  ', ' ', $html);
	$html = str_replace('  ', ' ', $html);
	$html = str_replace('  ', ' ', $html);
	$html = str_replace('  ', ' ', $html);
	$html = str_replace('  ', ' ', $html);
//
//	while (! (strpos($html, '  ') === false)) {
//		$html = str_replace('  ', ' ', $html);
//	}
//
	$html = str_replace('> <', '><', $html);
////	$html = str_replace('> ', '>', $html);
////	$html = str_replace(' <', '<', $html);
//	$html = str_replace('<br><br>', '<br>', $html);
//	$html = str_replace('<br> <br>', '<br>', $html);

	return $html;
}

function InjectJs ($html, $scriptNames, $injectMode = 'before', $htmlTag = '</body>') { // inject js template(s) into html
// $injectMode: before, after, append (to end of html)
// $htmlTag: e.g. </body>, only used with before/after
// if $htmlTag is not found, does fall back to append

	WriteLog('InjectJs() begin...');

	if (!GetConfig('admin/js/enable')) {
		return $html;
	}

	$scriptsText = '';  // will contain all the js we want to inject
	$scriptsComma = ''; // separator between scripts, will be set to \n\n after first script

	$scriptsDone = array();  // array to keep track of scripts we've already injected, to avoid duplicates

//	if (GetConfig('html/clock')) {
//		// if clock is enabled, automatically add its js
//		$scriptNames[] = 'clock';
//	}
//
//	if (GetConfig('admin/js/enable') && GetConfig('admin/js/fresh')) {
//		// if clock is enabled, automatically add it
//		$scriptNames[] = 'fresh';
//	}
//
	//output list of all the scripts we're about to include
	$scriptNamesList = implode(' ', $scriptNames);

	// loop through all the scripts
	foreach ($scriptNames as $script) {
		// only inject each script once, otherwise move on
		if (isset($scriptsDone[$script])) {
			next;
		} else {
			$scriptsDone[$script] = 1;
		}

		// separate each script with \n\n
		if (!$scriptsComma) {
			$scriptsComma = "\n\n";
		} else {
			$scriptsText .= $scriptsComma;
		}

		$scriptTemplate = GetTemplate("js/$script.js");

		if (!$scriptTemplate) {
			WriteLog("InjectJs: warning: Missing script contents for $script");
 			if (GetConfig('admin/debug')) {
// 				die('InjectJs: Missing script contents');
				$scriptTemplate = "alert('InjectJs: warning: Missing template $script.js');";
 			}
		}

		if ($script == 'voting') {
			// for voting.js we need to fill in some theme colors
			$colorSuccessVoteUnsigned = GetThemeColor('success_vote_unsigned');
			$colorSuccessVoteSigned = GetThemeColor('success_vote_signed');

			$scriptTemplate = str_replace('$colorSuccessVoteUnsigned', $colorSuccessVoteUnsigned, $scriptTemplate);
			$scriptTemplate = str_replace('$colorSuccessVoteSigned', $colorSuccessVoteSigned, $scriptTemplate);
		}
		// #todo finish porting this when GetRootAdminKey() is available in php
		//		if ($script == 'profile') {
		//			# for profile.js we need to fill in current admin id
		//			my $currentAdminId = GetRootAdminKey() || '-';
		//
		//			$scriptTemplate =~ s/\$currentAdminId/$currentAdminId/g;
		//		}

		if ($script == 'settings') {
			// for settings.js we also need to fill in some theme colors
			$colorHighlightAdvanced = GetThemeColor('highlight_advanced');
			$colorHighlightBeginner = GetThemeColor('highlight_beginner');

			$scriptTemplate = str_replace('$colorHighlightAdvanced', $colorHighlightAdvanced, $scriptTemplate);
			$scriptTemplate = str_replace('$colorHighlightBeginner', $colorHighlightBeginner, $scriptTemplate);
		}

		if (index($scriptTemplate, '>') > -1) {
			# warning here if script content contains > character, which is incompatible with mosaic's html comment syntax
			WriteLog('InjectJs: warning: Inject script "' . $script . '" contains > character');
		}

		static $debugType;
		if (!isset($debugType)) {
			$debugType = GetConfig('admin/js/debug');
			$debugType = trim($debugType);
		}

		if ($debugType) {
			#uncomment all javascript debug alert statements
			#and replace them with confirm()'s which stop on no/cancel
			#
			if ($debugType == 'console.log') {
				$scriptTemplate = str_replace("//alert('DEBUG:", "console.log('", $scriptTemplate);
			} elseif ($debugType == 'document.title') {
				$scriptTemplate = str_replace("//alert('DEBUG:", "document.title = ('", $scriptTemplate);
			} else {
				$scriptTemplate = str_replace("//alert('DEBUG:", "if(!window.dbgoff)dbgoff=!confirm('DEBUG:", $scriptTemplate);
			}
		}

		// add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	// get the wrapper, i.e. <script>$javascript</script>
	$scriptInject = GetTemplate('html/utils/scriptinject.template');


	// fill in the wrapper with our scripts from above
	$scriptInject = str_replace('$javascript', $scriptsText, $scriptInject);

	$scriptInject = '<!-- InjectJs: ' . $scriptNamesList . ' -->' . "\n\n" . $scriptInject;

	if ($injectMode != 'append' && index($html, $htmlTag) > -1) {
		// replace it into html, right before the closing </body> tag
		if ($injectMode == 'before') {
			$html = str_replace($htmlTag, $scriptInject . $htmlTag, $html);
		} else {
			$html = str_replace($htmlTag, $htmlTag . $scriptInject, $html);
		}
	} else {
		if ($injectMode != 'append') {
			WriteLog('InjectJs: warning: $html does not contain $htmlTag, falling back to append mode');
		}
		$html .= "\n" . $scriptInject;
	}

	return $html;
}

function HandleNotFound ($path, $pathRel) { // handles 404 error by regrowing the missing page
// Handle404 (
	WriteLog("HandleNotFound($path, $pathRel)");

	if (GetConfig('admin/php/regrow_404_pages')) {
		WriteLog('HandleNotFound: admin/php/regrow_404_pages was true');
		$SCRIPTDIR = GetScriptDir();
		WriteLog('HandleNotFound: $SCRIPTDIR = ' . $SCRIPTDIR);

		if (preg_match('/^\/[a-f0-9]{2}\/[a-f0-9]{2}\/([a-f0-9]{8})/', $path, $itemHashMatch)) {
			# Item URL in the form: /ab/01/ab01cd23.html
			WriteLog('HandleNotFound: found item hash');
			$itemHash = $itemHashMatch[1];
			$pagesPlArgument = $itemHash;
		}
		if (preg_match('/^\/author\/([A-F0-9]{16})/', $path, $itemHashMatch)) {
			WriteLog('HandleNotFound: found author fingerprint');
			$authorFingerprint = $itemHashMatch[1];
			$pagesPlArgument = $authorFingerprint;
		}
		if (preg_match('/^\/top\/([a-zA-Z0-9]+)\.html/', $path, $hashTagMatch)) {
			WriteLog('HandleNotFound: found hashtag');
			$hashTag = $hashTagMatch[1];
			$pagesPlArgument = '\#' . $hashTag;
		}
		if (
			$path == '/' ||
			$path == '/index.html' ||
			$path == '/read.html' ||
			$path == '/upload.html' ||
			$path == '/upload_multi.html' ||
			$path == '/profile.html' ||
			$path == '/etc.html' ||
			$path == '/events.html' ||
			$path == '/settings.html' ||
			$path == '/help.html' ||
			$path == '/search.html' ||
			$path == '/manual.html' ||
			$path == '/manual_advanced.html' ||
			$path == '/index0.html' ||
			$path == '/stats.html' ||
			$path == '/frame.html' ||
			$path == '/frame2.html' ||
			$path == '/frame3.html' ||
			$path == '/crypto.js' ||
			$path == '/crypto2.js' ||
			$path == '/openpgp.js'
		) {
			WriteLog('HandleNotFound: found a summary page');
			$pagesPlArgument = '--summary';
		}

		if (
			$path == '/authors.html'
		) {
			WriteLog('HandleNotFound: found authors page');
			$pagesPlArgument = '-M scores';
		}

		if (
			$path == '/data.html' ||
			$path == '/txt.zip' ||
			$path == '/index.sqlite3.zip'
		) {
			WriteLog('HandleNotFound: found data page');
			$pagesPlArgument = '--data';
		}

		if (
			$path == '/write.html' ||
			$path == '/write_post.html'
		) {
			WriteLog('HandleNotFound: found write page');
			$pagesPlArgument = '--write';
		}

		if (
			$path == '/tags.html' ||
			$path == '/votes.html'
		) {
			WriteLog('HandleNotFound: found tags page');
			$pagesPlArgument = '--tags';
		}

		if (isset($pagesPlArgument) && $pagesPlArgument) {
			# here we will issue a pages.pl call but first
			# we will check if it's been done in last 60s because
			# we want to keep from calling it too often, for example
			# in a case when the call does not result in
			# the page being built for whatever reason

			$mostRecentCacheName = 'pages/' . md5($pagesPlArgument);
			$mostRecentCall = intval(GetConfig($mostRecentCacheName));

			if (time() - $mostRecentCall > 60) {
				WriteLog('HandleNotFound: pages.pl was called more than 60 seconds ago, trying to grow page');
				# call pages.pl to generate the page
				$pwd = getcwd();
				WriteLog('$pwd = ' . $pwd);

				WriteLog("HandleNotFound: cd $SCRIPTDIR ; ./pages.pl $pagesPlArgument");
				WriteLog(`cd $SCRIPTDIR ; ./pages.pl $pagesPlArgument`);

				WriteLog("HandleNotFound: cd $pwd");
				WriteLog(`cd $pwd`);

				PutCache($mostRecentCacheName, time());
			} else {
				WriteLog('HandleNotFound: warning: pages.pl was called LESS THAN 60 seconds ago, NOT trying to grow page');
			}
		}

		$pathRel = '.' . $path; // relative path of $path (to current directory, which should be html/)

		if ($pathRel && file_exists($pathRel)) {
			WriteLog('HandleNotFound: $pathRel exist: ' . $pathRel);
			$html = file_get_contents($pathRel);
		}
	}

	if (!isset($html) || !$html) {
		// don't know how to handle this request, default to 404
		WriteLog('HandleNotFound: no $html');
		if (file_exists('404.html')) {
			$html = file_get_contents('404.html');
			header("HTTP/1.0 404 Not Found");
		}
	}

	if (!isset($html) || !$html) {
		// something strange happened, and $html is still blank
		// evidently, 404.html didn't work, just use some hard-coded html
		WriteLog('HandleNotFound: warning: 404.html missing, fallback');
		$html = '<html>'.
			'<head><title>404</title></head>'.
			'<body><h1>404 Message Received</h1><p>Something went wrong, please try again later. Thank you.</body>'.
			'</html>';
	}

	return $html;
} # HandleNotFound()

if (GetConfig('admin/php/route_enable')) {
// admin/php/route_enable is true
	$redirectUrl = '';
	if ($_GET) {
		// there is a get request
		WriteLog('route.php: $_GET = ' . print_r($_GET, 1));

		if (isset($_GET['path'])) {
			$serverResponse = '';

			// get request includes path argument
			$path = $_GET['path'];
			WriteLog('$path = ' . $path);
			$pathFull = realpath('.'.$path);

			WriteLog('route.php: $pathFull = ' . $pathFull);

			if ($path == '/profile.html') {
				// if profile, leave it alone
				// otherwise, below is for forcing login
			} else {
				// if registration is required, redirect user to profile.html
				if (GetConfig('admin/force_profile')) {
					$clientHasCookie = 0;
					if (isset($_COOKIE)) {
						if (isset($_COOKIE['cookie'])) {
							$clientHasCookie = 1;
						}
					}

					if (!$clientHasCookie) {
						RedirectWithResponse('/profile.html', 'Please create profile to continue.');
						if (! GetConfig('admin/force_profile_fallthrough')) {
							exit;
						}
					}
				}
			}

			$pathSelf = $_SERVER['PHP_SELF'];
			$pathSelfReal = realpath('.'.$pathSelf);
			$pathValidRoot = substr($pathSelfReal, 0, strlen($pathSelfReal) - strlen($pathSelf));

			WriteLog('$pathValidRoot = ' . $pathValidRoot . ';');
			WriteLog('$pathFull = ' . $pathFull . ';');
			WriteLog('substr($pathFull, 0, strlen($pathValidRoot)) = ' . substr($pathFull, 0, strlen($pathValidRoot)) . ';');

			if ($path == '/404.html' || $pathFull && substr($pathFull, 0, strlen($pathValidRoot)) == $pathValidRoot) {
				// mitigate directory traversal?

				WriteLog('$path = "' . $path . '"');
				if ($path) {
					$pathRel = '.' . $path; // relative path of $path (to current directory, which should be html/)
					if ($path != '/404.html' && file_exists($pathRel)) {
						WriteLog("file_exists($pathRel) was true");

						if (isset($_GET['txtClock'])) {
							$_GET['message'] = 'test';
							WriteLog('setting message = test');
						}

						if (
							isset($_GET['message'])
						)
						{
							WriteLog('$_GET[message] exists');
							$messageId = $_GET['message'];

							if ($messageId == 'test') {
								$testMessage = '
									Over the firewall,
									out the antenna,
									into the router,
									shot to the modem,
									out the transponder,
									bounce into space,
									off the satellite,
									over their firewall,
									into the forums ....
									nothing but NET
								';

								RedirectWithResponse($path, $testMessage);
							}

							if (preg_match('/^[a-f0-9]{8}$/', $messageId)) {
								WriteLog('route.php: Found $messageId which is [a-f0-9]{8}');

								$serverResponse = RetrieveServerResponse($messageId);
								$serverResponse = trim($serverResponse);
							} else {
								WriteLog('route.php: NOT Found $messageId which is [a-f0-9]{8}');
							}

							if (!$serverResponse && !$redirectUrl) {
								$redirectUrl = $path;
							}
						} else {
							WriteLog('$_GET[message] NOT set');
						}

						if (
							isset($_GET['optTheme']) &&
							isset($_GET['btnSetTheme'])
						)
						{
							WriteLog('Theme change requested');

							$newTheme = $_GET['optTheme'];
							$themeUpdateFile = '#config html/theme ' . $newTheme;

							// write file
							// server sign
							// call processor

							//
							// this quick hack doesn't work yet for lack of PutConfig() in php code
							//
							//PutConfig('html/theme', $newTheme);
							//file_put_contents('../config/html/theme', $newTheme);
							//

							if (GetConfig('theme/' . $newTheme . '/additional.css')) {
								//file_put_contents('../config/html/theme', $newTheme);
							}

							$responseThemeChanged = RedirectWithResponse('/settings.html', 'Requested theme change: ' . $newTheme);
						}

						//						if (!isset($_SERVER['PHP_AUTH_USER'])) {
						////							header('WWW-Authenticate: Basic realm="My Realm"');
						////							header('HTTP/1.0 401 Unauthorized');
						//							echo 'Text to send if user hits Cancel button';
						//							exit;
						//						} else {
						//							echo "<p>Hello {$_SERVER['PHP_AUTH_USER']}.</p>";
						//							echo "<p>You entered {$_SERVER['PHP_AUTH_PW']} as your password.</p>";
						//						}

						if (
							isset($_GET['chkUpgrade']) &&
							isset($_GET['btnUpgrade'])
						) {
							WriteLog('Upgrade requested');
							//#todo check cookie for admin?
							DoUpgrade();
							RedirectWithResponse('/stats.html', 'Upgrade complete. Press Update to re-import content.');
						}

						if (
							isset($_GET['chkFlush']) &&
							isset($_GET['btnFlush'])
						) {
							WriteLog('Flush requested');
							DoFlush();
							DoUpdate();
							RedirectWithResponse('/settings.html', 'Previous content has been archived.');
						}

						if (
							isset($_GET['chkOverthrow']) &&
							isset($_GET['btnOverthrow'])
						) {
							WriteLog('Overthrow requested');
							if (GetConfig('admin/allow_deop')) {
								$overthrowInterval = GetConfig('admin/overthrow_interval');
								if (!$overthrowInterval) {
									$overthrowInterval = 1;
								}
								$currentTime = time();
								$lastAction = intval(GetConfig('admin/latest_admin_action'));

								if ($currentTime - $lastAction > $overthrowInterval) {
									WriteLog('Overthrow conditions met');
									PutConfig('admin/latest_admin_action', 0);
									if (file_exists('../admin.key')) {
										#todo this stuff should be somewhere else
										unlink('../admin.key');
										MakePage('--summary');
										WriteLog('Overthrow successful');
										RedirectWithResponse('/settings.html', 'Register to become operator.');
									} else {
										WriteLog('Overthrow already in effect: admin.key missing');
										RedirectWithResponse('/settings.html', 'Register to become operator.');
									}
								} else {
									WriteLog('Overthrow conditions not met, unsuccessful');
									RedirectWithResponse('/settings.html', 'Conditions not met. This incident will be reported.');
								}
							} else {
								WriteLog('Overthrow conditions not met');
							}
						}

						// user asked for a particular file, and that's what we'll give them
						WriteLog('$html = file_get_contents($pathRel);');
						$html = file_get_contents($pathRel);

						if (index($html, 'This page looks plain because formatter is still catching up.') != -1) {
						// this special string appears in placeholder file generated by post.php
						// if string is found, try to call pages.pl to generate file again
						// the file is removed first... this is sub-optimal, but works for now
							WriteLog('route.php: found placeholder page, trying to replace it. $path = .' . $path);
							#unlink('.' . $path);
							$newHtml = HandleNotFound($path, $pathRel); // could be better done by rebuilding the page directly?
							if ($newHtml) {
								$html = $newHtml;
							}
						}

						if (GetConfig('admin/js/enable') && GetConfig('admin/js/fresh')) {
							// because javascript cannot access the page's headers
							// we will put the ETag value at the end of the page
							// as window.myOwnETag
							// this allows the script to compare it to the ETag value
							// returned by the server when requesting HEAD for current page
							// fresh_js fresh.js
							if (index($html, 'CheckIfFresh()') > -1) {
								// only need to do it if the script is included in page
								$md5 = md5_file($pathRel);
								header('ETag: ' . $md5);
								$html .= "<script><!-- window.myOwnETag = '$md5'; // --></script>";
								// #todo this should probably be templated and added using InjectJs()
							}
						}

						//if ($path == '/settings.html') {
							$noCacheFormElement = '<input type=hidden name=timestamp value=' . time() . '>';
							$html = str_ireplace('</form>', $noCacheFormElement . '</form>' , $html);
						//}

						if ($path == '/write.html') {
							if (file_exists('write.php')) {
								include('write.php');

								if (isset($_GET['name']) && $_GET['name']) {
									WriteLog('name request found');

									$nameValue = $_GET['name'];

									WriteLog('$nameValue = ' . $nameValue);

									// #todo validate $vouchValue
									$nameToken =
										'my name is ' . htmlspecialchars($nameValue) .
										"\n" .
										"\n" .
										"I like to ...\n\n"
									;

									WriteLog('$nameToken = ' . $nameToken);

									$html = str_ireplace('</textarea>', $nameToken . '</textarea>' , $html);
								} else {
									WriteLog('my name is request not found');
								}
							}
						}
					} else {
						WriteLog('$path not found, using HandleNotFound(' . $path . ',' . $pathRel . ')');
						$html = HandleNotFound($path, $pathRel);
					}
				} else {
					// no $path
					WriteLog('$path not specified, using HandleNotFound()');
					$html = HandleNotFound($path, '');
				}
			// if ($path == '/404.html' || $pathFull && substr($pathFull, 0, strlen($pathValidRoot)) == $pathValidRoot)
			} else {
				// #todo when does this actually happen?
				// smarter 404 handler
				WriteLog('smarter 404 handler... activate!');
				WriteLog('$path not found, using HandleNotFound()');
				$html = HandleNotFound($path, '');
			}
		} else {
			WriteLog('no $path specified in GET');
			$html = HandleNotFound($path, $pathRel);
		}

		if (GetConfig('html/clock')) {
			WriteLog('calling SetHtmlClock()');
			$html = SetHtmlClock($html);
		}

		if ($path == '/jstest1.html' && GetConfig('admin/js/enable')) {
			WriteLog('inject $userAgentValue into /jstest1.html');
			$userAgentValue = $_SERVER['HTTP_USER_AGENT'];
			$userAgentValue = htmlspecialchars($userAgentValue);
			$html = AddAttributeToTag($html, 'input name=txtNetworkUserAgent', 'value', $userAgentValue);
		} else {
			WriteLog('xxx $path = ' . $path . '; admin/js/enable = ' . GetConfig('admin/js/enable'));
		}

		if (isset($_GET['mode'])) {
			if ($_GET['mode'] == 'light') {
				$_GET['light'] = 1;
			}
		}

		if (isset($_GET['light'])) {
			// user is requesting to change light mode state

			$lightMode = $_GET['light'] ? 1 : 0; // normalize the request

			if (isset($_COOKIE['light'])) {
				// if there is a cookie, change its value if it's necessary

				if ($_COOKIE['light'] != $lightMode) {
					setcookie2('light', $lightMode);

					//$lightModeSetMessage = StoreServerResponse('Light mode has been set to ' . $lightMode);
					//$redirectUrl = '';
				}
			} else {
				// if there is no cookie set, set it

				setcookie2('light', $lightMode);
			}
		} else {
			// no requests for light mode change, check if there is a cookie

			if (isset($_COOKIE['light'])) {
				// cookie is set
				$lightMode = $_COOKIE['light'] ? 1 : 0;
			} else {
				// use light mode default from config
				$lightMode = GetConfig('admin/php/light_mode_default') ? 1 : 0;
			}
		}

		if (GetConfig('admin/php/light_mode_always_on')) {
			$lightMode = 1;
		}

		if ($_GET && isset($_GET['theme'])) {
			$themeMode = $_GET['theme']; // normalize the request
			if ($themeMode != 'chicago') {
				$themeMode = '';
			}
			if (isset($_COOKIE['theme'])) {
				// if there is a cookie, change its value if it's necessary
				if ($_COOKIE['theme'] != $themeMode) {
					setcookie2('theme', $themeMode);
					//$lightModeSetMessage = StoreServerResponse('Light mode has been set to ' . $lightMode);
					//$redirectUrl = '';
				}
			} else {
				// if there is no cookie set, set it
				setcookie2('theme', $themeMode);
			}
		}

		if ($serverResponse) {
			WriteLog('$serverResponse set');
		}

		if ($serverResponse) {
			// inject server message into html

			// base template for server message, not including js
			$serverResponseTemplate = GetTemplate('server_response.template');

			if (GetConfig('admin/js/enable')) {
				// add javascript call to close server response message
				// for the entire server response message table
				$serverResponseTemplate = AddAttributeToTag(
					$serverResponseTemplate,
					'table',
					'onclick',
					"if (window.serverResponseOk) { return serverResponseOk(this); }"
				);
			}

			// fill in the theme color for $colorHighlightAlert
			$colorHighlightAlert = GetThemeColor('highlight_alert');
			$serverResponseTemplate = str_replace('$colorHighlightAlert', $colorHighlightAlert, $serverResponseTemplate);

			// inject the message text itself.
			// no escaping, because it can contain html formatting
			$serverResponseTemplate = str_replace('$serverResponse', $serverResponse, $serverResponseTemplate);

			$messageInjected = 0;

			if (isset($_GET['anchorto']) && $_GET['anchorto']) {
				// anchorto means we can add a # to the "Thanks" link which goes straight to the relevant item

				$anchorTo = $_GET['anchorto'];

				if (index($html, "<a name=$anchorTo>") > -1) {
					// same as below, same message applies

					if (GetConfig('admin/js/enable')) {
						// add javascript call to close server response message for the 'thanks' link
						$serverResponseTemplate = AddAttributeToTag(
							$serverResponseTemplate,
							'a href=#maincontent',
							'onclick',
							"if (window.serverResponseOk) { return serverResponseOk(this); } else { return true; }"
						);
					}

					$serverResponseTemplate = str_replace(
						'<a href=#maincontent',
						'<a href="' . $path . '#' . $anchorTo . '"',
						$serverResponseTemplate
					);

					if (!$lightMode && GetConfig('admin/php/server_response_attach_to_anchor')) {
						WriteLog('server_response_attach_to_anchor');
						// if server_response_attach_to_anchor, we will put the server message next to the anchor
						// unless we are in light mode, because then we want the message at the top of the page

						$replaceWhat = "<a name=$anchorTo>";
						$replaceWith = "<a name=$anchorTo>" . $serverResponseTemplate;
						$html = str_replace($replaceWhat, $replaceWith, $html);

						$messageInjected = 1;
					}
				}
			}

			if (!$messageInjected) {
				// put the current file's path in the "OK" link for nojs browsers
				// this is a compromise, because it causes a page reload, which may be slow
				// the other option is to leave it as is, but the message will remain on
				// the page instead of disappearing, which doesn't look nearly as cool
				// perhaps to be conditional under html/cool_effects?
				$serverResponseTemplate = str_replace('<a href=#maincontent', '<a href="' . $path . '"', $serverResponseTemplate);

				// inject server message right after the body tag
				$replaceWhat = '(<body\s[^>]*>|<body>)'; // both with attributes or without
				$replaceWith = '$0' . $serverResponseTemplate; // the $0 is the original body tag, which we want to retain
				$html = preg_replace($replaceWhat, $replaceWith, $html);

				$messageInjected = 1;
			}

			if (GetConfig('admin/js/enable')) {
				//javascript stuff, if javascript is enabled

				// inject server_response.js for hiding the server message popup
				$html = InjectJs($html, array('server_response'), 'before', '</head>');

				// add onkeydown event to body tag, which responds to escape key
				// known issue: if there's non-32 whitespace, this may not work right
				$replaceWith = '<body onkeydown="if (event.keyCode && event.keyCode == 27) { if (window.bodyEscPress) { return bodyEscPress(); } }"';

				$replaceWhat = '<body ';
				$html = str_replace($replaceWhat, $replaceWith . ' ', $html);
				$replaceWhat = '<body>';
				$html = str_replace($replaceWhat, $replaceWith . '>', $html);
			}

			if ($messageInjected) {
				// ask browser to not cache page if it contains server response
				header('Pragma: no-cache');
			}
		}

		if ($redirectUrl) {
			// if we've come up with a place to redirect to, do it now

			//header('Location: ' . $redirectUrl);
		}

		if ($path == '/profile.html') {
			// special handling for /profile.html
			WriteLog('route.php: /profile.html');

			// we need cookies
			include_once('cookie.php');

			$handle = ''; // will store our handle
			$fingerprint = ''; // will store our fingerprint

			if (isset($cookie) && $cookie) {
				$fingerprint = $cookie;

				if (!$handle && GetConfig('admin/php/alias_lookup')) {
					$handle = GetAlias($fingerprint);
				} else {
					$handle = 'Guest';
				}

				// $html = str_replace('<span id=spanSignedInStatus></span>', '<span id=spanSignedInStatus class=beginner><p><b>Status: You are signed in</b></p></span>', $html);
				// #todo get this from template
				// #todo add the same logic to javascript frontend
			} else {
				$fingerprint = '(not signed in)';
				$handle = '(not signed in)';
			}

			$html = str_replace('<span id=lblHandle></span>', "<span id=lblHandle>$handle</span>", $html);
			$html = str_replace('<span id=lblFingerprint></span>', "<span id=lblFingerprint>$fingerprint</span>", $html);

			if (isset($cookie) && $cookie) {
				if (GetConfig('admin/js/enable')) {
					$html = str_replace('<span id=spanProfileLink></span>', '<span id=spanProfileLink><p><a href="/author/' . $cookie . '/index.html" onclick="if (window.sharePubKey) { return sharePubKey(this); }">Profile</a></p></span>', $html);
				} else {
					$html = str_replace('<span id=spanProfileLink></span>', '<span id=spanProfileLink><p><a href="/author/' . $cookie . '/index.html">Profile</a></p></span>', $html);
				}
			}
		}

		if (function_exists('WriteLog') && GetConfig('admin/php/debug')) {
			$html = str_replace('</body>', '<p class=advanced>' . WriteLog(0) . '</p></body>', $html);
		}

		if (GetConfig('html/clock')) {
			//$html = preg_replace('/id=txtClock value=\".+\"/', 'id=txtClock value="' . GetClockFormattedTime() . '"', $html);
			$html = SetHtmlClock($html);
		}

		if (GetConfig('admin/php/footer_stats') && file_exists('stats-footer.html')) {
			# footer stats
			if ($path == '/keyboard.html' || $path == '/keyboard_netscape.html' || $path == '/keyboard_android.html') {
				# no footer for the keyboard pages, because they are displayed in a thin frame at bottom of page
			} else {
				// footer stats
				$html = str_replace(
					'</body>',
					'<br>' . file_get_contents('stats-footer.html') . '</body>',
					$html
				);
			}

		} // footer stats

		if ($lightMode) {
			// light mode
			WriteLog('route.php: $lightMode is true!');

			$html = StripComments($html);
			$html = StripWhitespace($html);
			$html = CleanBodyTag($html);
			$html = StripHeavyTags($html);
			$html = TranslateEmoji($html);

			if (function_exists('mb_convert_encoding')) {
				$html = mb_convert_encoding($html, 'UTF-8', 'US-ASCII');
			} else {
				WriteLog('route.php: warning: mb_convert_encoding was missing');
			}

			$pathSelf = $_SERVER['REQUEST_URI'];
			if (! (strpos($pathSelf, '?') === false)) {
				$pathSelf = substr($pathSelf, 0, strpos($pathSelf, '?'));
			}

			//			$html = str_replace(
			//				'</body>',
			//				'<p>(Using site in lightweight mode. If you want, <a href="' . $pathSelf . '?light=0">switch to full mode</a>.)</p></body>',
			//				$html
			//			);
			$html = str_replace(
				'>Accessibility mode<',
				'><font color=orange>Light Mode is ON</font><',
				$html
			);
			$html = str_replace(
				'>Turn On<',
				'>Is ON<',
				$html
			);
			//
			//	$html = str_replace(
			//		'<main id=maincontent>',
			//		'<p>(Using site in lightweight mode. If you want, <a href="' . $pathSelf . '?light=0">switch to full mode</a>.)</p><main id=maincontent>',
			//		$html
			//	);

			//#todo perhaps strip onclick, onkeypress, etc., and style
		} else {
			$html = str_replace(
				'>Turn Off<',
				'>Is OFF<',
				$html
			);
		} // light mode

		if (
			GetConfig('admin/php/assist_show_advanced') &&
			(
				isset($_COOKIE['show_advanced']) &&
				$_COOKIE['show_advanced'] == '0'
			)
		) {
			// insert additional style rule at </head>
			// which sets class=advanced elements to display:none
			// if user has respective cookie set
			// to prevent jumpies when page loads

			WriteLog('route.php: ShowAdvanced() assist activated');
			WriteLog('route.php: $_COOKIE[show_advanced] = ' . $_COOKIE['show_advanced']);
			
			$html = str_replace(
				'</head>',
				"<!-- php/assist_show_advanced -->\n".
				 	"<style><!--" .
					"\n" .
					".advanced, .admin{ display:none }" .
					"/* assist ShowAdvanced() in pre-hiding elements with class=advanced */" .
					"\n" .
					"--></style>" .
					"</head>",
				$html
			);
			// #todo templatify
		}


		////////////////////////////
		print $html; // final output
		////////////////////////////
	}
} else {
	WriteLog('config/admin/php/route_enable = false');

	// this is a fallback, and shouldn't really be here
	// but it helps compensate for another bug

	//print "oh no! route_enable is false, but route.php was called!";
	if ($_GET['path']) {
		if (file_exists($path)) {
			$html = get_file_contents($path);
		}
		else if (file_exists($path . '.html')) {
			$html = get_file_contents($path . '.html');
			if (GetConfig('admin/php/debug')) {
				$html = str_replace('</body>', WriteLog('') . '</body>', $html);
			}
		}

		if ($html) {
			if (GetConfig('admin/php/debug')) {
				$html = str_replace('</body>', WriteLog('') . '</body>', $html);
			}
			print($html);
		} else {
			print('Technical issue encountered. Please contact maintainer.');
		}
	}
}

if (GetConfig('admin/php/debug')) {
	print WriteLog('');
}
