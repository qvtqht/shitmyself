#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use 5.010;
use POSIX;
use POSIX 'strftime';
use Data::Dumper;

#use Devel::StackTrace;

use File::Basename qw( fileparse );
use File::Path qw( make_path ); ## todo replace this with own version which is not fragile
use File::Spec;

use Date::Parse;

use lib 'lib';

use URI::Encode qw(uri_decode);
use URI::Escape;
#use HTML::Entities qw(encode_entities);
use Storable;
#use Time::Piece;
use Digest::SHA qw(sha1_hex);


# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`; #hardcode #todo
chomp $SCRIPTDIR;

# make a list of some directories that need to exist
my @dirsThatShouldExist = qw(log html html/txt cache html/author html/action html/top config);
push @dirsThatShouldExist, 'cache/' . GetMyVersion();
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/key';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/file';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/avatar';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/message';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/gpg';

# create directories that need to exist
foreach(@dirsThatShouldExist) {
	if (!-d && !-e $_) {
		mkdir $_;
	}
	if (!-e $_ || !-d $_) {
		die("$_ should exist, but it doesn't. aborting.");
	}
}

sub WriteLog {  # Writes timestamped message to console (stdout) AND log/log.log
	# Only if debug mode is enabled
	if (-e 'config/admin/debug') {
		my $text = shift;

		if (!$text) {
			$text = '(empty string)';
		}

		chomp $text;

		my $timestamp = GetTime();

		AppendFile("log/log.log", $timestamp . " " . $text);

		if (-e 'config/admin/prev_build_duration') {
			state $prevBuildDuration;
			$prevBuildDuration = $prevBuildDuration || trim(GetFile('config/admin/prev_build_duration'));
			#bug here

			if ($prevBuildDuration) {
				state $buildBegin;
				$buildBegin = $buildBegin || trim(GetFile('config/admin/build_begin'));

				my $approximateProgress = (GetTime() - $buildBegin) / $prevBuildDuration * 100;
#				print '(~' . $approximateProgress . '%) ' . $timestamp . " " . $text . "\n";
			} else {
#				print $timestamp . " " . $text . "\n";
			}
		} else {
#			print $timestamp . " " . $text . "\n";
		}

		return 1;
	}

	return 0;
}


# capture gpg's stderr output if capture_stderr_output is set
# the value of $gpgStderr will be appended to gpg commands in GpgParse()
# this block should be moved into GpgParse() probably
my $gpgStderr;
if (GetConfig('admin/gpg/capture_stderr_output')) {
	$gpgStderr = '2>&1';
} else {
	if (GetConfig('admin/debug')) {
		$gpgStderr = '';
	} else {
		$gpgStderr = ' 2>/dev/null';
	}
}

#sub GitPipe { # runs git with proper prefix, sufix, and post-command pipe
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
#	my $gitCommandPrefix = 'git --git-dir=html/txt/.git --work-tree=html/txt ';
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

# figure out whether to use gpg or gpg2 command for gpg stuff
# it might be stored in config
my $gpgCommand = trim(GetConfig('admin/gpg/gpg_command'));
if (!$gpgCommand) {
	if (GetConfig('admin/gpg/use_gpg2')) {
		$gpgCommand = 'gpg2';
	}
	else {
		# if not in config, use whatever version we have as `gpg`
		if (GetGpgMajorVersion() eq '2') {
			$gpgCommand = 'gpg2';
		}
		else {
			$gpgCommand = 'gpg';
		}
	}
}
WriteLog("utils.pl init: admin/gpg/use_gpg2 = " . GetConfig('admin/gpg/use_gpg2'));
WriteLog("utils.pl init: \$gpgCommand = $gpgCommand");

