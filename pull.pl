#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

use File::Basename qw(dirname);
use URI::Encode qw(uri_encode);
use Digest::SHA qw(sha1_hex);
use URI::Escape qw(uri_escape);

use lib 'lib';

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

require './utils.pl';
require './sqlite.pl';

sub PullFeedFromHost {
	my $host = shift;

	chomp $host;

	my $hostBase = "http://" . $host;

	my $hostFeedUrl = $hostBase . "/rss.txt";

	$hostFeedUrl = $hostFeedUrl . '?you=' . uri_escape($host);

	my @myHosts = split("\n", GetConfig('my_hosts'));
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

		my $pullItemLimit = GetConfig('pull_item_limit');
		my $itemsPulledCounter = 0;

		foreach my $item (@items) {
			my @itemArray = split('\|', $item);

			my $fileName = $itemArray[0];
			my $fileHash = $itemArray[1];
			if (-e '.' . $fileName) {
				print 'Exists: ' . $fileName . "\n";

				my $fileLocalHash = GetFileHash('.' . $fileName);

				WriteLog ('Remote: ' . $fileHash);
				WriteLog (' Local: ' . $fileLocalHash);
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


my $FILE = '/etc/sysconfig/network';
my $DIR = dirname($FILE);
print $DIR, "\n";

sub PushItemToHost {
	my $host = shift;
	my $fileName = shift;
	my $fileHash = shift;

	if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
		WriteLog("PushItemToHost: $fileHash exists in deleted.log, skipping");

		return;
	}

	chomp $host;
	chomp $fileName;
	chomp $fileHash;

	my $curlPrefix = '';
	if ($host =~ /\.onion$/ || $host =~ /\.onion:.+/) {
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

	my $url = 'http://' . $host . "/gracias.html?comment=" . $fileContents;
	$url = EscapeShellChars($url);

	my $curlCommand = $curlPrefix . 'curl';
	WriteLog("$curlCommand \"$url\"");

	my $curlResult = `$curlCommand \"$url\"`;

	return $curlResult;
}

sub PullItemFromHost {
	my $host = shift;
	my $fileName = shift;
	my $hash = shift;

	chomp $host;
	chomp $fileName;
	chomp $hash;

	if (GetFile('log/deleted.log') =~ $hash) {
		WriteLog("PullItemFromHost: $hash exists in deleted.log, skipping");

		return;
	}

	WriteLog("PullItemFromHost($host, $fileName, $hash");

	my $curlPrefix = '';
	if ($host =~ /\.onion$/ || $host =~ /\.onion:.+/) {
		$curlPrefix = 'torify ';
	}

	my $url = $host . $fileName;

	#print $url;

	my $curlCommand = $curlPrefix . 'curl';

	WriteLog ("$curlCommand -s $url");

	#my $remoteFileContents = '';#####`curl -A useragent -s $url`;
	my $remoteFileContents = `$curlCommand -s $url`;

	my $localPath = '.' . $fileName;

	my $localDir = dirname($localPath);

	#todo refactor into a utils function
	if (!-d "$localDir") {
		system("mkdir -p $localDir");
	}

	WriteLog("PutFile($localPath)");

	PutFile($localPath, $remoteFileContents);
}


sub PushItemsToHost {
	my $host = shift;
	chomp($host);

	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	my $pushItemLimit = GetConfig('push_item_limit');
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