<?php

//Header('Content-type: text/html');

function GetScriptDir () { // returns base script directory.
	$scriptDir = '$scriptDirPlaceholderForTemplating';
	// this placeholder is populated by pages.pl when template is written

	if ($scriptDir == '$'.'scriptDirPlaceholderForTemplating') {
		// this is a sanity check to make sure the placeholder was correctly populated
		return;
	}

	if (index($scriptDir, '"') != -1) {
		// $scriptDir contains double-quote, this is bad, as it will break things

		return;
	}

	return $scriptDir;
}

function SqliteEscape ($text) { # Escapes supplied text for use in sqlite query
# Just changes ' to ''
	WriteLog("SqliteEscape($text)");

	if (isset($text)) {
		$text = str_replace("'", "''", $text);
	} else {
		$text = '';
	}

	WriteLog('SqliteEscape: return ' . $text);

	return $text;
}

function SqliteGetValue ($query) { # Returns the first column from the first row returned by sqlite $query
	WriteLog("SqliteGetValue($query)");

	$command = "sqlite3 /home/toshiba/hike/cache/b/index.sqlite3 \"$query\"";
	WriteLog('SqliteGetValue: $command = ' . $command);

	$result = `$command`;
	WriteLog('SqliteGetValue: $result = ' . $result);

	return $result;
}



function DBGetAuthorAlias ($key) { # returns author's alias
// 	if (!IsFingerprint($key)) {
// 		WriteLog('DBGetAuthorAlias: warning: called with invalid parameter! returning');
// 		return;
// 	} #todo re-add this sanity check
	WriteLog("DBGetAuthorAlias($key)");

	$key = SqliteEscape($key);

	if ($key) {
		$query = "SELECT alias FROM author_alias WHERE key = '$key'";
		$returnValue = SqliteGetValue($query);

		WriteLog('DBGetAuthorAlias: $returnValue = ' . $returnValue);

		return $returnValue;
	} else {
		return "";
	}
}


function GetAlias($fingerprint, $noCache = 0) { # ; Returns alias for an identifier
	WriteLog("GetAlias($fingerprint, $noCache)");

	WriteLog('GetAlias: calling DBGetAuthorAlias()');
	$alias = DBGetAuthorAlias($fingerprint);

	if ($alias) {
		$alias = trim($alias);
		if ($alias && length($alias) > 24) {
			$alias = substr($alias, 0, 24);
		}

		return $alias;
	} else {
		$alias = GetConfig('prefill_username');
		return $alias;
	}
} # GetAlias()


function WriteLog ($text, $dontEscape = 0) { // writes to debug log if enabled
// the debug log is stored as a static variable in this function
// when a blank (false) argument is passed, returns entire log as html
// $dontEscape means don't escape html entities
	#file_put_contents('/home/toshiba/hike/log/log.log', time() . ':php:' . $text . "\n", FILE_APPEND);

	static $logText; # stores log
	if (!$logText) {
		# initialize
		$logText = '';
	}
	if (!$text) {
		# return entire log if text is blank
		return $logText;
	}
    if ($dontEscape) {
		$logText .= '<tt class=advanced>' . time() . ':' . $text . "<br></tt>\n";
    } else {
		$logText .= '<tt class=advanced>' . time() . ':' . htmlspecialchars($text) . "<br></tt>\n";
	}
}

//
//function GetRootAdminKey () { // Returns root admin's public key, 0 if there is none
//	static $adminsKey = 0;
//
//	if ($adminsKey) {
//		return $adminsKey;
//	}
//
//	$pwd = getcwd();
//
//	WriteLog('$pwd = ' . $pwd);
//
//	$scriptDir = substr($pwd, 0, strlen($pwd) - 5); // trim html/
//
//	if (file_exists("$scriptDir/admin.key")) {
//
//		$adminsInfo = GpgParse("$scriptDir/admin.key");
//
//		if ($adminsInfo['isSigned']) {
//			if ($adminsInfo['key']) {
//				$adminsKey = $adminsInfo['key'];
//
//				return $adminsKey;
//			} else {
//				return 0;
//			}
//		} else {
//			return 0;
//		}
//	} else {
//		return 0;
//	}
//
//	return 0;
//}


function GetMyCacheVersion () { // returns current cache version
	$myCacheVersion = 'b';
	return $myCacheVersion;
}

