#!/usr/bin/perl -T
$ENV{PATH}="/bin:/usr/bin";

use strict;
use warnings;
use utf8;
use 5.010;
use POSIX;
use POSIX 'strftime';
use Data::Dumper;
use Cwd qw(cwd);
use Digest::MD5 qw(md5_hex);

#use Devel::StackTrace;

use File::Basename qw( fileparse );
use File::Spec;

use Date::Parse;

use lib 'lib';

use URI::Encode qw(uri_decode);
use URI::Escape;
#use HTML::Entities qw(encode_entities);
use Storable;
#use Time::Piece;
use Digest::SHA qw(sha1_hex);

sub require_once { # $path ; use require() unless already done
	my $path = shift;
	chomp $path;

	if (!$path) {
		WriteLog('require_once: warning sanity check failed');
		return '';
	}

	state %state;

	if (defined($state{$path})) {
		WriteLog('require_once: already required: ' . $path);
		return '';
	}

	if (!-e $path) {
		WriteLog('require_once: sanity check failed, no $path = ' . $path);
		return '';
	}

	require $path;
	$state{$path} = 1;
	
	return 1;
} # require_once()

sub GetDir {
	my $dirName = shift;
	if (!$dirName) {
		return;
	}
	my $scriptDir = cwd();
	if ($dirName eq 'html') {
		return $scriptDir . '/html';
	}
}

my $SCRIPTDIR = cwd();
if (!$SCRIPTDIR) {
	die ('Sanity check failed: $SCRIPTDIR is false!');
}

sub GetMyCacheVersion {
	return 'b';
}

my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/txt';
my $CACHEDIR = $SCRIPTDIR . '/cache/' . GetMyCacheVersion();

{
	# make a list of some directories that need to exist
	my @dirsThatShouldExist = (
		"log",
		"$HTMLDIR",
		"$HTMLDIR/txt",
		"$HTMLDIR/image",
		"$HTMLDIR/thumb", #thumbnails
		"cache", #ephemeral data
		"$HTMLDIR/author",
		"$HTMLDIR/action",
		"$HTMLDIR/top", #top items for tags
		"config",
		"config/admin",
		"config/admin/php",
		"config/admin/php/post",
		"$HTMLDIR/upload", #uploaded files go here
		"$HTMLDIR/error", #error pages
		"once" #used for registering things which should only happen once e.g. scraping
	);

	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion();
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/key';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/file';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/avatar';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/message';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/gpg';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/gpg_message';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/gpg_stderr';
	push @dirsThatShouldExist, 'cache/' . GetMyCacheVersion() . '/response';

	# create directories that need to exist
	foreach my $dir (@dirsThatShouldExist) {
		if ($dir =~ m/^([a-zA-Z0-9_\/]+)$/) {
			$dir = $1;
		} else {
			WriteLog('utils.pl: warning: sanity check failed during @dirsThatShouldExist');
			WriteLog('utils.pl: $dir = ' . $dir);
			next;
		}
		if (!-d $dir && !-e $dir) {
			mkdir $dir;
		}
		if (!-e $dir || !-d $dir) {
			die("$dir should exist, but it doesn't. aborting.");
		}
	}
}

sub WriteLog { # $text; Writes timestamped message to console (stdout) AND log/log.log
	my $text = shift;
	if (!$text) {
		$text = '(empty string)';
	}
	chomp $text;

	{
		my $firstWord = substr($text, 0, index($text, ' '));
		my $firstWordHash = md5_hex($firstWord);
		my $firstWordHashFirstChar = substr($firstWordHash, 0, 1);
		$firstWordHashFirstChar =~ tr/0123456789abcdef/..\-\-,,""''++``++/;
		WriteMessage($firstWordHashFirstChar);
	}

	# Only if debug mode is enabled
	state $debugOn;
	if ($debugOn || -e 'config/admin/debug') {
		my $timestamp = GetTime();
		AppendFile("log/log.log", $timestamp . " " . $text);
		$debugOn = 1;
	}
} # WriteLog()


#sub GitPipe { # runs git with proper prefix, suffix, and post-command pipe
## $gitCommand = git command (excluding the 'git' part)
## $commandsFollowing = what follows after the git command (and after the command suffix)
#
#	my $gitCommand = shift;
#
#	if (!$gitCommand) {
#		return;
#	}
#
#	WriteLog('GitPipe: $gitCommand = ' . $gitCommand);
#
#	my $commandsFollowing = shift;
#	if (!$commandsFollowing) {
#		$commandsFollowing = '';
#	} else {
#		$commandsFollowing = ' ' . $commandsFollowing;
#	}
#
#	my $gitCommandPrefix = 'git --git-dir=' . $TXTDIR . '/.git --work-tree=' . $TXTDIR . ' ';
#	my $gitCommandSuffix = ' 2>&1';
#
#	my $gitCommandFull = $gitCommandPrefix . $gitCommand . $gitCommandSuffix . $commandsFollowing;
#
#	WriteLog('GitPipe: $gitCommandFull = ' . $gitCommandFull);
#
#	my $gitCommandResult = `$gitCommandFull`;
#
#	WriteLog('GitPipe: $gitCommandResult = ' . $gitCommandResult);
#
#	if ($gitCommandResult =~ m/^fatal:/) {
#		if ($gitCommand ne 'init') {
#			GitPipe('init');
#		}
#
#		return;
#	}
#
#	return $gitCommandResult;
#}


