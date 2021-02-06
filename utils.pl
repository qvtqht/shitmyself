#!/usr/bin/perl -T
#
# utils.pl
# utilities which haven't found their own file yet
# typically used by another file
# performs basic state validation whenever run
# 

$ENV{PATH}="/bin:/usr/bin";

use strict;
use warnings;
use utf8;
use 5.010;

use lib qw(lib); #needed for when we use included libs, such as on dreamhost
use POSIX 'strftime';
use Data::Dumper;
use Cwd qw(cwd);
use Digest::MD5 qw( md5_hex );
use File::Basename qw( fileparse );
use URI::Encode qw( uri_decode );
use URI::Escape;
use Storable;
use Digest::SHA qw( sha1_hex );
use File::Spec qw( abs2rel );

sub require_once { # $path ; use require() unless already done
	my $path = shift;
	chomp $path;

	if (!$path || !-e $path) {
		WriteLog('require_once: warning sanity check failed');
		return 0;
	}

	state %state;
	if (defined($state{$path})) {
		WriteLog('require_once: already required: ' . $path);
		return 0;
	}

	require $path;
	$state{$path} = 1;
	
	return 1;
} # require_once()

sub GetDir { # $dirName ; returns path to special directory specified
# 'html' = html root
# 'script'
# 'txt'
# 'image
	my $dirName = shift;
	if (!$dirName) {
		WriteLog('GetDir: warning: $dirName missing');
		return '';
	}
	WriteLog('GetDir: $dirName = ' . $dirName);

	my $scriptDir = cwd();
	if ($scriptDir =~ m/^([0-9a-zA-Z\/]+)/) {
		$scriptDir = $1;
		WriteLog('GetDir: $scriptDir sanity check passed');
	} else {
		WriteLog('GetDir: warning: sanity check failed on $scriptDir');
		return '';
	}
	WriteLog('GetDir: $scriptDir = ' . $scriptDir);

	if ($dirName eq 'script') {
		WriteLog('GetDir: return ' . $scriptDir);
		return $scriptDir;
	}

	if ($dirName eq 'html') {
		WriteLog('GetDir: return ' . $scriptDir . '/html');
		return $scriptDir . '/html';
	}

	if ($dirName eq 'php') {
		WriteLog('GetDir: return ' . $scriptDir . '/html');
		return $scriptDir . '/html';
	}

	if ($dirName eq 'txt') {
		WriteLog('GetDir: return ' . $scriptDir . '/html/txt');
		return $scriptDir . '/html/txt';
	}

	if ($dirName eq 'image') {
		WriteLog('GetDir: return ' . $scriptDir . '/html/image');
		return $scriptDir . '/html/image';
	}

	if ($dirName eq 'cache') {
		WriteLog('GetDir: return ' . $scriptDir . '/cache/' . GetMyCacheVersion());
		return $scriptDir . '/cache/' . GetMyCacheVersion();
	}

	WriteLog('GetDir: warning: fallthrough on $dirName = ' . $dirName);
	return '';
} # GetDir()

my $SCRIPTDIR = cwd();
if (!$SCRIPTDIR) {
	die ('Sanity check failed: $SCRIPTDIR is false!');
}