function GetMyVersion () { // returns current git commit id
// it is cached in config/admin/my_version
// otherwise it's looked up with: git rev-parse HEAD
	WriteLog('GetMyVersion()');
	static $myVersion; // store version for future lookups here
	if ($myVersion) {
		WriteLog('GetMyVersion: return from static: ' . $myVersion);
		return $myVersion;
	}

	$myVersion = GetConfig('admin/my_version');
	if (!$myVersion) {
		WriteLog('GetMyVersion: git rev-parse HEAD... ');
		$myVersion = `git rev-parse HEAD`;
		WriteLog('GetMyVersion: got ' . $myVersion);

		//save to config so that we don't have to call git next time
		//PutConfig('admin/my_version', $myVersion);
		PutConfig('admin/my_version', $myVersion);
	}

	$myVersion = trim($myVersion);
	return $myVersion;
}

function index ($string, $needle) { // emulates perl's index(), returning -1 when not found
	$strpos = strpos($string, $needle);
	if ($strpos === false) {
		return -1;
	} else {
		return $strpos;
	}
}

function length ($string) { // emulates perl's length()
	return strlen($string);
}

function GpgParsePubkey ($filePath) { // #todo parse file with gpg public key
    return array();
}

function GetFileHash ($fileName) { // returns hash of file contents
// GetItemHash GetHash
	WriteLog("GetFileHash($fileName)");

	if ((strtolower(substr($fileName, length($fileName) - 4, 4)) == '.txt')) {
		$fileContent = GetFile($fileName);

		if (index($fileContent, "\n-- \n") > -1) {
			// exclude signature from hash content
			$fileContent = substr($fileContent, 0, index($fileContent, "\n-- \n"));
		}

		return sha1($fileContent);
	} else {
		return sha1_file($fileName);
	}
}

function file_force_contents ($dir, $contents) { // ensures parent directories exist before writing file
// #todo clean this function up

    WriteLog("file_force_contents($dir, $contents)");

    $parts = explode('/', $dir);
    $file = array_pop($parts);
    $dir = '';

    foreach($parts as $part) {
        if (!is_dir($dir .= "/$part")) {
            mkdir($dir);
        }
    }

    return file_put_contents("$dir/$file", $contents);
}

function DoUpdate () { // #todo #untested
	$pwd = getcwd();

	WriteLog('$pwd = ' . $pwd);

	$scriptDir = GetScriptDir();

	WriteLog('$scriptDir = ' . $scriptDir);

	if (file_exists($scriptDir . '/update.pl')) {
		WriteLog('update.pl found, calling update.pl --all');
		WriteLog('cd "' . $scriptDir . '" ; perl ./update.pl --all');

		WriteLog(`cd "$scriptDir" ; perl ./update.pl --all`);

		WriteLog('cd "' . $pwd . '"');

		WriteLog(`cd "$pwd"`);
	}
}

function DoUpgrade () {
	$pwd = getcwd();
	WriteLog('$pwd = ' . $pwd);
	$scriptDir = GetScriptDir();
	WriteLog('$scriptDir = ' . $scriptDir);

	if (file_exists($scriptDir . '/upgrade.pl')) {
		WriteLog('upgrade.pl found, calling upgrade.pl');
		WriteLog('cd "' . $scriptDir . '" ; perl ./upgrade.pl');

		WriteLog(`cd "$scriptDir" ; perl ./upgrade.pl`);

		WriteLog('cd "' . $pwd . '"');

		WriteLog(`cd "$pwd"`);
	}
}

function DoFlush () {
	$pwd = getcwd();
	WriteLog('$pwd = ' . $pwd);
	$scriptDir = GetScriptDir();
	WriteLog('$scriptDir = ' . $scriptDir);

	if (file_exists($scriptDir . '/query/flush_no_keep.sh')) {
		WriteLog('query/flush_no_keep.sh found, calling query/flush_no_keep.sh');
		WriteLog('cd "' . $scriptDir . '" ; query/flush_no_keep.sh');
		WriteLog(`cd "$scriptDir" ; query/flush_no_keep.sh`);
		WriteLog('cd "' . $pwd . '"');
		WriteLog(`cd "$pwd"`);
	}
// 	if (file_exists($scriptDir . '/archive.pl')) {
// 		WriteLog('archive.pl found, calling archive.pl');
// 		WriteLog('cd "' . $scriptDir . '" ; perl ./archive.pl');
//
// 		WriteLog(`cd "$scriptDir" ; perl ./archive.pl`);
//
// 		WriteLog('cd "' . $pwd . '"');
//
// 		WriteLog(`cd "$pwd"`);
// 	}
}