sub GetCache { # get cache by cache key
	# comes from cache/ directory, under current git commit
	# this keeps cache version-specific

	my $cacheName = shift;
	chomp($cacheName);

	if (!$cacheName =~ m/^[\/[a-z0-9A-Z_]$/i) {
		# asnity check
		WriteLog('GetCache: warning: sanity check failed');
		return;
	} else {
		WriteLog('GetCache: sanity check passed!');
	}

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	# cache name prefixed by current version
	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	if (-e $cacheName) {
		# return contents of file at that path
		return GetFile($cacheName);
	} else {
		return;
	}
}

sub ParseDate { # takes $stringDate, returns epoch time
	my $stringDate = shift;

	my $time = str2time($stringDate);

	return $time;
}

#sub LookForDate {
## looks for date in string
## and returns it as epoch
## not finished yet
#	my @formats = ( '%Y/%m/%d %H:%M:%S', '%d %b %y');
#
#	my $dateString = shift;
#	chomp $dateString;
#
#	my $timestamp;
#	foreach my $format (@formats) {
#		if ( not defined $timestamp
#			and $timestamp =
#			eval {
#				localtime->strptime( $dateString, $format )
#			}
#		)
#		{
#			WriteLog("LookForDate: $dateString converted to $timestamp using $format");
#		}
#	}
#}

sub MakePath { # $newPath ; ensures all subdirs for path exist
	my $newPath = shift;
	chomp $newPath;

	if (! $newPath) {
		WriteLog('MakePath: warning: failed sanity check, $newPath missing');
		return '';
	}

	if (-e $newPath) {
		WriteLog('MakePath: path already exists, returning');
		return '';
	}

	if (! $newPath =~ m/^[0-9a-zA-Z\/]+$/) {
		WriteLog('MakePath: warning: failed sanity check');
		return '';
	}

	WriteLog("MakePath($newPath)");

	my @newPathArray = split('/', $newPath);
	my $newPathCreated = '';

	while (@newPathArray) {
		$newPathCreated .= shift @newPathArray;
		if ($newPathCreated && !-e $newPathCreated) {
			WriteLog('MakePath: mkdir ' . $newPathCreated);
			mkdir $newPathCreated;
		}
		if (1 || $newPathCreated) {
			$newPathCreated .= '/';
		}
	}
} # MakePath()

sub EnsureSubdirs { # $fullPath ; ensures that subdirectories for a file exist
	# takes file's path as argument
	# returns 0 for failure, 1 for success
	my $fullPath = shift;
	chomp $fullPath;

	if (substr($fullPath, 0, 1) eq '/') {
		WriteLog('EnsureSubdirs: warning: $fullPath should not begin with a / ' . $fullPath);
	}
	if (index($fullPath, '..')) {
		WriteLog('EnsureSubdirs: warning: $fullPath contains ..');
	}

	WriteLog("EnsureSubdirs($fullPath)");

	#todo remove requirement of external module
	my ( $file, $dirs ) = fileparse $fullPath;
	if ( !$file ) {
		WriteLog('EnsureSubdirs: warning: $file was not set, returning');
		WriteLog('EnsureSubdirs: $file = ' . $file);
		return 0;
		#$fullPath = File::Spec->catfile($fullPath, $file);
	}

	if ( !-d $dirs && !-e $dirs ) {
		if ( $dirs =~ m/^([^\s]+)$/ ) { #security #taint
			$dirs = $1; #untaint
			MakePath($dirs);
			return 1;
		} else {
			WriteLog('EnsureSubdirs: warning: $dirs failed sanity check, returning');
			return 0;
		}
	}
} # EnsureSubdirs()

sub PutCache { # $cacheName, $content; stores value in cache
	#todo sanity checks
	my $cacheName = shift;
	chomp($cacheName);

	my $content = shift;

	if (!defined($content)) {
		WriteLog('PutCache: warning: sanity check failed, no $content');
		return 0;
	}
	
	chomp($content);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	return PutFile($cacheName, $content);
} # PutCache()

sub UnlinkCache { # removes cache by unlinking file it's stored in
	my $cacheName = shift;
	chomp($cacheName);

	WriteLog("UnlinkCache($cacheName)");

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	my $cacheFile = './cache/' . $myVersion . '/' . $cacheName;

	my @cacheFiles = glob($cacheFile);

	if (scalar(@cacheFiles)) {
		WriteLog('UnlinkCache: scalar(@cacheFiles) = ' . scalar(@cacheFiles));
		unlink(@cacheFiles);
	}
} # UnlinkCache()

sub CacheExists { # Check whether specified cache entry exists, return 1 (exists) or 0 (not)
	my $cacheName = shift;
	chomp($cacheName);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	if (-e $cacheName) {
		return 1;
	} else {
		return 0;
	}
}

# sub GetGpgMajorVersion { # get the first number of the version which 'gpg --version' returns
# 	# expecting 1 or 2
#
# 	state $gpgVersion;
#
# 	if ($gpgVersion) {
# 		return $gpgVersion;
# 	}
#
# 	$gpgVersion = `gpg --version`;
# 	WriteLog('GetGpgMajorVersion: gpgVersion = ' . $gpgVersion);
#
# 	$gpgVersion =~ s/\n.+//g;
# 	$gpgVersion =~ s/gpg \(GnuPG\) ([0-9]+).[0-9]+.[0-9]+/$1/;
# 	$gpgVersion =~ s/[^0-9]//g;
#
# 	return $gpgVersion;
# }

sub GetMyVersion { # Get the currently checked out version (current commit's hash from git)
	# sub GetVersion {
	state $myVersion;

	my $ignoreSaved = shift;

	if (!$ignoreSaved && $myVersion) {
		# if we already looked it up once, return that
		return $myVersion;
	}

	$myVersion = `git rev-parse HEAD`;
	if (!$myVersion) {
		WriteLog('GetMyVersion: warning: sanity check failed, returning default');
		$myVersion = sha1_hex('hello, world!');
	}
	chomp($myVersion);
	return $myVersion;
} # GetMyVersion()

sub GetString { # $stringKey, $language, $noSubstitutions ; Returns string from config/string/en/
# $stringKey = 'menu/top'
# $language = 'en'
# $noSubstitute = returns empty string if no exact match
	my $defaultLanguage = 'en';

	my $stringKey = shift;
	my $language = shift;
	my $noSubstitute = shift;

	if (!$stringKey) {
		WriteLog('GetString: warning: called without $stringKey, exiting');
		return;
	}
	if (!$language) {
		$language = GetConfig('language');
	}
	if (!$language) {
		$language = $defaultLanguage;
	}

	# this will store all looked up values so that we don't have to look them up again
    state %strings; #memo
    my $memoKey = $stringKey . '/' . $language . '/' . ($noSubstitute ? 1 : 0);

	if (defined($strings{$memoKey})) {
	    #memo match
		return $strings{$memoKey};
	}

	my $string = GetConfig('string/' . $language . '/'.$stringKey);
	if ($string) {
	    # exact match
		chomp ($string);

		$strings{$memoKey} = $string;
	} else {
	    # no match, dig deeper...
		if ($noSubstitute) {
			$strings{$memoKey} = '';
			return '';
		} else {
			if ($language ne $defaultLanguage) {
				$string = GetString($stringKey, $defaultLanguage);
			}

			if (!$string) {
				$string = TrimPath($stringKey);
				# if string is not found, display string key
				# trin string key's path to make it less confusing
			}

			chomp($string);

			$strings{$memoKey} = $string;

			return $string;
		}
	}
}


#sub GetString {
#	my $stringKey = shift;
#
#	state %strings;
#
#	if (!%strings) {
#		# get them from language/en
#
#		my $stringsFile = GetFile('language/en');
#
#		my @results = split("\n", $stringsFile);
#
#		foreach (@results) {
#			chomp;
#
#			my ($key, $value) = split(/\|/, $_);
#
#			$strings{$key} = $value;
#		}
#	}
#
#	if (defined($strings{$stringKey})) {
#		return $strings{$stringKey};
#	}
#}


sub GetFileHash { # $fileName ; returns hash of file contents
# // GetItemHash GetHash
	WriteLog("GetFileHash()");

	my $fileName = shift;
	chomp $fileName;
	WriteLog("GetFileHash($fileName)");
    #todo normalize path (static vs full)
	state %memoFileHash;
	if ($memoFileHash{$fileName}) {
		WriteLog('GetFileHash: memo hit ' . $memoFileHash{$fileName});
		return $memoFileHash{$fileName};
	}
	WriteLog('GetFileHash: memo miss');

	if (-e $fileName) {
		if ((lc(substr($fileName, length($fileName) - 4, 4)) eq '.txt')) {
			my $fileContent = GetFile($fileName);
			if (index($fileContent, "\n-- \n") > -1) {
				# exclude footer content from hashing
				$fileContent = substr($fileContent, 0, index($fileContent, "\n-- \n"));
			}
			$memoFileHash{$fileName} = sha1_hex($fileContent);
			return $memoFileHash{$fileName};
		} else {
		    $memoFileHash{$fileName} = sha1_hex(GetFile($fileName));

			return $memoFileHash{$fileName};
		}
	} else {
		return;
	}
} #GetFileHash()

sub GetRandomHash { # returns a random sha1-looking hash, lowercase
	my @chars=('a'..'f','0'..'9');
	my $randomString;
	foreach (1..40) {
		$randomString.=$chars[rand @chars];
	}
	return $randomString;
}

sub GetTemplate { # $templateName ; returns specified template from template directory
# returns empty string if template not found
# here is how the template file is chosen:
# 1. template's existence is checked in config/template/ or default/template/
#    a. if it is found, it is THEN looked up in the config/theme/template/ and default/theme/template/
#    b. if it is not found in the theme directory, then it is looked up in config/template/, and then default/template/
# this allows themes to override existing templates, but not create new ones
#
	my $filename = shift;
	chomp $filename;
	#	$filename = "$SCRIPTDIR/template/$filename";

	WriteLog("GetTemplate($filename)");

	state %templateCache; #stores local memo cache of template

	if ($templateCache{$filename}) {
		#if already been looked up, return memo version
		return $templateCache{$filename};
	}

	if (!-e ('config/template/' . $filename) && !-e ('default/template/' . $filename)) {
		# if template doesn't exist
		# and we are in debug mode
		# report the issue
		WriteLog("GetTemplate: warning: template $filename missing");

		if (GetConfig('admin/dev_mode')) {
			die("GetTemplate: warning: template $filename missing, exiting");
		}
	}

	#information about theme
	my $themeName = GetConfig('html/theme');
	my $themePath = 'theme/' . $themeName . '/template/' . $filename;

	my $template = '';
	if (GetConfig($themePath)) {
		#if current theme has this template, override default
		$template = GetConfig($themePath);
	} else {
		#otherwise use regular template
		$template = GetConfig('template/' . $filename);
	}

	# add \n to the end because it makes the resulting html look nicer
	# and doesn't seem to hurt anything else
	$template .= "\n";

	if ($template) {
		#if template contains something, cache it
		$templateCache{$filename} = $template;
		return $template;
	} else {
		#if result is blank, report it
		WriteLog("GetTemplate: warning: GetTemplate() returning empty string for $filename.");
		return '';
	}
}

sub encode_entities2 { # returns $string with html entities <>"& encoded
	my $string = shift;
	if (!$string) {
		return;
	}

	WriteLog("encode_entities2($string)");

	$string =~ s/&/&amp;/g;
	$string =~ s/\</&lt;/g;
	$string =~ s/\>/&gt;/g;
	$string =~ s/"/&quot;/g;

	return $string;
}

sub GetHtmlAvatar { # Returns HTML avatar from cache 
	state %avatarCache;

	# returns avatar suitable for comments
	my $key = shift;
	if (!$key) {
		return;
	}

	if (!IsFingerprint($key)) {
		return;
	}

	if ($avatarCache{$key}) {
		WriteLog("GetHtmlAvatar: found in hash");
		return $avatarCache{$key};
	}

	my $avatar = GetAvatar($key);
	if ($avatar) {
		if (-e 'html/author/' . $key) {
			my $avatarLink = GetAuthorLink($key);
			$avatarCache{$key} = $avatar;
			return $avatarLink;
		}
	} else {
		return $key;
		#		return 'unregistered';
	}

	return $key;
	#	return 'unregistered';
}

sub GetAlias { # $fingerprint, $noCache ; Returns alias for an author
	my $fingerprint = shift;
	chomp $fingerprint;
	WriteLog("GetAlias($fingerprint)");

	my $noCache = shift;
	$noCache = ($noCache ? 1 : 0);

	state %aliasCache;
	if (!$noCache) {
		if (exists($aliasCache{$fingerprint})) {
			return $aliasCache{$fingerprint};
		}
	}

	my $alias = DBGetAuthorAlias($fingerprint);

	if ($alias) {
		{ # remove email address, if any
			$alias =~ s|<.+?>||g;
			$alias = trim($alias);
			chomp $alias;
		}

		if ($alias && length($alias) > 24) {
			$alias = substr($alias, 0, 24);
		}

		$aliasCache{$fingerprint} = $alias;
		return $aliasCache{$fingerprint};
	} else {
		return $fingerprint;
		#		return 'unregistered';
	}
} # GetAlias()

sub GetFileExtension { # $fileName ; returns file extension, naively
	my $fileName = shift;

	if ($fileName) {
		if ($fileName =~ m/.+\/.+\.(.+)/) {
			return $1;
		} else {
			return '';
		}
	} else {
		return '';
	}
} # GetFileExtension()

sub GetFile { # Gets the contents of file $fileName
	my $fileName = shift;

	if (!$fileName) {
		if (-e 'config/admin/debug') {
			#die('attempting GetFile() without $fileName');
		}
		return;
	}

	my $length = shift || 209715200;
	# default to reading a max of 2MB of the file. #scaling #bug

	if (
		-e $fileName # file exists
			&&
		!-d $fileName # not a directory
			&&
		open (my $file, "<", $fileName) # opens successfully
	) {
		my $return;

		read ($file, $return, $length);

		return $return;
	}

	return;
	#todo do something for a file which is missing
}

sub GetConfig { # $configName, $token, [$parameter] ;  gets configuration value based for $key
	# $token eq 'uncache'
	#    removes it from %configLookup
	# $token eq 'override'
	# 	instead of regular lookup, overrides value
	#		overridden value is stored in local sub memo
	#			this means all subsequent lookups now return $parameter
	#
	state $devMode;
	$devMode = 0;
#	this is janky, and doesn't work as expected
#	eventually, it will be nice for dev mode to not rewrite
#	the entire config tree on every rebuild
#	and also not require a rebuild after a default change
#	#todo
#	if (!defined($devMode)) {
#		if (-e 'config/admin/dev_mode') {
#			WriteLog('GetConfig: attention: setting $devMode = 1');
#			$devMode = 1;
#		} else {
#			$devMode = 0;
#		}
#	}

	my $configName = shift;
	chomp $configName;

	WriteLog("GetConfig($configName)");

	#	if ($configName =~ /^[a-z0-9_\/]{1,255}$/) {
	#		WriteLog("GetConfig: warning: Sanity check failed!");
	#		WriteLog("\$configName = $configName");
	#		return;
	#	}
	#
	state %configLookup;

	if ($configName && $configName eq 'unmemo') {
		undef %configLookup;
	}

	my $token = shift;
	if ($token) {
		chomp $token;
	}

	if ($token && $token eq 'unmemo') {
		WriteLog('GetConfig: unmemo requested, complying');
		# unmemo token to remove memoized value
		if (exists($configLookup{$configName})) {
			delete($configLookup{$configName});
		}
	}

	if ($token && $token eq 'override') {
		my $parameter = shift;
		if ($parameter) {
			$configLookup{$configName} = $parameter;
		} else {
			WriteLog('GetConfig: warning: $token was override, but no parameter. sanity check failed.');
			return '';
		}
	}

	if (exists($configLookup{$configName})) {
		WriteLog('GetConfig: $configLookup already contains value, returning that...');
		WriteLog('GetConfig: $configLookup{$configName} is ' . $configLookup{$configName});

		return $configLookup{$configName};
	}

	WriteLog("GetConfig: Looking for config value in config/$configName ...");

	my $acceptableValues;
	if ($configName eq 'html/clock_format') {
		if (substr($configName, -5) ne '.list') {
			my $configList = GetConfig("$configName.list");
			if ($configList) {
				$acceptableValues = $configList;
			}
		}
	} else {
		$acceptableValues = 0;
	}

	if (-d "config/$configName") {
		WriteLog('GetConfig: warning: $configName was a directory, returning');
		return;
	}

	if (-e "config/$configName") {
		WriteLog("GetConfig: -e config/$configName returned true, proceeding to GetFile(), set \$configLookup{}, and return \$configValue");

		my $configValue = GetFile("config/$configName");

		if (substr($configName, 0, 9) eq 'template/') {
			# don't trim
		} else {
			$configValue = trim($configValue);
		}

		$configLookup{$configValue} = $configValue;

		if ($acceptableValues) {
			# there is a list of acceptable values
			# check to see if value is in that list
			# if not, return 0
			if (index($configValue, $acceptableValues)) {
				return $configValue;
			} else {
				WriteLog('GetConfig: warning: $configValue was not in $acceptableValues');
				return 0; #todo should return default, perhaps via $param='default'
			}
		} else {
			return $configValue;
		}
	} else {
		WriteLog("GetConfig: -e config/$configName returned false, looking in defaults...");

		if (-e "default/$configName") {
			WriteLog("GetConfig: -e default/$configName returned true, proceeding to GetFile(), etc...");

			my $configValue = GetFile("default/$configName");
			$configValue = trim($configValue);
			$configLookup{$configName} = $configValue;

			if (!$devMode) {
				# this preserves default settings, so that even if defaults change in the future
				# the same value will remain for current instance
				# this also saves much time not having to run ./clean_dev when developing
				WriteLog('GetConfig: calling PutConfig(' . $configName . ', ' . $configValue .');');
				PutConfig($configName, $configValue);
			} else {
				WriteLog('GetConfig: $devMode is TRUE, not calling PutConfig()');
			}

			return $configValue;
		} else {
			WriteLog("GetConfig: warning: Tried to get undefined config with no default: $configName");
			return;
		}
	}

	WriteLog('GetConfig: warning: reached end of function, which should not happen');
	return;
} # GetConfig()

sub ConfigKeyValid { #checks whether a config key is valid 
	# valid means passes character sanitize
	# and exists in default/
	my $configName = shift;

	if (!$configName) {
		WriteLog('ConfigKeyValid: warning: $configName parameter missing');
		return 0;
	}

	WriteLog("ConfigKeyValid($configName)");

	if (! ($configName =~ /^[a-z0-9_\/]{1,64}$/) ) {
		WriteLog("ConfigKeyValid: warning: sanity check failed!");
		return 0;
	}

	WriteLog('ConfigKeyValid: $configName sanity check passed:');

	if (-e "default/$configName") {
		WriteLog("ConfigKeyValid: default/$configName exists");
		return 1;
	} else {
		WriteLog("ConfigKeyValid: default/$configName NOT exist!");
		return 0;
	}
} # ConfigKeyValid()

sub GetHtmlFilename { # get the HTML filename for specified item hash
	# GetItemUrl GetItemHtmlLink { #keywords
	# Returns 'ab/cd/abcdef01234567890[...].html'
	my $hash = shift;

	WriteLog("GetHtmlFilename()");

	if (!defined($hash) || !$hash) {
		if (WriteLog("GetHtmlFilename: warning: called without parameter")) {

			#my $trace = Devel::StackTrace->new;
			#print $trace->as_string; # like carp
		}

		return;
	}

	WriteLog("GetHtmlFilename($hash)");

	if (!IsItem($hash)) {
		WriteLog("GetHtmlFilename: warning: called with parameter that isn't a SHA-1. Returning.");
		WriteLog("$hash");
		#
		# my $trace = Devel::StackTrace->new;
		# print $trace->as_string; # like carp

		return;
	}

	#	my $htmlFilename =
	#		substr($hash, 0, 2) .
	#		'/' .
	#		substr($hash, 2, 8) .
	#		'.html';
	#


	# my $htmlFilename =
	# 	substr($hash, 0, 2) .
	# 	'/' .
	# 	substr($hash, 2, 2) .
	# 	'/' .
	# 	$hash .
	# 	'.html';
	#
	#
	my $htmlFilename =
		substr($hash, 0, 2) .
			'/' .
			substr($hash, 2, 2) .
			'/' .
			substr($hash, 0, 8) .
			'.html';

	return $htmlFilename;
}

sub GetTime () { # Returns time in epoch format.
	# Just returns time() for now, but allows for converting to 1900-epoch time
	# instead of Unix epoch
	#	return (time() + 2207520000);
	return (time());
}

sub GetClockFormattedTime() { # returns current time in appropriate format from config
	#formats supported: union, epoch (default)

	my $clockFormat = GetConfig('html/clock_format');
	chomp $clockFormat;

	if ($clockFormat eq '24hour') {
	    my $time = GetTime();

        my $hours = strftime('%H', localtime $time);
        my $minutes = strftime('%M', localtime $time);
        # my $seconds = strftime('%S', localtime $time);

        my $clockFormattedTime = $hours . ':' . $minutes;
        # my $clockFormattedTime = $hours . ':' . $minutes . ':' . $seconds;

        return $clockFormattedTime;
    }

	if ($clockFormat eq 'union') {
		my $time = GetTime();

		#todo implement this, for now it's only js
		#$clockFormattedTime = 'union_clock_format';
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;
		#
		# var hours = now.getHours();
		# var minutes = now.getMinutes();
		# var seconds = now.getSeconds();
		my $hours = strftime('%H', localtime $time);
		my $minutes = strftime('%M', localtime $time);
		my $seconds = strftime('%S', localtime $time);
		#

		my $milliseconds = '000';
		# if (now.getMilliseconds) {
		# 	milliseconds = now.getMilliseconds();
		# } else if (Math.floor && Math.random) {
		# 	milliseconds = Math.floor(Math.random() * 999)
		# }
		#
		# var hoursR = 23 - hours;
		# if (hoursR < 10) {
		# 	hoursR = '0' + '' + hoursR;
		# }
		my $hoursR = 23 - $hours;
		if ($hoursR < 10) {
			$hoursR = '0' . $hoursR;
		}

		# var minutesR = 59 - minutes;
		# if (minutesR < 10) {
		# 	minutesR = '0' + '' + minutesR;
		# }
		my $minutesR = 59 - $minutes;
		if ($minutesR < 10) {
			$minutesR = '0' . $minutesR;
		}

		# var secondsR = 59 - seconds;
		# if (secondsR < 10) {
		# 	secondsR = '0' + '' + secondsR;
		# }
		my $secondsR = 59 - $seconds;
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

		my $clockFormattedTime = $hours . $minutes . $seconds . $milliseconds . $secondsR . $minutesR . $hoursR;

		return $clockFormattedTime;
	}

	return GetTime();
}

sub GetTitle { # Gets title for file (incomplete, currently does nothing)
	my $text = shift;

	if (!$text) {
		return;
	}

}

sub ResetConfig { # Resets $configName to default by removing the config/* file
	# Does a ConfigKeyValid() sanity check first
	my $configName = shift;

	if (ConfigKeyValid($configName)) {
		unlink("config/$configName");
	}
}

sub PutConfig { # $configName, $configValue ; writes config value to config storage
	# $configName = config name/key (file path)
	# $configValue = value to write for key
	# Uses PutFile()
	#
	my $configName = shift;
	my $configValue = shift;

	WriteLog("PutConfig($configName, $configValue)");

	if (index($configName, '..') != -1) {
		WriteLog('PutConfig: warning: sanity check failed: $configName contains ".."');
		WriteLog('PutConfig: warning: sanity check failed: $configName contains ".."');
		return '';
	}

	chomp $configValue;

	my $putFileResult = PutFile("config/$configName", $configValue);

	# ask GetConfig() to remove memo-ized value it stores inside
	GetConfig($configName, 'unmemo');

	return $putFileResult;
} # PutConfig()

sub PutFile { # Writes content to a file; $file, $content, $binMode
	# $file = file path
	# $content = content to write
	# $binMode = whether or not to use binary mode when writing
	# ensures required subdirectories exist
	#
	WriteLog("PutFile(...)");

	my $file = shift;

	if (!$file) {
		return;
	}

	WriteLog("PutFile($file)");

	WriteLog("PutFile: EnsureSubdirs($file)");

	EnsureSubdirs($file);

	WriteLog("PutFile: $file, ...");

	my $content = shift;
	my $binMode = shift;

	if (!defined($content)) {
		WriteLog('PutFile: $content not defined, returning');
		return;
	}

	#	if (!$content) {
	#		return;
	#	}
	if (!$binMode) {
		WriteLog('PutFile: $binMode: 0');
		$binMode = 0;
	} else {
		$binMode = 1;
		WriteLog('PutFile: $binMode: 1');
	}

	WriteLog("PutFile: $file, (\$content), $binMode");
	#WriteLog("==== \$content ====");
	#WriteLog($content);
	#WriteLog("====");

	if ($file =~ m/^([^\s]+)$/) { #todo this is overly permissive #security #taint
		$file = $1;
		if (open (my $fileHandle, ">", $file)) {
			WriteLog("PutFile: file handle opened for $file");
			if ($binMode) {
				WriteLog("PutFile: binmode $fileHandle, ':utf8';");
				binmode $fileHandle, ':utf8';
			}
			WriteLog("PutFile: print $fileHandle $content;");
			print $fileHandle $content; #todo wide character error here

			WriteLog("PutFile: close $fileHandle;");
			close $fileHandle;

			return 1;
		}
	} else {
		WriteLog('PutFile: warning: sanity check failed: $file contains space');
	}
}

sub EpochToHuman { # returns epoch time as human readable time
	my $time = shift;

	return strftime('%F %T', localtime($time));
}

sub EpochToHuman2 { # not sure what this is supposed to do, and it's unused 
	my $time = shift;

	my ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime($time);
	$year = $year + 1900;
	$month = $month + 1;

}

#props http://www.bin-co.com/perl/scripts/str_replace.php
sub str_replace { # $replaceWhat, $replaceWith, $string ; emulates some of str_replace() from php
	# fourth $count parameter not implemented yet
	my $replace_this = shift;
	my $with_this  = shift;
	my $string   = shift;

	my $stringLength = length($string);

	if (!defined($string) || !$string) {
		WriteLog('str_replace: warning: $string not supplied');
		return "";
	}

	WriteLog("str_replace($replace_this, $with_this, ($stringLength))");

	if (!defined($replace_this) || !defined($with_this)) {
		WriteLog('str_replace: warning: sanity check failed, missing $replace_this or $with_this');
		return $string;
	}

	if ($replace_this eq $with_this) {
		WriteLog('str_replace: warning: $replace_this eq $with_this');
		return $string;
	}

	WriteLog("str_replace: sanity check passed, proceeding");

	my $length = length($string);
	my $target = length($replace_this);

	for (my $i = 0; $i < $length - $target + 1; $i++) {
		#todo there is a bug here
		if (!defined(substr($string, $i, $target))) {
			WriteLog("str_replace: warning: !defined(substr($string, $i, $target))");
		}
		elsif (substr($string, $i, $target) eq $replace_this) {
			$string = substr ($string, 0, $i) . $with_this . substr($string, $i + $target);
			$i += length($with_this) - length($replace_this); # when new string contains old string
			$length += length($with_this) - length($replace_this); # string is getting shorter or longer
		} else {
			# do nothing
		}
	}

	WriteLog("str_replace: result: ($stringLength)");

	return $string;
} # str_replace()

#props http://www.bin-co.com/perl/scripts/str_replace.php
sub str_ireplace { # $replaceWhat, $replaceWith, $string ; emulates some of str_ireplace() from php
	# fourth $count parameter not implemented yet
	my $replace_this = shift;
	my $with_this  = shift;
	my $string   = shift;

	if (!defined($string) || !$string) {
		WriteLog('str_ireplace: warning: $string not supplied');
		return "";
	}

	WriteLog("str_ireplace($replace_this, $with_this, $string)");

	if ($replace_this eq $with_this) {
		WriteLog('str_ireplace: warning: $replace_this eq $with_this');
		return $string;
	}

	WriteLog("str_ireplace: sanity check passed, proceeding");

	my $length = length($string);
	my $target = length($replace_this);

	for (my $i = 0; $i < $length - $target + 1; $i++) {
		if (lc(substr($string, $i, $target)) eq lc($replace_this)) {
			$string = substr ($string, 0, $i) . $with_this . substr($string, $i + $target);
			$i += length($with_this) - length($replace_this); # when new string contains old string
		}
	}

	WriteLog("str_ireplace: result: $string");

	return $string;
} # str_replace()

sub ReplaceStrings {
	my $content = shift;
	my $newLanguage = shift;

	if (!$newLanguage) {
		$newLanguage = GetConfig('language');
	}

	my $contentStripped = $content;
	$contentStripped =~ s/\<[^>]+\>/<>/sg;
	my @contentStrings = split('<>', $contentStripped);

	foreach my $string (@contentStrings) {
		$string = trim($string);

		if ($string && length($string) >= 5) {
			my $stringHash = md5_hex($string);

			WriteLog('ReplaceStrings, replacing ' . $string . ' (' . $stringHash . ')');

			my $newString = GetConfig('string/' . $newLanguage . '/' . $stringHash);

			if ($newString) {
				$content = str_replace($string, $newString, $content);
			} else {
				PutConfig('string/' . $newLanguage . '/' . $stringHash, $string);
			}
		}
	}

	return $content;
}

sub IsUrl { # add basic isurl()
	return 1;
} # IsUrl()

sub AddAttributeToTag { # $html, $tag, $attributeName, $attributeValue; adds attr=value to html tag;
	my $html = shift; # chunk of html to work with
	my $tag = shift; # tag we'll be modifying
	my $attributeName = shift; # name of attribute
	my $attributeValue = shift; # value of attribute

	WriteLog("AddAttributeToTag(\$html, $tag, $attributeName, $attributeValue)");
	WriteLog('AddAttributeToTag: $html before: ' . $html);

	my $tagAttribute = '';
	if ($attributeValue =~ m/\w/) {
		# attribute value contains whitespace, must be enclosed in double quotes
		$tagAttribute = $attributeName . '="' . $attributeValue . '"';
	} else {
		$tagAttribute = $attributeName . '=' . $attributeValue . '';
	}

	my $htmlBefore = $html;
	$html = str_ireplace('<' . $tag . ' ', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
	if ($html eq $htmlBefore) {
		$html = str_ireplace('<' . $tag . '', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
	}
	if ($html eq $htmlBefore) {
		$html = str_ireplace('<' . $tag . '>', '<' . $tag . ' ' . $tagAttribute . '>', $html);
	}
	if ($html eq $htmlBefore) {
		WriteLog('AddAttributeToTag: warning: nothing was changed');
	}

	WriteLog('AddAttributeToTag: $html after: ' . $html);

	return $html;
} # AddAttributeToTag()

sub RemoveHtmlFile { # $file ; removes existing html file
# returns 1 if file was removed
	my $file = shift;
	if (!$file) {
		return 0;
	}
	if ($file eq 'index.html') {
		# do not remove index.html
		# temporary measure until caching is fixed
		# also needs a fix for lazy html, because htaccess rewrite rule doesn't catch it
		return 0;
	}
	my $fileProvided = $file;
	$file = "$HTMLDIR/$file";

	if (
		$file =~ m/^([0-9a-z\/.]+)$/
			&&
		index($file, '..') == -1
	) {
		# sanity check
	 	$file = $1;
		if (-e $file) {
			unlink($file);
		}
	} else {
		WriteLog('RemoveHtmlFile: warning: sanity check failed, $file = ' . $file);
		return '';
	}
} # RemoveHtmlFile()

#

sub PutHtmlFile { # $file, $content, $itemHash ; writes content to html file, with special rules; parameters: $file, $content
	# the special rules are:
	# * if config/admin/html/ascii_only is set, all non-ascii characters are stripped from output to file
	# * if $file matches config/html/home_page, the output is also written to index.html
	#   also keeps track of whether home page has been written, and returns the status of it
	#   if $file is 'check_homepage'

	my $file = shift;
	my $content = shift;
	my $itemHash = shift; #optional

	if (!$file) {
		return;
	}

	if ($file eq 'welcome.html') {
		PutHtmlFile('index.html', $content);
	}

	WriteLog("PutHtmlFile($file)");

	if ($HTMLDIR && !-e $HTMLDIR) {
		mkdir($HTMLDIR);
	}

	if (!$HTMLDIR || !-e $HTMLDIR) {
		WriteLog('PutHtmlFile: $HTMLDIR is missing: ' . $HTMLDIR);
		return;
	}

	if (!$content) {
		$content = '';
	}

	# keeps track of whether home page has been written at some point
	# this value is returned if $file is 'check_homepage'
	# then we can write the default homepage in its place
	state $homePageWritten;
	if (!defined($homePageWritten)) {
		$homePageWritten = 0;
	}
	if ($file eq 'check_homepage') {
		# this is a special flag which returns the value of $homePageWritten
		# allows caller to know whether home page has already been written
		return $homePageWritten;
	}

	# remember what the filename provided is, so that we can use it later
	my $fileProvided = $file;
	$file = "$HTMLDIR/$file";

	# controls whether linked urls are converted to relative format
	# meaning they go from e.g. /write.html to ./write.html
	# this breaks the 404 page links so disable that for now
	my $relativizeUrls = GetConfig('html/relativize_urls');
	if (TrimPath($file) eq '404') {
		$relativizeUrls = 0;
	}
	if ($file eq "$HTMLDIR/stats-footer.html") {
		#note this means footer links will be broken if hosted on non-root dir on a domain
		$relativizeUrls = 0;
	}

	WriteLog("PutHtmlFile($file), \$content)");

	# $stripNonAscii remembers value of admin/html/ascii_only
	# this might be duplicate work
	state $stripNonAscii;
	if (!defined($stripNonAscii)) {
		$stripNonAscii = GetConfig('admin/html/ascii_only');
		if (!defined($stripNonAscii)) {
			$stripNonAscii = 0;
		}
		if ($stripNonAscii != 1) {
			$stripNonAscii = 0;
		}
	}

	# if $stripNonAscii is on, strip all non-ascii characters from the output
	# in the future, this can, perhaps, for example, convert unicode-cyrillic to ascii-cyrillic
	if ($stripNonAscii == 1) {
		WriteLog( '$stripNonAscii == 1');
		$content =~ s/[^[:ascii:]]//g;
	}

	# convert urls to relative if $relativizeUrls is set
	if ($relativizeUrls == 1) {
		# only the following *exact* formats are converted
		# thus it is important to maintain this exact format throughout the html and js templates
		# src="/
		# href="/
		# .src = '/
		# .location = '/

		# first we determine how many levels deep our current file is
		# we do this by counting slashes in $file
		my $count = ($fileProvided =~ s/\//\//g) + 1;

		# then we build the path prefix.
		# the same prefix is used on all links
		# this can be done more efficiently on a per-link basis
		# but most subdirectory-located files are of the form /aa/bb/aabbcc....html anyway
		my $subDir;
		if ($count == 1) {
			$subDir = './';
		} else {
			if ($count < 1) {
				WriteLog('PutHtmlFile: relativize_urls: sanity check failed, $count is < 1');
			} else {
				# $subDir = '../' x ($count - 1);
				$subDir = str_repeat('../', ($count - 1));
			}
		}

		# here is where we do substitutions
		# it may be wiser to use str_replace here
		$content =~ s/src="\//src="$subDir/ig;
		$content =~ s/href="\//href="$subDir/ig;
		$content =~ s/action="\//action="$subDir/ig;
		$content =~ s/\.src = '\//.src = '$subDir/ig;
		$content =~ s/\.location = '\//.location = '$subDir/ig;
	}

	# fill in colors
	my $colorTopMenuTitlebarText = GetThemeColor('top_menu_titlebar_text') || GetThemeColor('titlebar_text');
	$content =~ s/\$colorTopMenuTitlebarText/$colorTopMenuTitlebarText/g;#

	my $colorTopMenuTitlebar = GetThemeColor('top_menu_titlebar') || GetThemeColor('titlebar');
	$content =~ s/\$colorTopMenuTitlebar/$colorTopMenuTitlebar/g;

	# fill in colors
	my $colorTitlebarText = GetThemeColor('titlebar_text');#
	$content =~ s/\$colorTitlebarText/$colorTitlebarText/g;#

	my $colorTitlebar = GetThemeColor('titlebar');#
	$content =~ s/\$colorTitlebar/$colorTitlebar/g;#

	my $borderDialog = GetThemeAttribute('color/border_dialog');
	#todo rename it in all themes and then here
	# not actually a color, but the entire border definition
	$content =~ s/\$borderDialog/$borderDialog/g;

	my $colorWindow = GetThemeColor('window');
	$content =~ s/\$colorWindow/$colorWindow/g;

	# #internationalization #i18n
	if (GetConfig('language') ne 'en') {
		$content = ReplaceStrings($content);
	}

	# this allows adding extra attributes to the body tag
	my $bodyAttr = GetThemeAttribute('tag/body');
	if ($bodyAttr) {
		$bodyAttr = FillThemeColors($bodyAttr);
		$content =~ s/\<body/<body $bodyAttr/i;
		$content =~ s/\<body>/<body $bodyAttr>/i;
	}

	#if (GetConfig('html/debug')) {
		# this would make all one-liner html comments visible if it worked
		#$content =~ s/\<\!--(.+)--\>/<p class=advanced>$1<\/p>/g;
	#}

	PutFile($file, $content);

	if (index($content, '$') > -1) {
		# test for $ character in html output, warn/crash if it is there
		if (!($fileProvided eq 'openpgp.js')) {
			WriteLog('PutHtmlFile: warning: $content contains $ symbol! $file = ' . ($file ? $file : '-'));
		}
	}

#	if ($fileProvided eq GetConfig('html/home_page') || "$fileProvided.html" eq GetConfig('html/home_page')) {
#		# this is a special hook for generating index.html, aka the home page
#		# if the current file matches config/html/home_page, write index.html
#		# change the title to home_title while at it
#
#		my $homePageTitle = GetConfig('home_title');
#		$content =~ s/\<title\>(.+)\<\/title\>/<title>$homePageTitle<\/title>/;
#		PutFile($HTMLDIR . '/index.html', $content);
#		$homePageWritten = 1;
#	}
#
	# if ($itemHash) {
	# 	# filling in 404 pages, using 404.log
	#
	# 	# clean up the log file
	# 	system ('sort log/404.log | uniq > log/404.log.uniq ; mv log/404.log.uniq log/404.log');
	#
	# 	# store log file in static variable for future
	# 	state $log404;
	# 	if (!$log404) {
	# 		$log404 = GetFile('log/404.log');
	# 	}
	#
	# 	# if hash is found in 404 log, we will fill in the html page
	# 	# pretty sure this code doesn't work #todo
	# 	if ($log404 =~ m/$itemHash/) {
	# 		my $aliasUrl = GetItemMessage($itemHash); # url is stored inside message
	#
	# 		if ($aliasUrl =~ m/\.html$/) {
	# 			if (!-e "$HTMLDIR/$aliasUrl") { # don't clobber existing files
	# 				PutHtmlFile($aliasUrl, $content); # put html file in place (#todo replace with ln -s)
	# 			}
	# 		}
	# 	}
	# }
} # PutHtmlFile()

sub GetFileAsHashKeys { # returns file as hash of lines
	# currently not used, can be used for detecting matching lines later
	my $fileName = shift;

	my @lines = split('\n', GetFile($fileName));

	my %hash;

	foreach my $line (@lines) {
		$hash{$line} = 0;
	}

	return %hash;
}


sub AppendFile { # appends something to a file; $file, $content to append
	# mainly used for writing to log files
	my $file = shift;
	my $content = shift;

	if (open (my $fileHandle, ">>", $file)) {
		say $fileHandle $content;
		close $fileHandle;
	}
}

sub trim { # trims whitespace from beginning and end of $string
	my $s = shift;

	if (defined($s)) {
		$s =~ s/^\s+|\s+$//g;
		$s =~ s/^\n+|\n+$//g;
		chomp $s;

		return $s;
	}
};

sub GetSecondsHtml {# takes number of seconds as parameter, returns the most readable approximate time unit
	# 5 seconds = 5 seconds
	# 65 seconds = 1 minute
	# 360 seconds = 6 minutes
	# 3600 seconds = 1 hour
	# etc

	my $seconds = shift;

	if (!$seconds) {
		return;
	}

	chomp $seconds;

	my $secondsString = $seconds;

	if ($secondsString >= 60) {
		$secondsString = $secondsString / 60;

		if ($secondsString >= 60 ) {
			$secondsString = $secondsString / 60;

			if ($secondsString >= 24) {
				$secondsString = $secondsString / 24;

				if ($secondsString >= 365) {
					$secondsString = $secondsString / 365;

					$secondsString = floor($secondsString) . ' years';
				}
				elsif ($secondsString >= 30) {
					$secondsString = $secondsString / 30;

					$secondsString = floor($secondsString) . ' months';
				}
				else {
					$secondsString = floor($secondsString) . ' days';
				}
			}
			else {
				$secondsString = floor($secondsString) . ' hours';
			}
		}
		else {
			$secondsString = floor($secondsString) . ' minutes';
		}
	} else {
		$secondsString = floor($secondsString) . ' seconds';
	}
}

sub GetFileSizeWidget { # takes file size as number, and returns html-formatted human-readable size
	my $fileSize = shift;

	if (!$fileSize) {
		return;
	}

	chomp ($fileSize);

	my $fileSizeString = $fileSize;

	if ($fileSizeString > 1024) {
		$fileSizeString = $fileSizeString / 1024;

		if ($fileSizeString > 1024) {
			$fileSizeString = $fileSizeString / 1024;

			if ($fileSizeString > 1024) {
				$fileSizeString = $fileSizeString / 1024;

				if ($fileSizeString > 1024) {
					$fileSizeString = $fileSizeString / 1024;

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="terabytes">TB</abbr>';
				} else {

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="gigabytes">GB</abbr>';
				}
			} else {
				$fileSizeString = ceil($fileSizeString) . ' <abbr title="megabytes">MB</abbr>';
			}
		} else {
			$fileSizeString = ceil($fileSizeString) . ' <abbr title="kilobytes">KB</abbr>';
		}
	} else {
		$fileSizeString .= " bytes";
	}

	return $fileSizeString;
}

sub IsServer { # Returns 1 if supplied parameter equals GetServerKey(), otherwise returns 0
	my $key = shift;

	if (!$key) {
		WriteLog("IsServer() called without key!");
		return 0;
	}

	WriteLog("IsServer($key)");
	#
	#	if (!IsFingerprint($key)) {
	#		WriteLog("IsServer() failed due to IsFingerprint() returning falsee!");
	#
	#		return 0;
	#	}

	WriteLog("IsServer($key)");

	my $serverKey = GetServerKey();

	WriteLog("... \$serverKey = $serverKey");

	if ($serverKey eq $key) {
		WriteLog("... 1");
		return 1;
	} else {
		WriteLog("... 0");
		return 0;
	}
}

sub AuthorHasTag { # $key ; returns 1 if user is admin, otherwise 0
	# will probably be redesigned in the future
	my $key = shift;
	my $tagInQuestion = shift;

	if (!IsFingerprint($key)) {
		WriteLog('AuthorHasTag: warning: $key failed sanity check, returning 0');
		return 0;
	}

	if (!trim($tagInQuestion)) {
		WriteLog('AuthorHasTag: warning: $tagInQuestion failed sanity check, returning 0');
		return 0;
	}

	#todo $tagInQuestion sanity check

	WriteLog("AuthorHasTag($key, $tagInQuestion)");

	my $pubKeyHash = DBGetAuthorPublicKeyHash($key);
	if ($pubKeyHash) {
		WriteLog('AuthorHasTag: $pubKeyHash = ' . $pubKeyHash);

		my %pubKeyVoteTotals = DBGetItemVoteTotals($pubKeyHash);
		WriteLog('AuthorHasTag: join(",", keys(%pubKeyVoteTotals)) = ' . join(",", keys(%pubKeyVoteTotals)));

		if ($pubKeyVoteTotals{$tagInQuestion}) {
			WriteLog('IsAdmin: $tagInQuestion FOUND, return 1');
			return 1;
		} else {
			WriteLog('IsAdmin: $tagInQuestion NOT found, return 0');
			return 0;
		}
	} else {
		WriteLog('AuthorHasTag: warning, no $pubKeyHash, how did we even get here?');
		return 0;
	}

	WriteLog('AuthorHasTag: warning: unreachable fallthrough');
	return 0;
} # AuthorHasTag()

sub IsAdmin { # $key ; returns 1 if user is admin, otherwise 0
	# returns 2 if user is root admin.
	my $key = shift;

	WriteLog("IsAdmin($key)");

	if (!IsFingerprint($key)) {
		WriteLog('IsAdmin: warning: $key failed sanity check, returning 0');
		return 0;
	}

	if ($key eq GetRootAdminKey()) {
		WriteLog('IsAdmin: $key eq GetRootAdminKey(), return 2 ');
		return 2; # is admin, return true;
	} else {
		if (GetConfig('admin/allow_admin_permissions_tag_lookup')) {
			WriteLog('IsAdmin: not root admin, checking tags');
			return AuthorHasTag($key, 'admin');
		} else {
			WriteLog('IsAdmin: allow_admin_permissions_tag_lookup is false, stopping here');
			return 0;
		}
	}

	WriteLog('IsAdmin: warning: unreachable reached'); #should never reach here
} # IsAdmin()

sub GetServerKey { # Returns server's public key, 0 if there is none
	state $serversKey;

	if ($serversKey) {
		return $serversKey;
	}

	if (-e "$TXTDIR/server.key.txt") { #server's pub key should reside here
		my %adminsInfo = GpgParse("$TXTDIR/server.key.txt");

		if ($adminsInfo{'isSigned'}) {
			if ($adminsInfo{'key'}) {
				$serversKey = $adminsInfo{'key'};

				return $serversKey;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}

	WriteLog('GetServerKey: warning: fallthrough!');
	return 0;
} # GetServerKey()

sub GetRootAdminKey { # Returns root admin's public key, if there is none
	# it's located in ./admin.key as armored public key
	# should be called GetRootAdminKey()
	state $adminsKey;
	if ($adminsKey) {
		return $adminsKey;
	}
	if (-e "$SCRIPTDIR/admin.key") {
		my %adminsInfo = GpgParse("$SCRIPTDIR/admin.key");
		if ($adminsInfo{'isSigned'}) {
			if ($adminsInfo{'key'}) {
				$adminsKey = $adminsInfo{'key'};
				return $adminsKey;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}
	return 0;
}

sub TrimPath { # $string ; Trims the directories AND THE FILE EXTENSION from a file path
	my $string = shift;
	while (index($string, "/") >= 0) {
		$string = substr($string, index($string, "/") + 1);
	}
	if (index($string, ".") != -1) {
		$string = substr($string, 0, index($string, ".") + 0);
	}
	return $string;
}

sub htmlspecialchars { # $text, encodes supplied string for html output
	# port of php built-in
	my $text = shift;
	$text = encode_entities2($text);
	return $text;
}

sub HtmlEscape { # encodes supplied string for html output
	my $text = shift;

	$text = encode_entities2($text);

	return $text;
}

sub IsSha1 { # returns 1 if parameter is in sha1 hash format, 0 otherwise
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[a-fA-F0-9]{40}/) {
		return 1;
	} else {
		return 0;
	}
}

sub IsImageFile { # $file ; returns 1 if image file, 0 if not
	my $file = shift;
	if (!$file) {
		return 0;
	}
	chomp $file;
	if (!$file) {
		return 0;
	}

	if (
		-e $file
			&&
		(
			substr(lc($file), length($file) -4, 4) eq ".jpg" ||
			substr(lc($file), length($file) -4, 4) eq ".gif" ||
			substr(lc($file), length($file) -4, 4) eq ".png" ||
			substr(lc($file), length($file) -4, 4) eq ".bmp" ||
			substr(lc($file), length($file) -4, 4) eq ".svg" ||
			substr(lc($file), length($file) -5, 5) eq ".jfif" ||
			substr(lc($file), length($file) -5, 5) eq ".webp"
		)
	) {
		return 1;
	} else {
		return 0;
	}
	return 0;
} # IsImageFile()

sub IsTextFile { # $file ; returns 1 if txt file, 0 if not
	my $file = shift;
	if (!$file) {
		return 0;
	}
	chomp $file;
	if (!$file) {
		return 0;
	}

	if (
		-e $file
			&&
		(
			substr(lc($file), length($file) -4, 4) eq ".txt"
		)
	) {
		return 1;
	} else {
		return 0;
	}
	return 0;
} # IsTextFile()

sub IsItem { # $string ; returns 1 if parameter is in item hash format (40 or 8 lowercase hex chars), 0 otherwise
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/^[0-9a-f]{40}$/) {
		return 1;
	}

	if ($string =~ m/^[0-9a-f]{8}$/) {
		return 1;
	}

	return 0;
}

sub IsMd5 { # returns 1 if parameter is md5 hash, 0 otherwise
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[a-fA-F0-9]{32}/) {
		return 1;
	} else {
		return 0;
	}
}

sub IsFingerprint { # returns 1 if parameter is a user fingerprint, 0 otherwise
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[A-F0-9]{16}/) {
		return 1;
	} else {
		return 0;
	}
}

sub GpgParse {
	# $filePath = path to file containing the text
	#
	# $returnValues{'isSigned'} = whether the message has a valid signature: 0 or 1 for valid signature
	# $returnValues{'signTimestamp'} = timestamp of gpg signature, if any
	# $returnValues{'text'} = original text
	# $returnValues{'message'} = message text without framing
	# $returnValues{'key'} = fingerprint of signer
	# $returnValues{'alias'} = alias of signer, if they've added one by submitting their public key
	# $returnValues{'keyExpired'} = whether the key has expired: 0 for not expired, 1 for expired
	# $returnValues{'gitHash'} = git's hash of the file's contents
	# $returnValues{'verifyError'} = whether there was an error with parsing the message

	my %returnValues;

	my $filePath = shift;
	if (!$filePath || !-e $filePath || -d $filePath) {
		WriteLog('GpgParse: warning: $filePath missing, non-existent, or a directory');
		return;
	}
	WriteLog("GpgParse($filePath)");

	if ($filePath =~ m/([a-zA-Z0-9\.\/]+)/) {
		$filePath = $1;
	} else {
		WriteLog('GpgParse: sanity check failed on $filePath, returning');
		return '';
	}

	my $fileHash = GetFileHash($filePath);

	my $cachePathStderr = './cache/' . GetMyCacheVersion() . '/gpg_stderr';
	my $cachePathMessage = './cache/' . GetMyCacheVersion() . '/gpg_message';

	if ($cachePathStderr =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathStderr = $1;
	} else {
		WriteLog('GpgParse: sanity check failed, $cachePathStderr = ' . $cachePathStderr);
		return;
	}

	if ($cachePathMessage =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathMessage = $1;
	} else {
		WriteLog('GpgParse: sanity check failed, $cachePathMessage = ' . $cachePathMessage);
		return;
	}

	my $pubKeyFlag = 0;

	if (!-e "$cachePathStderr/$fileHash.txt") {
		my $fileContents = GetFile($filePath);

		my $gpgPubkey = '-----BEGIN PGP PUBLIC KEY BLOCK-----';
		my $gpgMessage = '-----BEGIN PGP SIGNED MESSAGE-----';
		my $gpgEncrypted = '-----BEGIN PGP MESSAGE-----';

		my $gpgCommand = 'gpg --pinentry-mode=loopback --batch ';

		if (index($fileContents, $gpgPubkey) > -1) {
			$gpgCommand .= '--import ';
			$pubKeyFlag = 1;
		}
		elsif (index($fileContents, $gpgMessage) > -1) {
			$gpgCommand .= '--decrypt ';
		}
		elsif (index($fileContents, $gpgEncrypted) > -1) {
			$gpgCommand .= '--decrypt ';
		}

		if ($fileHash =~ m/^([0-9a-f]+)$/) {
			$fileHash = $1;
		} else {
			WriteLog('GpgParse: sanity check failed, $fileHash = ' . $fileHash);
			return;
		}

		$gpgCommand .= "$filePath ";
		$gpgCommand .= ">$cachePathMessage/$fileHash.txt ";
		$gpgCommand .= "2>$cachePathStderr/$fileHash.txt ";

		WriteLog('GpgParse: $gpgCommand = ' . $gpgCommand);

		system($gpgCommand);
	}

	my $gpgStderrOutput = GetCache("gpg_stderr/$fileHash.txt");

	WriteLog('GpgParse: $gpgStderrOutput: ' . "\n" . $gpgStderrOutput);

	if ($gpgStderrOutput) {
		if ($gpgStderrOutput =~ /([0-9A-F]{40})/) {
			$returnValues{'key_long'} = $1;
		}
		if ($gpgStderrOutput =~ /([0-9A-F]{16})/) {
			$returnValues{'isSigned'} = 1;
			$returnValues{'key'} = $1;
		}
		if ($gpgStderrOutput =~ /Signature made (.+)/) {
			# my $gpgDateEpoch = #todo convert to epoch time
			$returnValues{'signTimestamp'} = $1;
		}

		if ($pubKeyFlag) {
			# parse gpg's output as public key
			if ($gpgStderrOutput =~ /\"([ a-zA-Z0-9<>\@.()\\\/]+)\"/) {
				# we found something which looks like a name
				my $aliasReturned = $1;
				$aliasReturned =~ s/\<(.+\@.+?)\>//g; # if has something which looks like an email, remove it

				$returnValues{'alias'} = $aliasReturned;
			} else {
				$returnValues{'alias'} = '?????';
			}

			my $name = $returnValues{'alias'};
			my $fingerprint = $returnValues{'key'};

			if (!$name) {
				WriteLog('GpgParse: warning: no name/alias from file ' . $filePath);
				$name = '(name)';
			}
			if (!$fingerprint) {
				WriteLog('GpgParse: warning: no fingerprint/key from file ' . $filePath);
				$fingerprint = '(fingerprint)';
			}

			my $message;
			$message = GetTemplate('message/user_reg.template');
			$message =~ s/\$name/$name/g;
			$message =~ s/\$fingerprint/$fingerprint/g;
			$returnValues{'message'} = $message;
		} # $pubKeyFlag
		else {
			# not a pubkey, just take whatever pgp output for us
			$returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
		}
	} # $gpgStderrOutput
	# else {
	# 	# for some reason gpg didn't output anything, so just put the original message
	# 	$returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
	# }
	$returnValues{'text'} = GetFile($filePath);
	$returnValues{'verifyError'} = 0;

	return %returnValues;
} # GpgParse()

sub EncryptMessage { # Encrypts message for target key (doesn't do anything yet)
	my $targetKey = shift;
	# file path
	chomp($targetKey);

	#todo
}

sub AddItemToConfigList { # Adds a line to a list stored in config
	# $configPath = reference to setting stored in config
	# $item = item to add to the list (appended to the file)

	my $configPath = shift;
	chomp($configPath);

	my $item = shift;
	chomp($item);

	# get existing list
	my $configList = GetConfig($configPath);

	if ($configList) {
		# if there is something already there, go through all this stuff
		my @configListAsArray = split("\n", $configList);

		foreach my $h (@configListAsArray) {
			# loop through each item on list and check if already exists
			if ($h eq $item) {
				# item already exists in list, nothing else to do
				return;
			}
		}

		#append to list
		$configList .= "\n";
		$configList .= $item;
		$configList = trim($configList);
		$configList .= "\n";
	} else {
		# if nothing is there, just add the requested item
		$configList = $item . "\n";
	}

	# remove any blank lines
	$configList =~ s/\n\n/\n/g;

	# put it back
	PutConfig($configPath, $configList);
}

sub FormatForWeb { # $text ; replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);

	# these have been moved to format for textart
	#	$text =~ s/\n /<br>&nbsp;/g;
	#	$text =~ s/^ /&nbsp;/g;
	#	$text =~ s/  / &nbsp;/g;

	$text =~ s/\n\n/<p>/g;
	$text =~ s/\n/<br>/g;

	# this is more flexible than \n but may cause problems with unicode
	# for example, it recognizes second half of russian "x" as \R
	# #regexbugX
	# $text =~ s/\R\R/<p>/g;
	# $text =~ s/\R/<br>/g;

	if (GetConfig('admin/html/allow_tag/code')) {
		$text =~ s/&lt;code&gt;(.*?)&lt;\/code&gt;/<code>$1<\/code>/msgi;
		# /s = single-line (changes behavior of . metacharacter to match newlines)
		# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
		# /g = global (all instances)
		# /i = case-insensitive
	}

	return $text;
}

sub FormatForRss { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	$text =~ s/\n/<br \/>\n/g;

	return $text;
}

sub TextartForWeb { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	$text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	$text =~ s/\n/<br>\n/g;

	#htmlspecialchars(
	## nl2br(
	## str_replace(
	## '  ', ' &nbsp;',
	# htmlspecialchars(
	## $quote->quote))))?><? if ($quote->comment) echo(htmlspecialchars('<br><i>Comment:</i> '.htmlspecialchars($quote->comment)
	#));?><?=$tt_c?></description>

	return $text;
}

sub SurveyForWeb { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	my $i = 0;

	$text = HtmlEscape($text);
	# $text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	# $text =~ s/\n/<br>\n/g;
	# $text =~ s/<br>/'<br><input type=text size=80 name=txt'.$i++.'><br>'/ge;
	# $text =~ s/<br>/<br><br>/g;
	$text = '<textarea wrap=wrap cols=80 rows=24>'.$text.'</textarea>';
	$text = '<form action=/post.html>'.$text.'<br><input type=submit value=Send></form>';

	#htmlspecialchars(
	## nl2br(
	## str_replace(
	## '  ', ' &nbsp;',
	# htmlspecialchars(
	## $quote->quote))))?><? if ($quote->comment) echo(htmlspecialchars('<br><i>Comment:</i> '.htmlspecialchars($quote->comment)
	#));?><?=$tt_c?></description>

	return $text;
}

sub WriteMessage { # Writes timestamped message to console (stdout)
	my $text = shift;
	chomp $text;

	state $lastText;

	if ($text eq '.' || length($text) == 1) {
		$lastText = $text;

		state @chars;
		if (!@chars) {
			#@chars = qw(, . - ' `); # may generate warning
			#@chars = (',', '.', '-', "'", '`');
			#@chars = ('.', ',');
			#@chars = (qw(0 1 2 3 4 5 6 7 8 9 A B C D E F));
		}

		#my @chars=('a'..'f','0'..'9');
		#print $chars[rand @chars];
		print $text;
		# my $randomString;
		# foreach (1..40) {
		# 	$randomString.=$chars[rand @chars];
		# }
		# return $randomString;

		return;
	}

	# just an idea
	# doesn't seem to work well because the console freezes up if there's no \n coming
	# if ($text =~ m/^[0-9]+$/) {
	# 	$lastText = $text;
	# 	print $text . " ";
	# 	return;
	# }

	WriteLog($text);
	my $timestamp = GetTime();

	if ($lastText eq '.' || length($lastText) == 1) {
		print "\n";
	}
	print "\n$timestamp $text\n";

	$lastText = $text;
}

my $lastVersion = GetConfig('current_version');
my $currVersion = GetMyVersion();

if (!$lastVersion) {
	$lastVersion = 0;
}

if ($lastVersion ne $currVersion) {
	WriteLog("$lastVersion ne $currVersion, posting changelog");

	#my $serverKey = `gpg --list-keys hikeserver`;

	#WriteLog("gpg --list-keys CCEA3752");
	#WriteLog($serverKey);

	my $changeLogFilename = 'changelog_' . GetTime() . '.txt';
	#todo this should be a template;
	my $changeLogMessage =
		'Software Updated to Version ' . substr($currVersion, 0, 8) . '..' . "\n\n" .
		'Installed software version has changed from ' . $lastVersion . ' to ' . $currVersion . "\n\n";

	if ($lastVersion) {
		#my $changeLogList = "Version has changed from $lastVersion to $currVersion";
		if ($lastVersion =~ m/^([0-9a-f]+)$/) {
			$lastVersion = $1;
		}
		if ($currVersion =~ m/^([0-9a-f]+)$/) {
			$currVersion = $1;
		}
		my $changeLogListCommand = "git log --oneline $lastVersion..$currVersion";
		my $changeLogList = `$changeLogListCommand`;
		$changeLogList = trim($changeLogList);
		$changeLogMessage .= "$changeLogList";
	} else {
		$changeLogMessage .= 'No changelog will be generated because $lastVersion is false';
	}

	$changeLogMessage .= "\n\n#changelog";

	PutFile("$TXTDIR/$changeLogFilename", $changeLogMessage);

	ServerSign("$TXTDIR/$changeLogFilename");

	PutConfig('current_version', $currVersion);
}

my $lastAdmin = GetConfig('current_admin');
my $currAdmin = GetRootAdminKey();

if (!$lastAdmin) {
	$lastAdmin = 0;
}

if ($currAdmin) {
	if ($lastAdmin ne $currAdmin) {
		WriteLog("$lastAdmin ne $currAdmin, posting change-admin");

		my $changeAdminFilename = 'changeadmin_' . GetTime() . '.txt';
		my $changeAdminMessage = 'Admin has changed from ' . $lastAdmin . ' to ' . $currAdmin;

		PutFile("$TXTDIR/$changeAdminFilename", $changeAdminMessage);

		ServerSign("$TXTDIR/$changeAdminFilename");

		PutConfig("current_admin", $currAdmin);

		require('./sqlite.pl');

		if ($lastAdmin) {
			DBAddPageTouch('author', $lastAdmin);
		}
		if ($currAdmin) {
			DBAddPageTouch('author', $currAdmin);
		}
	}
}

sub ServerSign { # Signs a given file with the server's key
	# If config/admin/server_key_id exists
	#   Otherwise, does nothing
	# Replaces file with signed version
	#
	# Server key should be stored in gpg keychain
	# Key ID should be stored in config/admin/server_key_id
	#

	WriteLog('ServerSign()');

	# get filename from parameters and ensure it exists
	my $file = shift;
	if (!-e $file) {
		return;
	}

	WriteLog('ServerSign(' . $file . ')');

	# see if config/admin/server_key_id is set
	my $serverKeyId = trim(GetConfig('admin/server_key_id'));

	WriteLog('$serverKeyId = ' . $serverKeyId);

	# return if it is not
	if (!$serverKeyId) {
		return;
	}

	# verify that key exists in gpg keychain
	WriteLog("gpg --list-keys $serverKeyId");

	my $serverKey = `gpg --list-keys $serverKeyId`;
	WriteLog($serverKey);

	# if public key has not been published yet, do it
	if (!-e "$TXTDIR/server.key.txt") {
		WriteLog("gpg --batch --yes --armor --export $serverKeyId");
		my $gpgOutput = `gpg --batch --yes --armor --export $serverKeyId`;

		PutFile($TXTDIR . '/server.key.txt', $gpgOutput);

		WriteLog($gpgOutput);
	} #todo here we should also verify that server.key.txt matches server_key_id

	# if everything is ok, proceed to sign
	if ($serverKey) {
		WriteLog("We have a server key, so go ahead and sign the file.");

		WriteLog("gpg --batch --yes -u $serverKeyId --clearsign \"$file\"");
		system("gpg --batch --yes -u $serverKeyId --clearsign \"$file\"");

		if (-e "$file.asc") {
			WriteLog("Sign appears successful, rename .asc file to .txt");
			rename("$file.asc", "$file");
		} else {
			WriteLog("Tried to sign, but no .asc file. PROBLEM!!!");
		}
	} else {
		#$changeLogMessage .= "\n\n(No server key found, not signing.)";
		WriteLog("No server key found, will not sign changelog.");
	}
}

sub FormatDate { # $epoch ; formats date depending on how long ago it was
	my $epoch = shift;

	my $time = GetTime();

	my $difference = $time - $epoch;

	my $formattedDate = '';

	if ($difference < 86400) {
	# less than a day, return 24-hour time
		$formattedDate = strftime '%H:%M', localtime $epoch;
	} elsif ($difference < 86400 * 30) {
	# less than a month, return short date
		$formattedDate = strftime '%m/%d', localtime $epoch;
	} else {
	# more than a month, return long date
		$formattedDate = strftime '%a, %d %b %Y', localtime $epoch;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;
	}

	return $formattedDate;
}

sub GetTimestampWidget { # $time ; returns timestamp widget
	#todo format on server-side for no-js clients
	my $time = shift;
	if ($time) {
		chomp $time;
	} else {
		$time = 0;
	}
	WriteLog('GetTimestampWidget("' . $time . '")');

	state $epoch; # state of config
	if (!defined($epoch)) {
		$epoch = GetConfig('html/timestamp_epoch');
	}

	if (!$time =~ m/^[0-9]+$/) {
		WriteLog('GetTimestampWidget: warning: sanity check failed!');
		return '';
	}

	my $widget = '';
	if ($epoch) {
		# epoch-formatted timestamp, simpler template
		$widget = GetTemplate('widget/timestamp_epoch.template');
		$widget =~ s/\$timestamp/$time/;
	} else {
		WriteLog('GetTimestampWidget: $epoch = false');
		$widget = GetTemplate('widget/timestamp.template');

		$widget = str_replace("\n", '', $widget);
		# if we don't do this, the link has an extra space

		my $timeDate = $time;
		$timeDate = FormatDate($time);
		# Alternative formats tried
		# my $timeDate = strftime '%c', localtime $time;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;

		# replace into template
		$widget =~ s/\$timestamp/$time/g;
		$widget =~ s/\$timeDate/$timeDate/g;
	}

	chomp $widget;
	return $widget;
} # GetTimestampWidget()

sub DeleteFile { # $fileHash ; delete file with specified file hash (incomplete)
	my $fileHash = shift;
	if ($fileHash) {
	}
} # DeleteFile()

sub IsFileDeleted { # $file, $fileHash ; checks for file's hash in deleted.log and removes it if found
# only one or the other is required
    my $file = shift;
	WriteLog("IsFileDeleted($file)");

    if ($file && !-e $file) {
		# file already doesn't exist
		WriteLog('IsFileDeleted: file already gone, returning 1');
		return 1;
    }

    my $fileHash = shift;
    if (!$fileHash) {
		WriteLog('IsFileDeleted: $fileHash not specified, calling GetFileHash()');
    	$fileHash = GetFileHash($file);
    }
	WriteLog("IsFileDeleted($file, $fileHash)");

    # if the file is present in deleted.log, get rid of it and its page, return
    if ($fileHash && -e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
        # write to log
        WriteLog("IsFileDeleted: $fileHash exists in deleted.log, removing $file");

		{
			# unlink the file itself
			if (-e $file) {
				unlink($file);
			}

			WriteLog('$fileHash = ' . $fileHash);

			my $htmlFilename = GetHtmlFilename($fileHash);

			if ($htmlFilename) {
				$htmlFilename = $HTMLDIR . '/' . $htmlFilename;

				if (-e $htmlFilename) {
					unlink($htmlFilename);
				}
			}


        }

        return 1;
    }

    # if the file is present in deleted.log, get rid of it and its page, return
    if ($fileHash && -e 'log/archived.log' && GetFile('log/archived.log') =~ $fileHash) {
        # write to log
        WriteLog("... $fileHash exists in archived.log, archiving $file");

		{
			# unlink the file itself
			if (-e $file) {
				my $archiveDir = './archive';
				my $newFilename = $archiveDir . '/' . TrimPath($file) . "." . GetFileExtension($file);
				my $suffixCounter = '';
				while (-e $newFilename . $suffixCounter) {
					if (!$suffixCounter) {
						$suffixCounter = 1;
					} else {
						$suffixCounter++;
					}
				}
				rename($file, $newFilename);
				#unlink($file);
			}

			WriteLog('$fileHash = ' . $fileHash);

			my $htmlFilename = GetHtmlFilename($fileHash);

			if ($htmlFilename) {
				$htmlFilename = $HTMLDIR . '/' . $htmlFilename;

				if (-e $htmlFilename) {
					unlink($htmlFilename);
				}
			}


        }

        return 1;
    }

    return 0;
} # IsFileDeleted()

sub file_exists { # $file ; port of php file_exists()
	my $file = shift;
	if (!$file) {
		return 0;
	}
	if (-e $file && -f $file && !-d $file) {
		return 1;
	} else {
		return 0;
	}
	return 0; #unreachable code
}

sub ExpireAvatarCache { # $fingerprint ; removes all caches for alias
	# DeleteAvatarCache ExpireAvatarCache ExpireAliasCache {

	my $key = shift;
	WriteLog("ExpireAvatarCache($key)");
	if (!IsFingerprint($key) && $key ne '*') {
		WriteLog('ExpireAvatarCache: warning: sanity check failed');
		return 0;
	}

	my $themeName = GetConfig('html/theme');
	UnlinkCache('avatar/' . $themeName . '/' . $key);
	UnlinkCache('avatar.color/' . $themeName . '/' . $key);
	UnlinkCache('avatar.plain/' . $themeName . '/' . $key);
} # ExpireAvatarCache()

sub GetItemEasyFind { #returns Easyfind strings for item
	WriteLog('GetItemEasyFind()');

	my $itemHash = shift;
	if (!$itemHash) {
		return;
	}
	chomp $itemHash;
	if (!IsItem($itemHash)) {
		return;
	}

	WriteLog("GetItemEasyFind($itemHash)");

	my @easyFindArray;
	while ($itemHash) {
		my $fragment = substr($itemHash, 0, 5);
		if ($fragment =~ m/[a-f]/) {
			push @easyFindArray, $fragment;
		}
		$itemHash = substr($itemHash, 5);
	}

	my $easyFindString = join(' ', @easyFindArray);

	return $easyFindString;
}

sub GetMessageCacheName {
	my $itemHash = shift;
	chomp($itemHash);

	if (!IsItem($itemHash)) {
		WriteLog('GetMessageCacheName: sanity check failed');
		return '';
	}

	my $messageCacheName = "./cache/" . GetMyCacheVersion() . "/message/$itemHash";
	return $messageCacheName;
}

sub GetItemMessage { # $itemHash, $filePath ; retrieves item's message using cache or file path
	WriteLog('GetItemMessage()');

	my $itemHash = shift;
	if (!$itemHash) {
		return;
	}

	chomp $itemHash;

	if (!IsItem($itemHash)) {
		return;
	}

	WriteLog("GetItemMessage($itemHash)");

	my $message;
	my $messageCacheName = GetMessageCacheName($itemHash);

	if (-e $messageCacheName) {
		$message = GetFile($messageCacheName);
	} else {
		my $filePath = shift;
		#todo sanitize/sanitycheck

		$message = GetFile($filePath);
	}

	return  $message;
}

sub GetItemMeta { # retrieves item's metadata
	# $itemHash, $filePath

	WriteLog('GetItemMeta()');

	my $itemHash = shift;
	if (!$itemHash) {
		return;
	}

	chomp $itemHash;
	if (!IsItem($itemHash)) {
		return;
	}

	WriteLog("GetItemMeta($itemHash)");

	my $filePath = shift;
	if (!$filePath) {
		return;
	}

	chomp $filePath;

	if (-e $filePath) {
		my $fileHash = GetFileHash($filePath);

		if ($fileHash eq $filePath) {
			my $metaFileName = $filePath . '.nfo';

			if (-e $metaFileName) {
				my $metaText;

				$metaText = GetFile($metaFileName);

				return $metaText;
			}
			else {
				return; # no meta file
			}
		} else {
			WriteLog('GetItemMeta: WARNING: called with hash which did not match file hash');

			return;
		}
	} else {
		return; # file doesn't exist
	}
} # GetItemMeta

sub AppendItemMeta { # appends to item's metadata
	# $
}

sub GetPrefixedUrl { # returns url with relative prefix 
	my $url = shift;
	chomp $url;

	return $url;
}

sub UpdateUpdateTime { # updates cache/system/last_update_time, which is used by the stats page
	my $lastUpdateTime = GetTime();

	PutCache("system/last_update_time", $lastUpdateTime);
}

sub RemoveEmptyDirectories { #looks for empty directories under $path and removes them
	my $path = shift;

	#todo probably more sanitizing

	$path = trim($path);
	if (!$path) {
		return;
	}

	#system('find $path -type d -empty -delete'); #todo uncomment when bugs fixed
}

sub RemoveOldItems {
	my $query = "
		SELECT * FROM item_flat WHERE file_hash NOT IN (
			SELECT file_hash FROM item_flat
			WHERE
				',' || tags_list || ',' like '%approve%'
					OR
				file_hash IN (
					SELECT item_hash
					FROM item_parent
					WHERE parent_hash IN (
						SELECT file_hash FROM item_flat WHERE ',' || tags_list || ',' LIKE '%approve%'
					)
				)
		)
		ORDER BY add_timestamp
	";
}

sub GetFileHashPath { # $file ; Returns text file's standardized path given its filename
	# e.g. /01/23/0123abcdef0123456789abcdef0123456789a.txt
	my $file = shift;

	# file should exist and not be a directory
	if (!-e $file || -d $file) {
		WriteLog('GetFileHashPath: warning: $file sanity check failed, $file = ' . $file);
		return '';
	}
	WriteLog("GetFileHashPath($file)");

	if ($file) {
		my $fileHash = GetFileHash($file);
		my $fileHashPath = GetPathFromHash($fileHash);
		return $fileHashPath;
	}
} # GetFileHashPath()

sub GetPathFromHash { # gets path of text file based on hash
	# relies on config/admin/organize_files = 1
	my $fileHash = shift;
	chomp $fileHash;

	if (!$fileHash) {
		return;
	}

	if (!-e $TXTDIR . '/' . substr($fileHash, 0, 2)) {
		system('mkdir ' . $TXTDIR . '/' . substr($fileHash, 0, 2));
	}

	if (!-e $TXTDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)) {
		system('mkdir ' . $TXTDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2));
	}

	my $fileHashSubDir = substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2);

	if ($fileHash) {
		my $fileHashPath = $TXTDIR . '/' . $fileHashSubDir . '/' . $fileHash . '.txt';

		WriteLog("\$fileHashPath = $fileHashPath");

		return $fileHashPath;
	}
}

sub Sha1Test {
	print "\n";

	print GetFileHash('utils.pl');

	print "\n";

	print(`sha1sum utils.pl | cut -f 1 -d ' '`);

	# print "\n";

	print(`php -r "print(sha1_file('utils.pl'));"`);

	print "\n";
}

sub GetPasswordLine { # $username, $password ; returns line for .htpasswd file
	my $username = shift;
	chomp $username;

	my $password = shift;
	chomp $password;

	return $username.":".crypt($password,$username)."\n";
} # GetPasswordLine()

sub OrganizeFile { # $file ; renames file based on hash of its contents
	# returns new filename
	# filename is obtained using GetFileHashPath()
	my $file = shift;
	chomp $file;

	if (!-e $file) {
		#file does not exist.
		WriteLog('OrganizeFile: warning: called on non-existing file: ' . $file);
		return '';
	}

	if (!GetConfig('admin/organize_files')) {
		WriteLog('OrganizeFile: warning: admin/organize_files was false, returning.');
		return $file;
	}

	if ($file eq "$TXTDIR/server.key.txt" || $file eq $TXTDIR || -d $file) {
		# $file should not be server.key, the txt directory, or a directory
		WriteLog('OrganizeFile: file is on ignore list, ignoring.');
		return $file;
	}

	if (GetConfig('admin/dev_mode')) {
		WriteLog('OrganizeFile: dev_mode is on, returning');
		return $file;
	}

	# organize files aka rename to hash-based path
	my $fileHashPath = GetFileHashPath($file);

	# turns out this is actually the opposite of what needs to happen
	# but this code snippet may come in handy
	# if (index($fileHashPath, $SCRIPTDIR) == 0) {
	# 	WriteLog('IndexTextFile: hash path begins with $SCRIPTDIR, removing it');
	# 	$fileHashPath = str_replace($SCRIPTDIR . '/', '', $fileHashPath);
	# } # index($fileHashPath, $SCRIPTDIR) == 0
	# else {
	# 	WriteLog('IndexTextFile: hash path does NOT begin with $SCRIPTDIR, leaving it alone');
	# }

	if ($fileHashPath) {
		if ($file eq $fileHashPath) {
			# Does it match? No action needed
			WriteLog('OrganizeFile: hash path matches, no action needed');
		}
		elsif ($file ne $fileHashPath) {
			# It doesn't match, fix it
			WriteLog('OrganizeFile: hash path does not match, organize');
			WriteLog('OrganizeFile: Before: ' . $file);
			WriteLog('OrganizeFile: After: ' . $fileHashPath);

			if (-e $fileHashPath) {
				# new file already exists, rename only if not larger
				WriteLog("OrganizeFile: warning: $fileHashPath already exists!");

				if (-s $fileHashPath > -s $file) {
					unlink ($file);
				} else {
					rename ($file, $fileHashPath);
				}
			} # -e $fileHashPath
			else {
				# new file does not exist, safe to rename
				rename ($file, $fileHashPath);
			}

			# if new file exists
			if (-e $fileHashPath) {
				$file = $fileHashPath; #don't see why not... is it a problem for the calling function?
			} else {
				WriteLog("Very strange... \$fileHashPath doesn't exist? $fileHashPath");
			}
		} # $file ne $fileHashPath
		else {
			WriteLog('IndexTextFile: it already matches, next!');
			WriteLog('$file: ' . $file);
			WriteLog('$fileHashPath: ' . $fileHashPath);
		}
	} # $fileHashPath

	WriteLog("OrganizeFile: returning $file");
	return $file;
} # OrganizeFile()


sub VerifyThirdPartyAccount {
	my $fileHash = shift;
	my $thirdPartyUrl = shift;
} # verify token

sub ProcessTextFile { # $file ; add new text file to index
	my $file = shift;
	if ($file eq 'flush') {
		IndexFile('flush');
	}
	my $relativePath = File::Spec->abs2rel ($file,  $SCRIPTDIR);
	if ($file ne $relativePath) {
		$file = $relativePath;
	}
	my $addedTime = GetTime2();
	WriteLog('ProcessTextFile: $file = ' . $file . '; $addedTime = ' . $addedTime);

	# get file's hash from git
	my $fileHash = GetFileHash($file);
	if (!$fileHash) {
		return 0;
	}

	WriteLog('ProcessTextFile: $fileHash = ' . $fileHash);

	# if deletion of this file has been requested, skip
	if (IsFileDeleted($file, $fileHash)) {
		WriteLog('ProcessTextFile: IsFileDeleted() returned true, skipping');
		WriteLog('ProcessTextFile: return 0');

		return 0;
	}

	if (GetConfig('admin/organize_files')) {
		my $fileNew = OrganizeFile($file);
		if ($fileNew eq $file) {
			WriteLog('ProcessTextFile: $fileNew eq $file');
		} else {
			WriteLog('ProcessTextFile: changing $file to new value per OrganizeFile()');
			$file = $fileNew;
			WriteLog('ProcessTextFile: $file = ' . $file);
		}
	} else {
		WriteLog("ProcessTextFile: organize_files is off, continuing");
	}

	if (!GetCache('indexed/' . $fileHash)) {
		WriteLog('ProcessTextFile: ProcessTextFile(' . $file . ') not in cache/indexed, calling IndexFile');

		IndexFile($file);
		IndexFile('flush');

		PutCache('indexed/' . $fileHash, '1');
	} else {
		# return 0 so that this file is not counted
		WriteLog('ProcessTextFile: already indexed ' . $fileHash . ', return 0');
		return 0;
	}

	WriteLog('ProcessTextFile: return ' . $fileHash);
	return $fileHash;

	# run commands to
	#	  add changed file to git repo
	#    commit the change with message 'hi' #todo
	#    cd back to pwd


	#		# below is for debugging purposes
	#
	#		my %queryParams;
	#		$queryParams{'where_clause'} = "WHERE file_hash = '$fileHash'";
	#
	#		my @files = DBGetItemList(\%queryParams);
	#
	#		WriteLog("Count of new items for $fileHash : " . scalar(@files));

} # ProcessTextFile()

1;
