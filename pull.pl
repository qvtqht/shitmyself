#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

use File::Basename qw(dirname);
use URI::Encode qw(uri_encode);
use Digest::SHA qw(sha1_hex);

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

	$hostFeedUrl = $hostFeedUrl . '?you=' . uri_encode($host);

	my @myHosts = split("\n", GetConfig('my_hosts'));
	my $myHostUrl = $myHosts[rand @myHosts];

	$hostFeedUrl .= '&me=' . uri_encode($myHostUrl);

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

	chomp $host;
	chomp $fileName;

	WriteLog("PushItemToHost($host, $fileName");

	my $fileContents = GetFile($fileName);
	$fileContents = uri_encode($fileContents);

	my $url = 'http://' . $host . "/gracias.html?comment=" . $fileContents;
	$url = EscapeShellChars($url);

	WriteLog("curl \"$url\"");

	my $curlResult = `curl \"$url\"`;

	return $curlResult;
}

sub PullItemFromHost {
	my $host = shift;
	my $fileName = shift;
	my $hash = shift;

	chomp $host;
	chomp $fileName;
	chomp $hash;

	WriteLog("PullItemFromHost($host, $fileName, $hash");

	my $url = $host . $fileName;

	#print $url;

	WriteLog ("curl -s $url");

	#my $remoteFileContents = `curl -A useragent -s $url`;
	my $remoteFileContents = `curl -s $url`;

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

	my $cachePrefix = "./cache/push/";

	foreach my $file(@files) {
		my $fileName = $file->{'file_path'};
		my $fileHash = $file->{'file_hash'};

		my $hostHash = sha1_hex($host);

		if (!GetFile("$cachePrefix/$hostHash/$fileHash")) {
			PushItemToHost($host, $fileName);
			PutFile("$cachePrefix/$hostHash/$fileHash", 1);
		}
	}
}

my @hostsToPull = split("\n", GetConfig('pull_hosts'));

foreach my $host (@hostsToPull) {
	PullFeedFromHost($host);
	#PushItemsToHost($host);
}