function PutConfig ($configKey, $configValue) { # writes config value to config storage
# SetConfig {
# PutConfig {
	WriteLog("PutConfig($configKey, $configValue)");
	$configDir = '../config'; // config is stored here #todo unhardcode
	$putFileResult = PutFile("$configDir/$configKey", $configValue);
	GetConfig($configKey, 'unmemo');
	return $putFileResult;
} # PutConfig()

function GetConfig ($configKey, $token = 0) { // get value for config value $configKey
	WriteLog("GetConfig($configKey, $token)");

	// config is stored in config/
	// if not found in config/ it looks in default/
	// if it is in default/, it is copied to config/

// 	// memoize #todo
// 	static $configLookup;
// 	if (!isset($configLookup)) {
// 		$configLookup = array();
// 	}
// 	if ($configKey == 'unmemo') {
// 		// memo reset
// 		$configLookup = array();
// 		return;
// 	}
// 	if ($token == 'unmemo') {
// 		// memo reset
// 		unset($configLookup[$configKey]);
// 		return;
// 	}

	//#todo finish porting from perl
	// 	if ($token && $token eq 'unmemo') {
	// 		WriteLog('GetConfig: unmemo requested, complying');
	// 		# unmemo token to remove memoized value
	// 		if (exists($configLookup{$configName})) {
	// 			delete($configLookup{$configName});
	// 		}
	// 	}
	//
	// 	if (exists($configLookup{$configName})) {
	// 		WriteLog('GetConfig: $configLookup already contains value, returning that...');
	// 		WriteLog('GetConfig: $configLookup{$configName} is ' . $configLookup{$configName});
	//
	// 		return $configLookup{$configName};
	// 	}

	$configDir = '../config'; // config is stored here
	$defaultDir = '../default'; // defaults are stored here
	$pwd = getcwd();

	WriteLog('GetConfig('.$configKey.'); $pwd = "' . $pwd . '", $configDir = "' . $configDir . '", $defaultDir = "' . $defaultDir . '", pwd = "' . getcwd() . '"');
	WriteLog('GetConfig: Checking in ' . $configDir . '/' . $configKey );

	if (file_exists($configDir . '/' . $configKey)) {
		WriteLog('GetConfig: found in config/');
		$configValue = file_get_contents($configDir . '/' . $configKey);
	} elseif (file_exists($defaultDir . '/' . $configKey)) {
		WriteLog('GetConfig: not found in config/, but found in default/');
		WriteLog("GetConfig: copy ($defaultDir/$configKey, $configDir/$configKey);"); // copy to config/
		copy ($defaultDir . '/' . $configKey, $configDir . '/' . $configKey); // copy to config/
		//#todo this copy should be copy_with_dir_creation
		$configValue = file_get_contents($configDir . '/' . $configKey);
	} else {
		// otherwise return empty string
		WriteLog('GetConfig: warning: else, fallthrough, for ' . $configKey);
		$configValue = '';
	}
//
// 	// store in memo
// 	$configLookup[$configKey] = $configValue;

	WriteLog('GetConfig: $configValue: ' . $configValue);
	$configValue = trim($configValue); // remove trailing \n and any other whitespace
	WriteLog('GetConfig: $configValue after trim: ' . $configValue);
	WriteLog('GetConfig("' . $configKey . '") = "' . $configValue . '"), returning');
	// notify log of what we found
	return $configValue;
} // GetConfig()

function GetTemplate ($templateKey) { // get template from config tree
// looks in theme directory first, so config/theme/ > default/theme/ > config/ > default/
    $themeName = GetConfig('html/theme');
    $themePath = 'theme/' . $themeName . '/template/' . $templateKey;

	WriteLog("GetTemplate($templateKey)");

    if (GetConfig($themePath)) {
    	WriteLog("GetTemplate: GetConfig($themePath) was true, returning GetConfig($themePath)");
        return GetConfig($themePath);
    } else {
		WriteLog("GetTemplate: GetConfig($themePath) was FALSE, returning GetConfig(template/$templateKey)");

	    return GetConfig("template/$templateKey");
    }
}