sub GetCache { # get cache by cache key
	# comes from cache/ directory, under current git commit
	# this keeps cache version-specific

	#todo sanity checks
	my $cacheName = shift;
	chomp($cacheName);
	
	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyVersion();
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

sub EnsureSubdirs { # ensures that subdirectories for a file exist
# takes file's path as argument

# todo remove requirement of external module
	my $fullPath = shift;

	my ( $file, $dirs ) = fileparse $fullPath;
	if ( !$file ) {
		return;
		$fullPath = File::Spec->catfile($fullPath, $file);
	}

	if ( !-d $dirs && !-e $dirs ) {
		make_path $dirs or WriteLog("Failed to create path: $dirs");
	}
}

sub PutCache { # stores value in cache; $cacheName, $content

#todo sanity checks and error handling
	my $cacheName = shift;
	chomp($cacheName);

	my $content = shift;
	chomp($content);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	return PutFile($cacheName, $content);
}

sub UnlinkCache { # removes cache by unlinking file it's stored in
	my $cacheName = shift;
	chomp($cacheName);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	if (-e $cacheName) {
		unlink($cacheName);
	}
}

sub CacheExists { # Check whether specified cache entry exists, return 1 (exists) or 0 (not)
	my $cacheName = shift;
	chomp($cacheName);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName;

	if (-e $cacheName) {
		return 1;
	} else {
		return 0;
	}
}

sub GetGpgMajorVersion { # get the first number of the version which 'gpg --version' returns
# expecting 1 or 2

# todo sanity checks
	state $gpgVersion;

	if ($gpgVersion) {
		return $gpgVersion;
	}

	$gpgVersion = `gpg --version`;
	WriteLog('GetGpgMajorVersion: gpgVersion = ' . $gpgVersion);

	$gpgVersion =~ s/\n.+//g;
	$gpgVersion =~ s/gpg \(GnuPG\) ([0-9]+).[0-9]+.[0-9]+/$1/;
	$gpgVersion =~ s/[^0-9]//g;

	return $gpgVersion;
}

sub GetMyVersion { # Get the currently installed version (current commit's hash from git)
# returns current git commit hash as version
	state $myVersion;

	if ($myVersion) {
		return $myVersion;
	}

	$myVersion = `git rev-parse HEAD`;

	chomp($myVersion);

	return $myVersion;
}


sub WriteConfigFromDatabase { # Writes contents of 'config' table in database to config/ directory (unfinished)
#	print("1");
#	my $query = "SELECT * FROM config_latest";
#
#	my $configSet = SqliteQuery2($query);
#
#	my @configSetArray = @{$configSet};
#
#	while (@configSetArray) {
#		my $configLineRef = shift @configSetArray;
#		my @configLine = @{$configLineRef};
#		WriteLog(Data::Dumper->Dump(@configLine));
##
##		my $configKey = shift @configSetArray;
##		my $configValue = shift @configSetArray;
##		my $configTimestamp = shift @configSetArray;
#
##		PutConfig($configKey, $configValue);
#	}
#
#	#print(Data::Dumper->Dump($configSet));
##
##	for my $config (@{$configSet}) {
##		WriteLog(Data::Dumper->Dump($config));
##	}
#	#die();
#
#	#todo finish this
#
#	#get
#
#	#write to config/
}

sub GetString { # Returns string from config/string/en/..., with special rules:
# #todo look up locale, not hard-coded to en
	my $stringKey = shift;
	my $language = shift;

	if (!$language) {
		$language = GetConfig('language');
	}

	if (!$language) {
		$language = 'en';
	}

	state %strings;

	if (!defined($strings{$stringKey})) {
		my $string = GetConfig('string/' . $language . '/'.$stringKey);

		if ($string) {
			chomp ($string);

	    	$strings{$stringKey} = $string;
		} else {
			return $stringKey;
		}
	}

	if (defined($strings{$stringKey})) {
		return $strings{$stringKey};
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


sub GetFileHash { # $fileName ; returns git's hash of file contents
	WriteLog("GetFileHash()");

	my $fileName = shift;

	chomp $fileName;

	WriteLog("GetFileHash($fileName)");

	return sha1_hex(GetFile($fileName));
#
#	my $gitOutput = GitPipe('hash-object -w "' . $fileName. '"');
#
#	if ($gitOutput) {
#		WriteLog($gitOutput);
#		chomp($gitOutput);
#
#		WriteLog("GetFileHash($fileName) = $gitOutput");
#
#		return $gitOutput;
#	} else {
#		return;
#	}
}

sub GetRandomHash { # returns a random sha1-looking hash, lowercase
	my @chars=('a'..'f','0'..'9');
	my $randomString;
	foreach (1..40) {
		$randomString.=$chars[rand @chars];
	}
	return $randomString;
}

sub GetTemplate { # returns specified template from HTML directory
# returns empty string if template not found
	my $filename = shift;
	chomp $filename;
#	$filename = "$SCRIPTDIR/template/$filename";

	WriteLog("GetTemplate($filename)");

	state %templateCache;

	if ($templateCache{$filename}) {
		return $templateCache{$filename};
	}

	if (GetConfig('admin/debug') && !-e ('config/template/' . $filename) && !-e ('default/template/' . $filename)) {
		WriteLog("GetTemplate: template/$filename does not exist, exiting");
	}

	my $template = GetConfig('template/' . $filename);

	$template .= "\n";

	if ($template) {
		$templateCache{$filename} = $template;
		return $template;
	} else {
		WriteLog("WARNING! GetTemplate() returning empty string for $filename.");
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

sub GetAvatar { # returns HTML avatar based on author key, using avatar.template
# affected by config/html/color_avatars
	WriteLog("GetAvatar(...)");

	state $avatarCacheDir;
	state $avatarTemplate;

	if (!$avatarCacheDir || !$avatarTemplate) {
		if (GetConfig('html/color_avatars')) {
			$avatarCacheDir = 'avatar.color/';
			$avatarTemplate = 'avatar.template';
		} else {
			$avatarCacheDir = 'avatar.plain/';
			$avatarTemplate = 'avatar2.template';
		}
	}

	state %avatarCache;

	my $gpgKey = shift;

	if (!$gpgKey) {
		return;
	}

	chomp $gpgKey;

	WriteLog("GetAvatar($gpgKey)");

	if ($avatarCache{$gpgKey}) {
		WriteLog('GetAvatar: found in %avatarCache');
		return $avatarCache{$gpgKey};
	}

	WriteLog("GetAvatar: continuing with cache lookup");

	my $avCacheFile = GetCache($avatarCacheDir . $gpgKey);
	if ($avCacheFile) {
		$avatarCache{$gpgKey} = $avCacheFile;
		return $avCacheFile;
	}

	my $avatar = GetTemplate($avatarTemplate);
	#todo strip all whtespace outside of html tags here to make it non-wrap

	if ($gpgKey) {
		my $alias = GetAlias($gpgKey);

		$alias = trim($alias);

		if (GetConfig('html/color_avatars')) {
			my $color1 = substr($gpgKey, 0, 6);
			my $color2 = substr($gpgKey, 3, 6);
			my $color3 = substr($gpgKey, 6, 6);
			my $color4 = substr($gpgKey, 9, 6);

			$alias = encode_entities2($alias);
			#$alias = encode_entities($alias, '<>&"');

			if ($alias) {
				#		my $char1 = substr($gpg_key, 12, 1);
				#		my $char2 = substr($gpg_key, 13, 1);
				#		my $char3 = substr($gpg_key, 14, 1);
				#
				#		$char1 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;
				#		$char2 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;
				#		$char3 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;

				my $char1 = '*';
				my $char2 = '*';

				$avatar =~ s/\$color1/$color1/g;
				$avatar =~ s/\$color2/$color2/g;
				$avatar =~ s/\$color3/$color3/g;
				#$avatar =~ s/\$color4/$color4/g;
				$avatar =~ s/\$alias/$alias/g;
				$avatar =~ s/\$char1/$char1/g;
				$avatar =~ s/\$char2/$char2/g;
				#$avatar =~ s/\$char3/$char3/g;
			}
			else {
				$avatar = '';
			}
		} else {
			$avatar =~ s/\$alias/$alias/g;
		}
	} else {
		$avatar = "";
	}

	my $colorUsername = GetThemeColor('username');
	$avatar =~ s/\$colorUsername/$colorUsername/g;

	$avatarCache{$gpgKey} = $avatar;

	if ($avatar) {
		PutCache($avatarCacheDir . $gpgKey, $avatar);
	}

	return $avatar;
}

sub GetAlias { # Returns alias for a GPG key
	my $gpgKey = shift;
	chomp $gpgKey;

	WriteLog("GetAlias($gpgKey)");

	my $alias = DBGetAuthorAlias($gpgKey);

	if ($alias && length($alias) > 24) {
		$alias = substr($alias, 0, 24);
	}

	if ($alias) {
		$alias =~ s|<.+?>||g;
		trim($alias);
		chomp $alias;

		return $alias;
	} else {
		return $gpgKey;
#		return 'unregistered';
	}
}

sub GetFile { # Gets the contents of file $fileName
	my $fileName = shift;

	if (!$fileName) {
#		WriteLog('attempting GetFile() without $fileName'); #todo writelog is too much dependencies for here
		if (-e 'config/admin/debug') {
			die('attempting GetFile() without $fileName');
		}
		return;
	}

	my $length = shift || 209715200;
	# default to reading a max of 2MB of the file. #scaling

	if (-e $fileName && !-d $fileName && open (my $file, "<", $fileName)) {
		my $return;

		read ($file, $return, $length);

		return $return;
	}

	return;
	#todo do something for a file which is missing
}

sub GetConfig { # gets configuration value based for $key
	my $configName = shift;
	chomp $configName;

	WriteLog("GetConfig($configName)");

#	if ($configName =~ /^[a-z0-9_]{1,32}$/) {
#		print("WARNING! GetConfig() sanity check failed!");
#		print("\$configName = $configName");
#		die();
#		return;
#	}
#
	state %configLookup;

	if (exists($configLookup{$configName})) {
		WriteLog('$configLookup already contains value, returning that...');
		WriteLog('$configLookup{$configName} is ' . $configLookup{$configName});

		return $configLookup{$configName};
	}

	WriteLog("Looking for config value in config/$configName ...");

	if (-e "config/$configName") {
		WriteLog("-e config/$configName returned true, proceeding to GetFile(), set \$configLookup{}, and return \$configValue");

		my $configValue = GetFile("config/$configName");

		if (substr($configName, 0, 9) eq 'template/') {
			# don't trim
		} else {
			$configValue = trim($configValue);
		}

		$configLookup{$configValue} = $configValue;

		return $configValue;
	} else {
		WriteLog("-e config/$configName returned false, looking in defaults...");

		if (-e "default/$configName") {
			WriteLog("-e default/$configName returned true, proceeding to GetFile(), etc...");

			my $configValue = GetFile("default/$configName");
			$configValue = trim($configValue);
			$configLookup{$configName} = $configValue;

			WriteLog('PutConfig (' . $configName . ', ' . $configValue .');');

			PutConfig ($configName, $configValue);

			return $configValue;
		} else {
			WriteLog("WARNING! Tried to get value of config with no default value!");
			#WriteLog("-e default/$configName returned false");
			#die();
		}
	}

	return;
}

sub ConfigKeyValid { #checks whether a config key is valid 
# valid means passes character sanitize
# and exists in default/
	WriteLog('ConfigKeyValid()');

	my $configName = shift;

	WriteLog('ConfigKeyValid($configName)');

	if ($configName =~ /^[a-z0-9_\/]{1,64}$/) {
		WriteLog("WARNING! ConfigKeyValid() sanity check failed!");
	}

	WriteLog('ConfigKeyValid(\$configName sanity check passed)');

	if (-e "default/$configName") {
		WriteLog("default/$configName exists!");

		return 1;
	} else {
		WriteLog("default/$configName NOT exist!");

		return 0;
	}
}

sub GetHtmlFilename { # get the HTML filename for specified item hash
# Returns 'ab/cd/abcdef01234567890[...].html'
	my $hash = shift;

	WriteLog("GetHtmlFilename()");

	if (!defined($hash) || !$hash) {
		if (WriteLog("Warning! GetHtmlFilename() called without parameter")) {

			my $trace = Devel::StackTrace->new;
			print $trace->as_string; # like carp
		}

		return;
	}

	WriteLog("GetHtmlFilename(\$hash = $hash)");

	if (!IsSha1($hash)) {
		WriteLog("Warning! GetHtmlFilename() called with parameter that isn't a SHA-1. Returning.");
		WriteLog("$hash");

		my $trace = Devel::StackTrace->new;
		print $trace->as_string; # like carp

		return;
	}

	#	my $htmlFilename =
	#		substr($hash, 0, 2) .
	#		'/' .
	#		substr($hash, 2, 8) .
	#		'.html';
	#
	my $htmlFilename =
		substr($hash, 0, 2) .
		'/' .
		substr($hash, 2, 2) .
		'/' .
		$hash .
		'.html';

	return $htmlFilename;
}

sub GetDigitColor() { # returns a 2-char color that corresponds to a digit for coloring the clock's digits
# Not sure of purpose, might be useful

	my $digit = shift;

	if (!$digit) {
		return;
	}
	if (length($digit) != 1) {
		return;
	}
	#todo $digit must be ^[0-9]{1}$

	my $digitColor = floor($digit / 10 * 255);
	my $digitColorHex = sprintf("%X", $digitColor);

	if (length($digitColorHex) < 2) {
		$digitColorHex = '0' . $digitColorHex;
	}

	return $digitColor;
}

sub GetTime() { # Returns time in epoch format.
# Just returns time() for now, but allows for converting to 1900-epoch time
# instead of Unix epoch
#	return (time() + 2207520000);
	return (time());
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

sub PutConfig { # writes config value to config storage
# $configName = config name/key (file path)
# $configValue = value to write for key
# Uses PutFile()
#
	my $configName = shift;
	my $configValue = shift;

	chomp $configValue;

	return PutFile("config/$configName", $configValue);
}
							  
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

	EnsureSubdirs($file);

	WriteLog("PutFile($file, ...");

	my $content = shift;
	my $binMode = shift;

	if (!defined($content)) {
		return;
	}

#	if (!$content) {
#		return;
#	}
	if (!$binMode) {
		$binMode = 0;
	} else {
		$binMode = 1;
	}

	WriteLog("PutFile($file, (\$content), $binMode)");
	WriteLog("==== \$content ====");
	WriteLog($content);
	WriteLog("====");

	if (open (my $fileHandle, ">", $file)) {
		WriteLog("file handle opened.");
		if ($binMode) {
			binmode $fileHandle, ':utf8';
		}
		print $fileHandle $content;
		close $fileHandle;
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

sub str_replace {
	my $string = shift;
#	return $string;
	my $old = shift;
	my $new = shift;

	if (!$old || !$new || !$string) {
		return 'str_replace failed due to one of the parameters missing!'; #todo make some kind of gesture
	}

	if (index($new, $old)) {
		WriteLog('str_replace: $new contains $old, this won\'t do');
		return $string;
	}

	my $i;
	while (($i = index($string, $old)) != -1) {
		substr($string, $i, length($old)) = $new;
	}


	#
#	WriteLog('str_replace("' . $string . '", "' . $old . '", "' . $new . '")');
#
#	my $i = index($string, $old);
#	if ($i != -1) {
#		if ($i > 0) {
#			$string = substr($string, 0, $i) . $new . substr($string, $i + length($old));
#		} else {
#			$string = $new . substr($string, length($old));
#		}
#		$string = str_replace($string, $old, $new, $recursionLevel);
#	}

	return $string;
}

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
				$content = str_replace($content, $string, $newString);
			} else {
				PutConfig('string/' . $newLanguage . '/' . $stringHash, $string);
			}
		}
	}

	return $content;
}

sub PutHtmlFile { # writes content to html file, with special rules; parameters: $file, $content
# the special rules are:
# * if config/admin/html/ascii_only is set, all non-ascii characters are stripped from output to file
# * if $file matches config/home_page, the output is also written to html/index.html
#   also keeps track of whether home page has been written, and returns the status of it
#   if $file is 'check_homepage'
#      
	my $file = shift;
	my $content = shift;
	my $itemHash = shift; #optional

	if (!$file) {
		return;
	}

	if (!$content) {
		$content = '';
	}

	# controls whether linked urls are converted to relative format
	# meaning they go from e.g. /write.html to ./write.html
	# this breaks the 404 page links so disable that for now
	my $relativizeUrls = GetConfig('html/relativize_urls');
	if (TrimPath($file) eq '404') {
		$relativizeUrls = 0;
	}

	# keeps track of whether home page has been written at some point
	# this value is returned if $file is 'check_homepage'
	# then we can write the default homepage in its place
	state $homePageWritten;
	if (!defined($homePageWritten)) {
		$homePageWritten = 0;
	}
	if ($file eq 'check_homepage') {
		return $homePageWritten;
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
		my $count = ($file =~ s/\//\//g);

		# then we build the path prefix.
		# the same prefix is used on all links
		# this can be done more efficiently on a per-link basis
		# but most subdirectory-located files are of the form /aa/bb/aabbcc....html anyway
		my $subDir;
		if ($count == 1) {
			$subDir = './';
		} else {
			$subDir = '../' x ($count - 1);
		}

		# here is where we do substitutions
		# it may be wiser to use str_replace here
		$content =~ s/src="\//src="$subDir/ig;
		$content =~ s/href="\//href="$subDir/ig;
		$content =~ s/\.src = '\//.src = '$subDir/ig;
		$content =~ s/\.location = '\//.location = '$subDir/ig;
	}

	# fill in colors
	my $colorTitlebarText = GetThemeColor('titlebar_text');#
	$content =~ s/\$colorTitlebarText/$colorTitlebarText/g;#

	my $colorTitlebar = GetThemeColor('titlebar');#
	$content =~ s/\$colorTitlebar/$colorTitlebar/g;#

	my $borderDialog = GetThemeAttribute('color/border_dialog');
	# todo rename it in all themes and then here
	# not actually a color, but the entire border definition
	$content =~ s/\$borderDialog/$borderDialog/g;

	my $colorWindow = GetThemeColor('window');
	$content =~ s/\$colorWindow/$colorWindow/g;

	# #internationalization #i18n
	if (GetConfig('language') ne 'en') {
		$content = ReplaceStrings($content);
	}

	PutFile($file, $content);

	# this is a special hook for generating index.html, aka the home page
	# if the current file matches config/home_page, write index.html
	# change the title to home_title while at it
	if ($file eq GetConfig('home_page')) {
		my $homePageTitle = GetConfig('home_title');
		$content =~ s/\<title\>(.+)\<\/title\>/<title>$homePageTitle ($1)<\/title>/;
		PutFile ('html/index.html', $content);
		$homePageWritten = 1;
	}
	
	# filling in 404 pages, using 404.log
	if ($itemHash) {
		# clean up the log file
		system ('sort log/404.log | uniq > log/404.log.uniq ; mv log/404.log.uniq log/404.log');

		# store log file in static variable for future 
		state $log404;
		if (!$log404) {
			$log404 = GetFile('log/404.log');
		}

		# if hash is found in 404 log, we will fill in the html page
		# pretty sure this code doesn't work #todo
		if ($log404 =~ m/$itemHash/) {
			my $aliasUrl = GetItemMessage($itemHash); # url is stored inside message

			if ($aliasUrl =~ m/\.html$/) {
				if (!-e 'html/' . $aliasUrl) { # don't clobber existing files
					PutHtmlFile('html/' . $aliasUrl, $content); # put html file in place (#todo replace with ln -s)
				}
			}
		}
	}
}

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

sub GetFileSizeHtml { # takes file size as number, and returns html-formatted human-readable size
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

sub IsAdmin { # returns 1 if parameter equals GetAdminKey() or GetServerKey(), otherwise 0
# will probably be redesigned in the future
	my $key = shift;

	if (!IsFingerprint($key)) {
		return 0;
	}

#	my $adminKey = GetAdminKey();
#
#	if ($adminKey eq $key) {
	if ($key eq GetAdminKey() || $key eq GetServerKey()) {
		return 1;
	} else {
		return 0;
	}
}


sub GetServerKey { # Returns server's public key, 0 if there is none
	state $serversKey;

	if ($serversKey) {
		return $serversKey;
	}

	if (-e "html/txt/server.key.txt") { #server's pub key should reside here
		my %adminsInfo = GpgParse("html/txt/server.key.txt");

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

	return 0;
}

sub GetAdminKey { # Returns admin's public key, 0 if there is none
	state $adminsKey = 0;

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

sub TrimPath { # Trims the directories AND THE FILE EXTENSION from a file path
	my $string = shift;

	while (index($string, "/") >= 0) {
		$string = substr($string, index($string, "/") + 1);
	}

	$string = substr($string, 0, index($string, ".") + 0);

	return $string;
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

sub IsItem { # returns 1 if parameter is in item hash format (40 lowercase hex chars), 0 otherwise
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[0-9a-f]{40}/) {
		return 1;
	} else {
		return 0;
	}
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

sub GpgParse { # Parses a text file containing GPG-signed message, and returns information as a hash
	# $filePath = path to file containing the text
	#
	# $returnValues{'isSigned'} = whether the message has a valid signature: 0 or 1 for valid signature
	# $returnValues{'text'} = original text
	# $returnValues{'message'} = message text without framing
	# $returnValues{'key'} = fingerprint of signer
	# $returnValues{'alias'} = alias of signer, if they've added one by submitting their public key
	# $returnValues{'keyExpired'} = whether the key has expired: 0 for not expired, 1 for expired
	# $returnValues{'gitHash'} = git's hash of the file's contents
	# $returnValues{'verifyError'} = whether there was an error with parsing the message


	WriteLog("===BEGIN GPG PARSE===");

	my $filePath = shift;

	my $txt = '';
	if (-e $filePath) {
		$txt = GetFile($filePath);
	} else {
		$txt = $filePath;
	}
	if (!$txt) {
		$txt = '(Text is blank or not found)';
	}

	my $message;

	my $isSigned = 0;

	my $gpg_key;

	my $alias = '';

	my $keyExpired = 0;

	my $fileHash = GetFileHash($filePath);

	if ($fileHash) {

		my $cachePath;
		$cachePath = "./cache/" . GetMyVersion() . "/gpg/$fileHash.cache";

		my %returnValues;

		if (-e $cachePath) {
			WriteLog("GpgParse cache hit! $cachePath");

			%returnValues = %{retrieve($cachePath)};

		} else {
			# Signed messages begin with this header
			my $gpg_message_header = "-----BEGIN PGP SIGNED MESSAGE-----";

			# Public keys (that set the username) begin with this header
			my $gpg_pubkey_header = "-----BEGIN PGP PUBLIC KEY BLOCK-----";

			# Encrypted messages begin with this header
			my $gpg_encrypted_header = "-----BEGIN PGP MESSAGE-----";

			###########################################################################
			## Below where we check for a GPG signed message and sort it accordingly ##
			###########################################################################

			my $trimmedTxt = trim($txt);

			my $verifyError = 0;

			######################
			## ENCRYPTED MESSAGE
			##

			if (index($txt, $gpg_encrypted_header) != -1) {
				$message = "This is an encrypted message. Decryption is not yet supported by the web interface.";
			}

			#		if (substr($trimmedTxt, 0, length($gpg_encrypted_header)) eq $gpg_encrypted_header) {
			#			WriteLog("$gpgCommand --batch --list-only --status-fd 1 \"$filePath\"");
			#			my $gpg_result = `$gpgCommand --batch --list-only --status-fd 1 "$filePath"`;
			#			WriteLog($gpg_result);
			#
			#			foreach (split("\n", $gpg_result)) {
			#				chomp;
			#
			#				my $key_id_prefix;
			#				my $key_id_suffix;
			#
			#				if (index($gpg_result, "[GNUPG:] ENC_TO ") >= 0) {
			#					$key_id_prefix = "[GNUPG:] ENC_TO ";
			#					$key_id_suffix = " ";
			#
			#					if ($key_id_prefix) {
			#						# Extract the key fingerprint from GPG's output.
			#						$gpg_key = substr($gpg_result, index($gpg_result, $key_id_prefix) + length($key_id_prefix));
			#						$gpg_key = substr($gpg_key, 0, index($gpg_key, $key_id_suffix));
			#
			#						$message = "Encrypted message for $gpg_key\n";
			#
			#						$isSigned = 1;
			#
			#					}
			#				}
			#			}
			#		}

			###############
			## PUBLIC KEY
			##

			WriteLog("Looking for public key header...");

			# find pubkey header in message
			if (substr($trimmedTxt, 0, length($gpg_pubkey_header)) eq $gpg_pubkey_header) {
				WriteLog("Found public key header!");

				WriteLog("$gpgCommand --keyid-format LONG \"$filePath\" $gpgStderr");
				my $gpg_result = `$gpgCommand --keyid-format LONG "$filePath" $gpgStderr`;
				WriteLog($gpg_result);

				WriteLog("$gpgCommand --import \"$filePath\" $gpgStderr");
				my $gpgImportKeyResult = `$gpgCommand --import "$filePath" $gpgStderr`;
				WriteLog($gpgImportKeyResult);

				foreach (split("\n", $gpg_result)) {
					chomp;
					WriteLog("Looking for returned alias in $_");

					# gpg 1
					if ($gpgCommand eq 'gpg' && !GetConfig('admin/gpg/use_gpg2')) {
						WriteLog('$gpgCommand is gpg');

						if (substr($_, 0, 4) eq 'pub ') {
							my @split = split(" ", $_, 4);
							$alias = $split[3];
							$gpg_key = $split[1];

							@split = split("/", $gpg_key);
							$gpg_key = $split[1];

							$alias =~ s|<.+?>||g;
							$alias =~ s/^\s+//;
							$alias =~ s/\s+$//;
						}
					}

					# gpg 2
					elsif ($gpgCommand eq 'gpg2' || GetConfig('admin/gpg/use_gpg2')) {
						if (substr($_, 0, 4) eq 'pub ') {
							WriteLog('gpg2 ; pub hit');

							WriteLog('$_ is ' . $_ . ' .. going to split it');

							my @split = split(" ", $_, 4); # 4 limits it to 4 fields
							$gpg_key = $split[1];

							WriteLog($split[0] . '|' . $split[1] . '|' . $split[2] . '|' . $split[3]);
							#$alias = $split[3];

							@split = split("/", $gpg_key);
							$gpg_key = $split[1];

							WriteLog('$gpg_key = ' . $gpg_key);
						}
						if (substr($_, 0, 3) eq 'uid' && !$alias) {
							WriteLog('gpg2: uid hit');

							WriteLog('$_ is ' . $_);

							my @split = split(' ', $_, 2);

							$alias = $split[1];
							$alias = trim($alias);

							WriteLog('$alias is now ' . $alias);
						}
					}
				}

				# Public key confirmed, update $message
				if ($gpg_key) {
					if (!$alias) {
						$alias = '(Blank)';
					}
					#$message = "Welcome, $alias\nFingerprint: $gpg_key";
					$message = GetTemplate('message/user_reg.template');

					$message =~ s/\$name/$alias/g;
					$message =~ s/\$fingerprint/$gpg_key/g;

				}
				else {
					$message = "Problem! Public key item did not parse correctly. Try changing config/admin/gpg/gpg_command";
				}

				$isSigned = 1;
			}

			#######################
			## GPG SIGNED MESSAGE
			##
			if (substr($trimmedTxt, 0, length($gpg_message_header)) eq $gpg_message_header) {
				# Verify the file by using command-line gpg
				# --status-fd 1 makes gpg output to STDOUT using a more concise syntax
				WriteLog("$gpgCommand --verify --status-fd 1 \"$filePath\" $gpgStderr");
				my $gpg_result = `$gpgCommand --verify --status-fd 1 "$filePath" $gpgStderr`;
				WriteLog($gpg_result);

				my $key_id_prefix;
				my $key_id_suffix;

				if (index($gpg_result, "[GNUPG:] BADSIG") >= 0 || index($gpg_result, "[GNUPG:] ERRSIG") >= 0 || index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
					#			$key_id_prefix = 0;
					#			$key_id_suffix = 0;
					#%returnValues{'sigError'} = 1;
					WriteLog("Decoding error detected!!!!1");
					$verifyError = 1;

				}
				else {
					#			if (index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
					#				$key_id_prefix = "[GNUPG:] NO_PUBKEY ";
					#				$key_id_suffix = "\n";
					#			}

					if (index($gpg_result, "[GNUPG:] GOODSIG ") >= 0) {
						$key_id_prefix = "[GNUPG:] GOODSIG ";
						$key_id_suffix = " ";
					}

					if (index($gpg_result, "[GNUPG:] EXPKEYSIG ") >= 0) {
						$key_id_prefix = "[GNUPG:] EXPKEYSIG ";
						$key_id_suffix = " ";

						$keyExpired = 1;
					}
				}

				if ($key_id_prefix && (!$verifyError || GetConfig('admin/allow_broken_signatures'))) {
					# Extract the key fingerprint from GPG's output.
					$gpg_key = substr($gpg_result, index($gpg_result, $key_id_prefix) + length($key_id_prefix));
					$gpg_key = substr($gpg_key, 0, index($gpg_key, $key_id_suffix));

					WriteLog("$gpgCommand --decrypt \"$filePath\" $gpgStderr");
					$message = `$gpgCommand --decrypt "$filePath" $gpgStderr`;

					$isSigned = 1;
				}

				if (!$isSigned) {
					WriteLog("Decoding signed message fallthrough!!!1 Setting \$verifyError = 1");
					$verifyError = 1;
				}
			}

			if (!$isSigned) {
				$message = $txt;
			}
			#
			#		if ($isSigned) {
			#			my $messageTrimmed = trim($message);
			#
			#			if (
			#				substr($messageTrimmed, 0, length($gpg_pubkey_header)) eq $gpg_pubkey_header ||
			#				substr($messageTrimmed, 0, length($gpg_message_header)) eq $gpg_message_header ||
			#				substr($messageTrimmed, 0, length($gpg_message_header)) eq $gpg_message_header
			#			) {
			#				#todo this is where we recurse GpgParse() and get any nested signed messages and stuff like that
			#			}
			#		}

			$returnValues{'isSigned'} = $isSigned;
			$returnValues{'text'} = $txt;
			$returnValues{'message'} = $message;
			$returnValues{'key'} = $gpg_key;
			$returnValues{'alias'} = $alias;
			$returnValues{'keyExpired'} = $keyExpired;
			$returnValues{'gitHash'} = $fileHash;
			$returnValues{'verifyError'} = $verifyError;

			store \%returnValues, $cachePath;
		}

		WriteLog("GpgParse success! $cachePath");

		WriteLog("===END GPG PARSE===");

		return %returnValues;
	} else {
		die;

		WriteLog('GpgParse fail! no $fileHash');

		WriteLog("===END GPG PARSE===");

		return;
	}
}

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

sub FormatForWeb { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	#	$text =~ s/\n /<br>&nbsp;/g;
	#	$text =~ s/^ /&nbsp;/g;
	#	$text =~ s/  / &nbsp;/g;
	$text =~ s/\n/<br>\n/g;

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
	$text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	$text =~ s/\n/<br>\n/g;
#	$text =~ s/<br>/'<br><input type=text size=80 name=txt'.$i++.'><br>'/ge;

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
# Even if debug mode is 0
	my $text = shift;
	chomp $text;

	my $timestamp = GetTime();

	print $timestamp . ' ' . $text . "\n";
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

	my $changeLogList = `git log --oneline $lastVersion..$currVersion`;
	$changeLogList = trim($changeLogList);
	$changeLogMessage .= "$changeLogList";

	$changeLogMessage .= "\n\n#changelog";

	PutFile("html/txt/$changeLogFilename", $changeLogMessage);

	ServerSign("html/txt/$changeLogFilename");

	PutConfig('current_version', $currVersion);
}

my $lastAdmin = GetConfig('current_admin');
my $currAdmin = GetAdminKey();

if (!$lastAdmin) {
	$lastAdmin = 0;
}

if ($currAdmin) {
	if ($lastAdmin ne $currAdmin) {
		WriteLog("$lastAdmin ne $currAdmin, posting change-admin");

		my $changeAdminFilename = 'changeadmin_' . GetTime() . '.txt';
		my $changeAdminMessage = 'Admin has changed from ' . $lastAdmin . ' to ' . $currAdmin;

		PutFile("html/txt/$changeAdminFilename", $changeAdminMessage);

		ServerSign("html/txt/$changeAdminFilename");

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
	WriteLog("$gpgCommand --list-keys $serverKeyId $gpgStderr");
	#my $gpgCommand = GetConfig('admin/gpg/gpg_command');

	my $serverKey = `$gpgCommand --list-keys $serverKeyId $gpgStderr`;
	WriteLog($serverKey);

	# if public key has not been published yet, do it
	if (!-e "html/txt/server.key.txt") {
		WriteLog("$gpgCommand --batch --yes --armor --export $serverKeyId $gpgStderr");
		my $gpgOutput = `$gpgCommand --batch --yes --armor --export $serverKeyId $gpgStderr`;

		PutFile('html/txt/server.key.txt', $gpgOutput);

		WriteLog($gpgOutput);
	} #todo here we should also verify that server.key.txt matches server_key_id
	
	# if everything is ok, proceed to sign
	if ($serverKey) {
		WriteLog("We have a server key, so go ahead and sign the file.");

		#todo this is broken with gpg2
		# should start with $gpgCommand
#		WriteLog("gpg --batch --yes --default-key $serverKeyId --clearsign \"$file\"");
#		system("gpg --batch --yes --default-key $serverKeyId --clearsign \"$file\"");
		WriteLog("$gpgCommand --batch --yes -u $serverKeyId --clearsign \"$file\" $gpgStderr");
		system("$gpgCommand --batch --yes -u $serverKeyId --clearsign \"$file\" $gpgStderr");

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

sub FormatDate {
	my $epoch = shift;

	my $time = GetTime();

	my $difference = $time - $epoch;

	my $formattedDate = '';

	if ($difference < 86400) {
		$formattedDate = strftime '%H:%M', localtime $epoch;
	} elsif ($difference < 86400 * 30) {
		$formattedDate = strftime '%m/%d', localtime $epoch;
	} else {
		$formattedDate = strftime '%a, %d %b %Y', localtime $epoch;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;
	}

	return $formattedDate;
}

sub GetTimestampElement { # returns <span class=timestamp>$time</span>
	my $time = shift;

	state $epoch;

	if ($time) {
		chomp $time;
	} else {
		$time = 0;
	}

	if (!defined($epoch)) {
		$epoch = GetConfig('html/timestamp_epoch');
	}

	WriteLog('GetTimestampElement("' . $time . '")');

	#todo sanity check;

	my $timestampElement = '';
	if ($epoch) {
		$timestampElement = GetTemplate('timestamp.template');

		$timestampElement =~ s/\$timestamp/$time/;
	} else {
		WriteLog('GetTimestampElement: $epoch = false');

		$timestampElement = GetTemplate('timestamp2.template');

		my $timeDate = $time;

		if ($time =~ m/^[0-9]+$/) {
			WriteLog('GetTimestampElement: ($time =~ m/^[0-9]+$/) is true');
			$timeDate = FormatDate($time);
		}

#		my $timeDate = strftime '%c', localtime $time;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;

		$timestampElement =~ s/\$timestamp/$time/;
		$timestampElement =~ s/\$timeDate/$timeDate/;
	}

	chomp $timestampElement;

	return $timestampElement;
}

sub DeleteFile { #delete file with specified file hash (incomplete) 
	my $fileHash = shift;

	if ($fileHash) {
	}
}

sub GetItemMessage { # retrieves item's message using cache or file path
# $itemHash, $filePath

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
	my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$itemHash";

	if (-e $messageCacheName) {
		$message = GetFile($messageCacheName);
	} else {
		my $filePath = shift;
		#todo sanitize/sanitycheck

		$message = GetFile($filePath);
	}

	return  $message;
}

sub GetPrefixedUrl { # returns url with relative prefix 
	my $url = shift;
	chomp $url; 
	
	return $url;
}

sub UpdateUpdateTime { # updates config/system/last_update_time, which is used by the stats page
	my $lastUpdateTime = GetTime();

	PutConfig("system/last_update_time", $lastUpdateTime);
}

sub RemoveEmptyDirectories { #looks for empty directories under $path and removes them
	my $path = shift;
	
	#todo probably more sanitizing
	
	$path = trim($path);
	if (!$path) {
		return;
	}
	
	system('find $path -type d -empty -delete');
}

sub RemoveOldItems {
	my $query = "
		SELECT * FROM item_flat WHERE file_hash NOT IN (
			SELECT file_hash FROM item_flat
			WHERE
				',' || tags_list || ',' like '%keep%'
					OR
				file_hash IN (
					SELECT item_hash
					FROM item_parent
					WHERE parent_hash IN (
						SELECT file_hash FROM item_flat WHERE ',' || tags_list || ',' LIKE '%keep%'
					)
				)
		)
		ORDER BY add_timestamp
	";
}

1;