#my $HTMLDIR = $SCRIPTDIR . '/html';
#my $TXTDIR = $HTMLDIR . '/txt';
#my $IMAGEDIR = $HTMLDIR . '/txt';

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
		WriteLog('EnsureSubdirs: warning: $fullPath begins with / ' . $fullPath);
		#todo not sure if this should be a warning? what else would fullpath contain?
	}
	if (index($fullPath, '..') != -1 ) {
		WriteLog('EnsureSubdirs: warning: $fullPath contains .. ' . $fullPath);
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

sub GetMyVersion { # Get the currently checked out version (current commit's hash from git)
	# GetVersion {
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
			$fileContent = trim($fileContent);
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
	state %templateMemo; #stores local memo cache of template
	if ($templateMemo{$filename}) {
		#if already been looked up, return memo version
		WriteLog('GetTemplate: returning from memo for ' . $filename);
		if (trim($templateMemo{$filename}) eq '') {
			WriteLog('GetTemplate: warning: returning empty string for ' . $filename);
		}
		return $templateMemo{$filename};
	}

	if (!-e ('config/template/' . $filename) && !-e ('default/template/' . $filename)) {
		#shim for rename
		if (-e ('config/template/html/' . $filename) || -e ('default/template/html/' . $filename)) {
			WriteLog('GetTemplate: warning: template reference needs to be prepended with html: ' . $filename);
			return GetTemplate('html/' . $filename);
		}

		# if template doesn't exist
		# and we are in debug mode
		# report the issue
		WriteLog("GetTemplate: warning: template $filename missing");

		if (GetConfig('admin/dev/die_on_missing_template')) {
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
		$templateMemo{$filename} = $template;
		return $template;
	} else {
		#if result is blank, report it
		WriteLog("GetTemplate: warning: GetTemplate returning empty string for $filename.");
		return '';
	}
} # GetTemplate()

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

	if (!$fingerprint) {
		WriteLog('GetAlias: warning: $fingerprint was missing');
		return '';
	}

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
		WriteLog('GetFile: warning: $fileName missing or false');
		return '';
	}

	chomp $fileName;

	if ($fileName =~ m/^([0-9a-zA-Z\/._-]+)$/) {
		$fileName = $1;
		WriteLog('GetFile: $fileName passed sanity check: ' . $fileName);
	} else {
		WriteLog('GetFile: warning: $fileName FAILED sanity check: ' . $fileName);
		return '';
	}

	my $length = shift || 209715200;
	# default to reading a max of 2MB of the file. #scaling #bug

	WriteLog('GetFile: trying to open file...');
	if (
		-e $fileName # file exists
			&&
		!-d $fileName # not a directory
			&&
		open (my $file, "<", $fileName) # opens successfully
	) {
		WriteLog('GetFile: opened successfully, trying to read...');
		my $return;
		read ($file, $return, $length);
		WriteLog('GetFile: read success, returning.');
		return $return;
	}

	return;
	#todo do something for a file which is missing
} # GetFile()


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
		WriteLog('str_replace: caller: ' . join(', ', caller));
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

	WriteLog('str_ireplace(' . $replace_this . ', ' . $with_this . ', ($string)' . length($string));

	if ($replace_this eq $with_this) {
		WriteLog('str_ireplace: warning: $replace_this eq $with_this');
		WriteLog('str_ireplace: caller: ' . join(', ', caller));
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

	WriteLog('str_ireplace: length($result) = ' . length($string));

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

	if ($file eq 'profile.html') {
		PutHtmlFile('index.html', $content);
	}

	WriteLog("PutHtmlFile($file)");

	my $HTMLDIR = GetDir('html');

	if ($HTMLDIR && !-e $HTMLDIR) {
		WriteLog('PutHtmlFile: warning: $HTMLDIR was missing, trying to mkdir(' . $HTMLDIR . ')');
		mkdir($HTMLDIR);
	}

	if (!$HTMLDIR || !-e $HTMLDIR) {
		WriteLog('PutHtmlFile: $HTMLDIR is missing: ' . $HTMLDIR);
		return '';
	}

	if (!$content) {
		WriteLog('PutHtmlFile: warning: $content missing');
		$content = '';
	}

	# remember what the filename provided is, so that we can use it later
	my $fileProvided = $file;
	$file = "$HTMLDIR/$file";

	# controls whether linked urls are converted to relative format
	# meaning they go from e.g. /write.html to ./write.html
	# this breaks the 404 page links so disable that for now
	my $relativizeUrls = (GetConfig('html/relativize_urls') ? 1 : 0);
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
		WriteLog('PutHtmlFile: $stripNonAscii == 1, removing non-ascii characters');
		$content =~ s/[^[:ascii:]]//g;
	}

	# convert urls to relative if $relativizeUrls is set
	if ($relativizeUrls == 1) {
		WriteLog('PutHtmlFile: $relativizeUrls == 1, relativizing urls');
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


	#############################################
	my $putFileResult = PutFile($file, $content);
	#############################################

	{
		if (index($content, '$') > -1) {
			# test for $ character in html output, warn/crash if it is there
			if (!($fileProvided eq 'openpgp.js')) {
				# except for openpgp.js, most files should not have $ characters
				WriteLog('PutHtmlFile: warning: $content contains $ symbol! $file = ' . ($file ? $file : '-'));
			}
		}
		if ($content =~ m/<html.+<html/) {
			# test for duplicate <html> tag
			WriteLog('PutHtmlFile: warning: $content contains duplicate <html> tags');
		}
	}

	return $putFileResult;
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
			WriteLog('AuthorHasTag: $tagInQuestion FOUND, return 1');
			return 1;
		} else {
			WriteLog('AuthorHasTag: $tagInQuestion NOT found, return 0');
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
	if (!$key || !IsFingerprint($key)) {
		WriteLog('IsAdmin: warning: $key failed sanity check, returning 0');
		return 0;
	}
	WriteLog("IsAdmin($key)");

	my $rootAdminKey = ''; #GetRootAdminKey();
	if (!$rootAdminKey) {
		$rootAdminKey = '';
	}

	if ($key eq $rootAdminKey) {
		WriteLog('IsAdmin: $key eq $rootAdminKey, return 2 ');
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
#
#sub GetServerKey { # Returns server's public key, 0 if there is none
#	state $serversKey;
#
#	if ($serversKey) {
#		return $serversKey;
#	}
#
#	my $TXTDIR = GetDir('txt');
#
#	if (-e "$TXTDIR/server.key.txt") { #server's pub key should reside here
#		my %adminsInfo = GpgParse("$TXTDIR/server.key.txt");
#
#		if ($adminsInfo{'isSigned'}) {
#			if ($adminsInfo{'key'}) {
#				$serversKey = $adminsInfo{'key'};
#
#				return $serversKey;
#			} else {
#				return 0;
#			}
#		} else {
#			return 0;
#		}
#	} else {
#		return 0;
#	}
#
#	WriteLog('GetServerKey: warning: fallthrough!');
#	return 0;
#} # GetServerKey()

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
# todo more validation
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/^([0-9a-f]{40})$/) {
		return $1;
	}

	if ($string =~ m/^([0-9a-f]{8})$/) {
		return $1;
	}

	return 0;
} # IsItem()