function GetFile ($file) { // gets file contents
	$file = trim($file);

	if (!$file || !file_exists($file)) {
		WriteLog('GetFile: warning: $file was not provided');
		return '';
	}

	return file_get_contents($file);
}

function PutFile ($file, $content) { // puts file contents
	WriteLog("PutFile($file, (\$content)");

	if (index($file, '..') == -1) {
		WriteLog('PutFile: warning: sanity check failed, $file contains ..');
		return '';
	}

	$pathArray = explode('/', $file);
	$filePathComma = '';
	$filePath = '';
	while ($pathArray) {
		WriteLog('PutFile: $pathArray = ' . print_r($pathArray, 1));
		$filePath .= $filePathComma . array_shift($pathArray);
		WriteLog('PutFile: $filePath = ' . $filePath);

		if ($pathArray) {
			if (! file_exists($filePath)) {
				WriteLog("PutFile: mkdir($filePath)");
				mkdir($filePath);
			}
		}

		$filePath .= $filePathComma;
		WriteLog('PutFile: $filePathComma = ' . $filePathComma);
		$filePathComma = '/';
	}


	$putFileResult = file_put_contents($file, $content);
	WriteLog('PutFile: $putFileResult = ' . $putFileResult);
	return $putFileResult;
} # PutFile()

function GetCache ($cacheName) { // get cache contents by key/name
	// comes from cache/ directory, under current git commit
	// this keeps cache version-specific

	static $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	// cache name prefixed by current version
	$cacheName = '../cache/' . $myVersion . '/' . $cacheName;

	if (file_exists($cacheName)) {
		// return contents of file at that path
		return GetFile($cacheName);
	} else {
		return;
	}
}

function PutCache ($cacheName, $content) { // stores value in cache
//#todo sanity checks and error handling
	WriteLog("PutCache($cacheName, $content)");

	static $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = '../cache/' . $myVersion . '/' . $cacheName;

	WriteLog('PutCache: $cacheName = ' . $cacheName);

	return PutFile($cacheName, $content);
}

function UnlinkCache ($cacheName) { // removes cache by unlinking file it's stored in
	static $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = '../cache/' . $myVersion . '/' . $cacheName;

	if (file_exists($cacheName)) {
		unlink($cacheName);
	}
}

function CacheExists ($cacheName) { // Check whether specified cache entry exists, return 1 (exists) or 0 (not)
	static $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = '../cache/' . $myVersion . '/' . $cacheName;

	if (file_exists($cacheName)) {
		return 1;
	} else {
		return 0;
	}
}

function StoreServerResponse ($message) { // adds server response message and returns message id
// stores message in cache/sm[message_id]
// returns message id which can be passed to next page load via ?message= parameter
	WriteLog("StoreServerResponse($message)");
	$message = trim($message);
    if ($message == '') {
    	return;
    }

    $messageId = md5($message . time() . rand());
    $messageId = substr($messageId, 0, 8);

	PutCache('response/' . $messageId, $message);
	WriteLog("StoreServerResponse: $messageId, cache written");
	return $messageId;
} # StoreServerResponse()

function RetrieveServerResponse ($messageId) { // retrieves response message for display by client and deletes it
	WriteLog("RetrieveServerResponse($messageId)");
	$message = GetCache('response/' . $messageId);
	if ($message) {
		if (!GetConfig('admin/php/debug')) {
			WriteLog("RetrieveServerResponse: Message found, removing.");
			// message was found, remove it
			// remove stored message if not in debug mode
			UnlinkCache('response/' . $messageId);
		} else {
			WriteLog("RetrieveServerResponse: Message found, not deleting because debug mode.");
		}
	} else {
		WriteLog('RetrieveServerResponse: warning: message not found!');
	}
	return $message;
} # RetrieveServerResponse()

function GetHtmlFilename ($hash) { // gets html filename based on hash
	// path for new html file
	$fileHtmlPath =
		substr($hash, 0, 2) .
		'/' .
		substr($hash, 2, 2) .
		'/' .
		substr($hash, 0, 8) .
		'.html'
	;

	return $fileHtmlPath;
}

