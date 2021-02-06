#!/usr/bin/perl -T
use strict;
use 5.010;
use utf8;

sub GetMyCacheVersion { # returns "version" of cache
# this is used to prevent cache conflicts between different software versions
# used to return git commit identifier, looking for a better alternative now
# todo make this return something other than hard-coded string
	my $cacheVersion = 'b';

	state $dirChecked;
	if (!$dirChecked) {
		$dirChecked = 1;
		my $cacheDir = GetDir('cache');
		if (!-e "$cacheDir/$cacheVersion") {
			WriteLog('GetMyCacheVersion: warning: directory no exist. try to make once...');
			mkdir("$cacheDir/$cacheVersion");
		}
	}
	WriteLog('GetMyCacheVersion: returning $cacheVersion = ' . $cacheVersion);

	return $cacheVersion;
}

#my $CACHEDIR = $SCRIPTDIR . '/cache/' . GetMyCacheVersion();
my $CACHEDIR = './cache/' . GetMyCacheVersion(); #todo

sub GetCache { # get cache by cache key
	# comes from cache/ directory

	my $cacheName = shift;
	chomp $cacheName;

	if ($cacheName =~ m/^([\/[a-z0-9A-Z_.\/]+)$/i) {
		# sanity check passed
		$cacheName = $1;
		WriteLog('GetCache: sanity check passed');
	} else {
		WriteLog('GetCache: warning: sanity check failed on $cacheName = "' . $cacheName . '"');
		return '';
	}

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	# cache name prefixed by current version
	$cacheName = './cache/' . $myVersion . '/' . $cacheName; #todo

	if (-e $cacheName) {
		# return contents of file at that path
		return GetFile($cacheName);
	}
	else {
		return;
	}
} # GetCache()

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

	$cacheName = './cache/' . $myVersion . '/' . $cacheName; #todo

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

	my $cacheFile = './cache/' . $myVersion . '/' . $cacheName; #todo

	my @cacheFiles = glob($cacheFile);

	if (scalar(@cacheFiles)) {
		WriteLog('UnlinkCache: scalar(@cacheFiles) = ' . scalar(@cacheFiles));
		#unlink(@cacheFiles); #todo #temporary
	}
} # UnlinkCache()

sub CacheExists { # Check whether specified cache entry exists, return 1 (exists) or 0 (not)
	my $cacheName = shift;
	chomp($cacheName);

	state $myVersion;
	if (!$myVersion) {
		$myVersion = GetMyCacheVersion();
	}

	$cacheName = './cache/' . $myVersion . '/' . $cacheName; #todo

	if (-e $cacheName) {
		return 1;
	} else {
		return 0;
	}
}


sub GetMessageCacheName {
	my $itemHash = shift;
	chomp($itemHash);

	if (!IsItem($itemHash)) {
		WriteLog('GetMessageCacheName: sanity check failed');
		return '';
	}

	my $messageCacheName = "./cache/" . GetMyCacheVersion() . "/message/$itemHash"; #todo
	return $messageCacheName;
}


sub ExpireAvatarCache { # $fingerprint ; removes all caches for alias
	# DeleteAvatarCache ExpireAvatarCache ExpireAliasCache {

	my $key = shift;
	WriteLog("ExpireAvatarCache($key)");
	if (!IsFingerprint($key) && $key ne '*') {
		WriteLog('ExpireAvatarCache: warning: sanity check failed');
        my ($package, $filename, $line) = caller;
		WriteLog('ExpireAvatarCache: caller information: ' . $package . ',' . $filename . ', ' . $line);
		return 0;
	}

	my $themeName = GetConfig('html/theme');
	UnlinkCache('avatar/' . $themeName . '/' . $key);
	UnlinkCache('avatar.color/' . $themeName . '/' . $key);
	UnlinkCache('avatar.plain/' . $themeName . '/' . $key);
} # ExpireAvatarCache()

sub GetFileMessageCachePath {
	my $fileHash = shift;
	if (!$fileHash) {
		return ''; #todo
	}
	if (!IsItem($fileHash) && -e $fileHash) {
		$fileHash = GetFileHash($fileHash);
	}

	my $CACHEPATH = GetDir('cache');
	my $cachePathMessage = "$CACHEPATH/message";

	if ($cachePathMessage =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathMessage = $1;
		WriteLog('GpgParse: $cachePathMessage sanity check passed: ' . $cachePathMessage);
	} else {
		WriteLog('GpgParse: warning: sanity check failed, $cachePathMessage = ' . $cachePathMessage);
		return '';
	}

	my $fileMessageCachPath = "$cachePathMessage/$fileHash";

	if ($fileMessageCachPath =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$fileMessageCachPath = $1;
		WriteLog('GpgParse: $fileMessageCachPath sanity check passed: ' . $fileMessageCachPath);
	} else {
		WriteLog('GpgParse: warning: sanity check failed, $fileMessageCachPath = ' . $fileMessageCachPath);
		return '';
	}

	return $fileMessageCachPath;
}

1;