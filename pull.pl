#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

use File::Basename qw(dirname);
use URI::Encode qw(uri_encode);
use Digest::SHA qw(sha1_hex);
use URI::Escape qw(uri_escape);

require './utils.pl';
require './sqlite.pl';

sub PullFeedFromHost { # connects to $host with http and downloads any new items posted
# downloads /rss.txt first
# then downloads any listed items which are not already stored locally
# determined by provided sha hash
	my $host = shift;

	chomp $host;

	my $hostBase = "http://" . $host;

	my $hostFeedUrl = $hostBase . "/rss.txt";

	$hostFeedUrl = $hostFeedUrl . '?you=' . uri_escape($host);

	my @myHosts = split("\n", GetConfig('system/my_hosts'));
	my $myHostUrl = $myHosts[rand @myHosts];

	$hostFeedUrl .= '&me=' . uri_escape($myHostUrl);

	#my $feed = `curl -A useragent $hostFeedUrl`;

	WriteLog("curl $hostFeedUrl");

	my $feed = `curl $hostFeedUrl`;

	if ($feed) {
		my @items = split("\n", $feed);

		#verify that every line of the feed begins with a slash
		#otherwise exit sub
		foreach my $item (@items) {
			if (substr($item, 0, 1) ne '/') {
				return;
			}
		}

		WriteLog("Items found: " . scalar @items);

		my $pullItemLimit = GetConfig('admin/pull_item_limit');
		my $itemsPulledCounter = 0;

		foreach my $item (@items) {
			my @itemArray = split('\|', $item);

			my $fileName = $itemArray[0];
			my $fileHash = $itemArray[1];
			if (-e '.' . $fileName) {
				print 'Exists: ' . $fileName . "\n";

				my $fileLocalHash = GetFileHash('.' . $fileName);

				WriteLog('Remote: ' . $fileHash);
				WriteLog(' Local: ' . $fileLocalHash);
			} else {
				my $fileUrl = $hostBase . $fileName;

				WriteLog('Absent: ' . $fileUrl);

				$itemsPulledCounter++;

				PullItemFromHost($hostBase, $fileName, $fileHash);
			}

			if ($itemsPulledCounter >= $pullItemLimit) {
				WriteLog("Items to pull limit reached for host, exiting PullFeedFromHost");

				last;
			}
		}
	}
}


# my $FILE = '/etc/sysconfig/network';
# my $DIR = dirname($FILE);
# print $DIR, "\n";

sub PushItemToHost { # $host, $fileName, [$fileHash] ;  pushes an item to host via /post.html
	my $host = shift;
	my $fileName = shift;
	my $fileHash = shift; # optional, calculated from $fileName if missing

	if (!$host || !$fileName) {
		WriteLog('PushItemToHost: warning: sanity check failed');
		return '';
	}
	chomp $host;
	chomp $fileName;

	if (IsFileDeleted($fileName, $fileHash)) {
		WriteLog("PushItemToHost: IsFileDeleted() returned true, skipping");
		return;
	}

	if (!$fileHash) {
		$fileHash = GetFileHash($fileName);
		WriteLog('PushItemToHost: $fileHash was not specified, GetFileHash($fileName) returned: ' . $fileHash);
	}
	chomp $fileHash;

	my $curlPrefix = '';
	if ($host =~ /\.onion$/ || $host =~ /\.onion:.+/) {
		#todo feature-check for torify and onions
		WriteLog('PushItemToHost: adding torify prefix');
		$curlPrefix = 'torify ';
	}

	my $pushHash = sha1_hex($host . '|' . $fileHash);
	WriteLog("PushItemToHost($host, $fileName, $fileHash");

	my $pushLog = "./log/push.log";
	my $grepResult = `grep -i "$pushHash" $pushLog`;
	if ($grepResult) {
		WriteLog('Already pushed! ' . $grepResult);
		return 0;
	} else {
		WriteLog('Not pushed yet, trying now');
		AppendFile($pushLog, $pushHash);
	}

	my $fileContents = GetFile($fileName);
	$fileContents = uri_escape($fileContents);

	my $url = 'http://' . $host . "/post.html?comment=" . $fileContents;
	$url = EscapeShellChars($url);

	my $curlCommand = $curlPrefix . 'curl';
	WriteLog("$curlCommand \"$url\"");

	my $curlResult = `$curlCommand \"$url\"`;
	PutFile("once/$pushHash", $curlResult);

	return $curlResult;
} # PushItemToHost()

sub PullItemFromHost { #pulls item from host by downloading it via its .txt url
	my $host = shift;
	my $fileName = shift;
	my $hash = shift;

	chomp $host;
	chomp $fileName;
	chomp $hash;

	if (IsFileDeleted(0, $hash)) {
		WriteLog("PullItemFromHost: IsFileDeleted() returned true, skipping");
		return;
	}

	WriteLog("PullItemFromHost($host, $fileName, $hash");

	my $curlPrefix = '';
	if ($host =~ /\.onion$/ || $host =~ /\.onion:.+/) {
		$curlPrefix = 'torify ';
	}

	my $url = $host . $fileName;

	#print $url;
	$url = EscapeShellChars($url);

	my $curlCommand = $curlPrefix . 'curl';
	WriteLog('PullItemFromHost: $curlCommand = ' . $curlCommand . ' (-s "$url")');
	WriteLog('PullItemFromHost: $url = ' . $url);

	#my $remoteFileContents = '';#####`curl -A useragent -s $url`;
	my $remoteFileContents = `$curlCommand -s "$url"`;
	my $localPath = '.' . $fileName;
	my $localDir = dirname($localPath);

	#todo refactor into a utils function
	if (!-d "$localDir") {
		WriteLog("PullItemFromHost: mkdir -p $localDir");
		system("mkdir -p $localDir");
	}
	WriteLog("PullItemFromHost: PutFile($localPath)");
	PutFile($localPath, $remoteFileContents);
} # PullItemFromHost()


sub PushItemsToHost { #pushes items to $host which have not already been pushed
	my $host = shift;
	chomp($host);

	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	my $pushItemLimit = GetConfig('admin/push_item_limit');
	my $itemsPushedCounter = 0;

	foreach my $file(@files) {
		my $fileName = $file->{'file_path'};
		my $fileHash = $file->{'file_hash'};

		if (PushItemToHost($host, $fileName, $fileHash)) {
			$itemsPushedCounter++;
		}

		if ($itemsPushedCounter >= $pushItemLimit) {
			WriteLog("Items to pull limit reached for host, exiting PullFeedFromHost");

			last;
		}
	}
}

my @hostsToPull = split("\n", GetConfig('pull_hosts'));

foreach my $host (@hostsToPull) {
	#PullFeedFromHost($host);
	PushItemsToHost($host);
}