function RedirectWithResponse ($url, $message) { // redirects to page with server message parameter added to url
// calls StoreServerResponse($message)
// then creates url with message= parameter
// sends Location: header to redirect to said url

	WriteLog("RedirectWithResponse($url, $message)");

	// should only redirect once per session
	static $redirected;
	if (isset($redirected) && $redirected > 0) {
		WriteLog('RedirectWithResponse: warning: called more than once!');
		return;
	}
	if (!$redirected) {
		$redirected = 1;
	} else {
		$redirected++;
	}

	if (headers_sent()) {
		// problem, can't redirect if headers already sent;
		// we will print a message instead, but this is definitely a problem

		WriteLog('RedirectWithResponse: warning: Trying to redirect when headers have already been sent!');
	}


	$responseId = StoreServerResponse($message);

	if (substr($url, 0, 1) == '/') {
	// todo perhaps account for './' also?
		$protocol = 'http';
		if (isset($_SERVER['HTTPS'])) {
			$protocol = 'https';
		}

		if ($_SERVER['HTTP_HOST']) {
			$url = $protocol . '://' . $_SERVER['HTTP_HOST'] . $url;
		}
		elseif (GetConfig('admin/my_domain')) {
			$url = 'http://' . GetConfig('admin/my_domain') . $url;
		}
	}

	if (index($url, '?') < 0) {
		// no question mark, append ?message=
		$redirectUrl = $url . '?message=' . $responseId;
	} else {
		// there's already a question mark, we need to use the & syntax
		if (substr($url, strlen($url) - 1, 1) == '&' || substr($url, strlen($url) - 1, 1) == '?') {
			// query ends with & already, we don't need to add one
			$redirectUrl = $url . 'message=' . $responseId;
		} else {
			// there's no & at the end, so append &message
			$redirectUrl = $url . '&message=' . $responseId;
		}
	}

	if (GetConfig('admin/php/debug') || GetConfig('admin/php/debug_server_response')) {
		if (!headers_sent()) {
			// #warning, this is not a good pattern, don't copy this code. the html will be printed unescaped.
			// doing it in this case because we want to make a clickable link
			WriteLog('<a href="' . $redirectUrl . '">' . $redirectUrl . '</a> <font color=red>(redirect paused because admin/php/debug is true)</font>', 1);

			// #todo template the html
			print '<div style="background-color: yellow"><a href="' . $redirectUrl . '"><b>Continue</b>: ' . $redirectUrl . '</a><br>Message: '.htmlspecialchars($message).'</div><hr>';
		}
	} else {
		// do the redirect
		if (!headers_sent()) {
			if (0 & $message == 'Goodbye!') {
				header('WWW-Authenticate: Basic realm="Goodbye!"');
				header('HTTP/1.0 401 Unauthorized');
			} else {
				header('Location: ' . $redirectUrl);
			}
		} else {
			WriteLog('RedirectWithResponse: warning: wanted to send Location header, but headers already sent');
		}
	}
} # RedirectWithResponse()