sub IsItemPrefix { # $string ; returns sanitized value if parameter is in item prefix format (4 lowercase hex chars), 0 otherwise
# todo more validation
	WriteLog('IsItemPrefix()');

	my $string = shift;

	if (!$string) {
		return 0;
	}

	chomp $string;

	WriteLog('IsItemPrefix: $string = ' . $string);

	if ($string =~ m/^([0-9a-f]{4})$/) {
		WriteLog('IsItemPrefix: returning $1 = ' . $1);

		return $1; # returned sanitized value, in case it is needed
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

sub CheckForInstalledVersionChange {
	WriteLog('CheckForInstalledVersionChange() begin');

	my $lastVersion = GetConfig('current_version');
	my $currVersion = GetMyVersion();

	if (!$lastVersion) {
		$lastVersion = 0;
	}

	if (!$currVersion) {
		WriteLog('CheckForInstalledVersionChange: warning: sanity check failed, no $currVersion');
		return '';
	}

	if ($lastVersion ne $currVersion) {
		WriteLog("CheckForInstalledVersionChange: $lastVersion ne $currVersion, posting changelog");

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
		my $TXTDIR = GetDir('txt');
		PutFile("$TXTDIR/$changeLogFilename", $changeLogMessage);
		ServerSign("$TXTDIR/$changeLogFilename");
		PutConfig('current_version', $currVersion);

		return $currVersion;
	} else {
		return 0;
	}
} # CheckForInstalledVersionChange()

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
	my $TXTDIR = GetDir('txt');

	if (!-e "$TXTDIR/server.key.txt") {
		#todo move to gpgp.pl
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

sub IsFileDeleted { # $file, $fileHash ; checks for file's hash in deleted.log and removes it if found
#todo rename to IsFileMarkedAsDeleted()
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
				my $HTMLDIR = GetDir('html');
				$htmlFilename = $HTMLDIR . '/' . $htmlFilename; #todo this could be a sub?
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
				my $HTMLDIR = GetDir('html');
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

sub GetItemEasyFind { #returns Easyfind strings for item
# easyfind is just breaking up the item's hash into smaller searchable chunks
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
} # GetItemEasyFind()

sub GetItemDetokenedMessage { # $itemHash, $filePath ; retrieves item's message using cache or file path
	WriteLog('GetItemDetokenedMessage()');

	my $itemHash = shift;
	if (!$itemHash) {
		WriteLog('GetItemDetokenedMessage: warning: missing $itemHash');
		return '';
	}

	chomp $itemHash;

	if (!IsItem($itemHash)) {
		WriteLog('GetItemDetokenedMessage: warning: $itemHash failed sanity check');
		return '';
	}

	WriteLog("GetItemDetokenedMessage($itemHash)");

	my $message = '';
	my $messageCacheName = GetMessageCacheName($itemHash);

	if (-e $messageCacheName) {
		WriteLog('GetItemDetokenedMessage: $message = GetFile(' . $messageCacheName . ');');
		$message = GetFile($messageCacheName);
		if (!$message) {
			WriteLog('GetItemDetokenedMessage: cache exists, but $message was missing');

			my $filePath = shift;
			if (!$filePath) {
				$filePath = '';
			}

			WriteLog('GetItemDetokenedMessage: $filePath = ' . $filePath);

			if (!$filePath) {
				$filePath = GetPathFromHash($itemHash);
				WriteLog('GetItemDetokenedMessage: missing $filePath, using GetPathFromHash(): ' . $filePath);
			}

			if (!$filePath || !-e $filePath) {
				$filePath = DBGetItemAttributeValue($itemHash, 'file_path');
				chomp $filePath;
				WriteLog('GetItemDetokenedMessage: missing $filePath, using DBGetItemAttributeValue(): ' . $filePath);
			}

			WriteLog('GetItemDetokenedMessage: $filePath = ' . $filePath);

			if ($filePath && -e $filePath) {
				WriteLog('GetItemDetokenedMessage = GetFile(' . $filePath . ');');
				$message = GetFile($filePath);
			} else {
				WriteLog('GetItemDetokenedMessage: warning: no $filePath or file is missing');
				$message = '';
			}
		}
	}

	if (!$message) {
		WriteLog('GetItemDetokenedMessage: warning: $message is false');
	}

	return $message;
} # GetItemDetokenedMessage()

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
#GetFilePath {
	# relies on config/admin/organize_files = 1
	my $fileHash = shift;
	chomp $fileHash;

	if (!$fileHash) {
		return;
	}

	my $TXTDIR = 'html/txt'; #todo #todo
#	my $TXTDIR = GetDir('txt');
	if ($fileHash =~ m/^([0-9a-f]+)$/) { #todo should this be unlimited length?
		$fileHash = $1;
		WriteLog('GetPathFromHash: $fileHash sanity check passed: ' . $fileHash);
	} else {
		WriteLog('GetPathFromHash: warning: $fileHash sanity check failed!');
		return '';
	}

	if (!-e $TXTDIR . '/' . substr($fileHash, 0, 2)) {
		WriteLog('GetPathFromHash: mkdir ' . $TXTDIR . '/' . substr($fileHash, 0, 2));
		system('mkdir ' . $TXTDIR . '/' . substr($fileHash, 0, 2));
	}

	if (!-e $TXTDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)) {
		system('mkdir ' . $TXTDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2));
	}

	my $fileHashSubDir = substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2);

	if ($fileHash) {
		my $fileHashPath = $TXTDIR . '/' . $fileHashSubDir . '/' . $fileHash . '.txt';
		WriteLog('GetPathFromHash: $fileHashPath = ' . $fileHashPath);
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

sub VerifyThirdPartyAccount {
	my $fileHash = shift;
	my $thirdPartyUrl = shift;
} # verify token

sub ProcessTextFile { # $file ; add new text file to index
	my $file = shift;
	if ($file eq 'flush') {
		IndexFile('flush');
	}
	my $relativePath = File::Spec->abs2rel($file, $SCRIPTDIR); #todo this shouldn't have a ::
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

require './string.pl';
require './cache.pl';
require './config.pl';
require './string.pl';
require './html.pl';
require './file.pl';
#require './access.pl';

sub EnsureDirsThatShouldExist { # creates directories expected later
	WriteLog('EnsureDirsThatShouldExist() begin');
	# make a list of some directories that need to exist
	my $HTMLDIR = GetDir('html');
	#todo this should be ... improved upon
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

EnsureDirsThatShouldExist();

CheckForInstalledVersionChange();

my $utilsPl = 1;

require './sqlite.pl';

1;