function GetWindowTemplate ( # body, title, headings, status, menu
	$windowBody,
	$windowTitle,
	$columnHeadings,
	$windowStatus,
	$windowMenubarContent
) { // returns html for window template
// uses template/window/standard.template by default

	// stores number of columns if they exist
	// if no columns, remains at 0
	// whether there are columns or not determines:
	// * column headers
	// * colspan= in non-column cells
	$contentColumnCount = 0;

	// base template
	$windowTemplate = GetTemplate('window/standard.template');

	// titlebar, if there's a title
	if ($windowTitle) {
		$windowTitlebar = GetTemplate('window/titlebar.template');
		$windowTitlebar = str_replace('$windowTitle', $windowTitle, $windowTitlebar);

		$windowTemplate = str_replace('$windowTitlebar', $windowTitlebar, $windowTemplate);
	} else {
		$windowTemplate = str_replace('$windowTitlebar', '', $windowTemplate);
	}

	// menubar, if there is menubar content
	if ($windowMenubarContent) {
		$windowMenubar = GetTemplate('window/menubar.template');
		$windowMenubar = str_replace('$windowMenubarContent', $windowMenubarContent, $windowMenubar);

		$windowTemplate = str_replace('$windowMenubar', $windowMenubar, $windowTemplate);
	} else {
		$windowTemplate = str_replace('$windowMenubar', '', $windowTemplate);
		//#todo currently results in an empty menubar
	}

	// column headings from the $columnHeadings variable
	if ($columnHeadings) {
		$windowHeaderTemplate = GetTemplate('window/header_wrapper.template');
		$windowHeaderColumns = '';
		$columnsArray = explode(',', $columnHeadings);

		$printedColumnsCount = 0;
		foreach ($columnsArray as $columnCaption) {
			$printedColumnsCount++;

			$columnHeaderTemplate = GetTemplate('window/header_column.template');
			if ($printedColumnsCount >= count($columnsArray)) {
				$columnCaption .= '<br>'; //# for no-table browsers
			}

			$columnHeaderTemplate = str_replace('$headerCaption', $columnCaption, $columnHeaderTemplate);
			$windowHeaderColumns .= $columnHeaderTemplate;
		}

		$windowHeaderTemplate = str_replace('$windowHeadings', $windowHeaderColumns, $windowHeaderTemplate);
		$windowTemplate = str_replace('$windowHeader', $windowHeaderTemplate, $windowTemplate);

		$contentColumnCount = count($columnsArray);
	} else {
		$windowTemplate = str_replace('$windowHeader', '', $windowTemplate);
		$contentColumnCount = 0;
	}

	// main window content, aka body
	if ($windowBody) {
		if (index(strtolower($windowBody), '<tr') == -1) {
			// put content into a table row and cell if missing
			$windowBody = '<tr class=content><td>' . $windowBody . '</td></tr>';
		}

		$windowTemplate = str_replace('$windowBody', $windowBody, $windowTemplate);
	} else {
		$windowTemplate = str_replace('$windowBody', '', $windowTemplate);
	}

	// status bar
	if ($windowStatus) {
		$windowStatusTemplate = GetTemplate('window/status.template');

		$windowStatusTemplate = str_replace('$windowStatus', $windowStatus, $windowStatusTemplate);

		$windowTemplate = str_replace('$windowStatus', $windowStatusTemplate, $windowTemplate);
	} else {
		$windowTemplate = str_replace('$windowStatus', '', $windowTemplate);
	}

	// fill in the column count if necessary
	if ($contentColumnCount) {
		$windowTemplate = str_replace('$contentColumnCount', $contentColumnCount, $windowTemplate);
	} else {
		$windowTemplate = str_replace('$contentColumnCount', '', $windowTemplate);
	}

	return $windowTemplate;
}

function GetThemeAttribute ($attributeName) { // returns theme color from config/theme/...
// uses GetConfig(), which means look first in config/ and then in default/
	$themeName = GetConfig('html/theme');

	$attributePath = 'theme/' . $themeName . '/' . $attributeName;
	//#todo sanity checks

	$attributeValue = GetConfig($attributePath);
	$attributeValue = trim($attributeValue);

	WriteLog('GetThemeAttribute: $attributeName: ' . $attributeName . '; $attributePath: ' . $attributePath . '; $attributeValue: ' . $attributeValue);

	return $attributeValue;
}

function GetThemeColor ($colorName) { // returns theme color based on html/theme
	$colorName = 'color/' . $colorName;
	$color = GetThemeAttribute($colorName);

	if (!$color) {
		$color = '#00ff00';
		WriteLog("GetThemeColor: WARNING: Value for $colorName not found");
	}

	if (preg_match('/^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/', $color)) {
	// color value looks like a 6-digit hex value without a # prefix, so add the prefix
		WriteLog('GetThemeColor: Color found missing its # prefix: ' . $color);

		$color = '#' . $color;

		WriteLog('GetThemeColor: Prefix added: ' . $color);
	} else {
		WriteLog('GetThemeColor: Found nice color: ' . $color);
	}

	WriteLog('GetThemeColor: Returning for ' . $colorName . ': ' . $color);

	return $color;
}

function GetTime () { // returns time()
// why this wrapper? so that we can use a different base for epoch time than 1970-01-01
	return time();
}

function AddAttributeToTag ($html, $tag, $attributeName, $attributeValue) { // adds attr=value to html tag;
	WriteLog('AddAttributeToTag() begin');

	$tagAttribute = '';
	if (preg_match('/\w/', $attributeValue)) {
		WriteLog('AddAttributeToTag: whitespace match true');
		// attribute value contains whitespace, must be enclosed in double quotes
		$tagAttribute = $attributeName . '="' . $attributeValue . '"';
	} else {
		WriteLog('AddAttributeToTag: whitespace match false');
		$tagAttribute = $attributeName . '=' . $attributeValue . '';
	}

	WriteLog('AddAttributeToTag: $tagAttribute is ' . $tagAttribute);

	{ #todo this is sub-optimal, and tag case is not preserved
		$htmlBefore = $html;
		$html = str_ireplace('<' . $tag . ' ', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
		if ($html == $htmlBefore) {
			$html = str_ireplace('<' . $tag . '', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
		}
		if ($html == $htmlBefore) {
			$html = str_ireplace('<' . $tag . '>', '<' . $tag . ' ' . $tagAttribute . '>', $html);
		}
		if ($html == $htmlBefore) {
			$html = str_ireplace('<' . $tag . '>', '<' . $tag . ' ' . $tagAttribute . '>', $html);
		}
		if ($html == $htmlBefore) {
			WriteLog('AddAttributeToTag: warning: nothing was changed');
		}
	}

// 	// #todo this is sub-optimal
// 	$html = preg_replace("/\<$tag\w/i", "<$tag $tagAttribute ", $html);
// 	$html = preg_replace("/\<$tag/i", "<$tag $tagAttribute ", $html); // is this right/necessary? #todo
// 	$html = preg_replace("/\<$tag\>/i", "<$tag $tagAttribute>", $html);

	return $html;
}

function GetClockFormattedTime () { // returns current time in appropriate format from config
//formats supported: union, epoch (default)

	WriteLog("GetClockFormattedTime()");

	$clockFormat = GetConfig('html/clock_format');

	if ($clockFormat == '24hour') {
	    $time = GetTime();

		// #todo make it perl-equivalent with localtime($time)
        $hours = strftime('%H', $time);
        $minutes = strftime('%M', $time);
        // $seconds = strftime('%S', $time);

        // $clockFormattedTime = $hours . ':' . $minutes . ':' . $seconds;
        $clockFormattedTime = $hours . ':' . $minutes;

		WriteLog("GetClockFormattedTime: return $clockFormattedTime");

		return $clockFormattedTime;
    }

	if ($clockFormat == 'union') {
		// union square clock format
		$time = GetTime() - 3600 * 4; // hard-coded correction, should be timezone convert #todo

		// #todo make it perl-equivalent with localtime($time)
		$hours = strftime('%H', $time);
		$minutes = strftime('%M', $time);
		$seconds = strftime('%S', $time);

		$milliseconds = '000';
		$hoursR = 23 - $hours;
		if ($hoursR < 10) {
			$hoursR = '0' . $hoursR;
		}

		$minutesR = 59 - $minutes;
		if ($minutesR < 10) {
			$minutesR = '0' . $minutesR;
		}

		$secondsR = 59 - $seconds;
		if ($secondsR < 10) {
			$secondsR = '0' . $secondsR;
		}

		#
		# if (milliseconds < 10) {
		# 	milliseconds = '00' + '' + milliseconds;
		# } else if (milliseconds < 100) {
		# 	milliseconds = '0' + '' + milliseconds;
		# }
		#

		$clockFormattedTime = $hours . $minutes . $seconds . $milliseconds . $secondsR . $minutesR . $hoursR;

		WriteLog("GetClockFormattedTime: return $clockFormattedTime");

		return $clockFormattedTime;
	}

	// default is epoch

	WriteLog("GetClockFormattedTime: return default, aka epoch, aka GetTime()");

	return GetTime();
}

function IsItem ($string) { # returns 1 if parameter is in item hash format (40 or 8 lowercase hex chars), 0 otherwise
	WriteLog("IsItem($string)");

	if (!$string) {
		WriteLog("IsItem: NO STRING!");
		return 0;
	}

	if (preg_match('/^[0-9a-f]{40}$/', $string)) {
		WriteLog("IsItem: matched 40 chars");
		return 1;
	}

	if (preg_match('/^[0-9a-f]{8}$/', $string)) {
		WriteLog("IsItem: matched 8 chars");
		return 1;
	}

	WriteLog("IsItem: NO MATCH!");
	return 0;
}

function setcookie2 ($key, $value) { // sets cookie with ie3 compatibility
	WriteLog('setcookie2(' . $key . ',' . $value . ')');

	$cookieDateFormat = "D, d-M-Y H:i:s";
	$cookieDate = date($cookieDateFormat, time() + 86400*2*365) . ' GMT';
	// timezone hard-coding is not important here

	Header('Set-Cookie: ' . $key . '=' . $value . '; expires=' . $cookieDate . '; path=/', false);
}

function unsetcookie2 ($key) { // remove cookie in most compatible way
	WriteLog('unsetcookie2(' . $key . ')');

	Header("Set-Cookie: $key=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/", false);
}

function IndexTextFile ($filePath) {
	$scriptDir = GetScriptDir();
	$pwd = getcwd();

	WriteLog("cd $scriptDir ; ./index.pl \"$filePath\"");
	WriteLog(`cd $scriptDir ; ./index.pl "$filePath"`);

	if ($pwd) {
		WriteLog("cd $pwd");
		WriteLog(`cd $pwd`);
	}
//
// 	WriteLog("cd $scriptDir ; ./pages.pl \"$hash\"");
// 	WriteLog(`cd $scriptDir ; ./pages.pl "$hash"`);
} // IndexTextFile()

function MakePage ($pageName) {
	#todo sanity checks
	$scriptDir = GetScriptDir();
	$pwd = getcwd();

	WriteLog("cd $scriptDir ; ./pages.pl \"$pageName\"");
	WriteLog(`cd $scriptDir ; ./pages.pl "$pageName"`);

	if ($pwd) {
		WriteLog("cd $pwd");
		WriteLog(`cd $pwd`);
	}
//
// 	WriteLog("cd $scriptDir ; ./pages.pl \"$hash\"");
// 	WriteLog(`cd $scriptDir ; ./pages.pl "$hash"`);
} // IndexNewFile()

function ProcessNewComment ($comment, $replyTo) { // saves new comment to .txt file and calls indexer
	$hash = ''; // hash of new comment's contents
	$fileUrlPath = ''; // path file should be stored in based on $hash
	$scriptDir = GetScriptDir();

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


		$fileHtmlPath = './' . GetHtmlFilename($hash); // path for new html file
		$fileUrlPath = '/' . GetHtmlFilename($hash); // client's (browser's) path to html file
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
	} # isset($comment) && $comment

	if (GetConfig('admin/php/post/index_file_on_post')) {
		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}

		WriteLog("cd $scriptDir ; ./index.pl \"$filePath\"");
		WriteLog(`cd $scriptDir ; ./index.pl "$filePath"`);

		WriteLog("cd $scriptDir ; ./pages.pl \"$hash\"");
		WriteLog(`cd $scriptDir ; ./pages.pl "$hash"`);

		if (isset($replyTo) && $replyTo) {
			WriteLog("\$replyTo = $replyTo");
			if (IsItem($replyTo)) {
				WriteLog("cd $scriptDir ; ./pages.pl \"$replyTo\"");
				WriteLog(`cd $scriptDir ; ./pages.pl "$replyTo"`);
			}
		} else {
			WriteLog("\$replyTo not found");
		}

		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}


	} # index_file_on_post

	if (GetConfig('admin/php/post/update_item_on_post')) {
		WriteLog('ProcessNewComment: admin/php/post/update_item_on_post is TRUE');

		WriteLog("cd $scriptDir ; ./update.pl \"$filePath\"");
		WriteLog(`cd $scriptDir ; ./update.pl "$filePath"`);

		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}

		if (isset($replyTo) && $replyTo) {
			WriteLog("\$replyTo = $replyTo");
			if (IsItem($replyTo)) {
				WriteLog("cd $scriptDir ; ./pages.pl \"$replyTo\"");
				WriteLog(`cd $scriptDir ; ./pages.pl "$replyTo"`);

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

		WriteLog("cd $scriptDir ; ./update.pl --all");
		WriteLog(`cd $scriptDir ; ./update.pl --all`);

		if ($pwd) {
			WriteLog("cd $pwd");
			WriteLog(`cd $pwd`);
		}
	} else {
		WriteLog('ProcessNewComment: admin/php/post/update_all_on_post is FALSE');

		if (GetConfig('admin/php/post/update_on_post')) {
			WriteLog('ProcessNewComment: admin/php/post/update_on_post is TRUE');

			WriteLog("cd $scriptDir ; ./update.pl");
			WriteLog(`cd $scriptDir ; ./update.pl`);

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
