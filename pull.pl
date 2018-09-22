#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

use File::Basename qw(dirname);

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

				PullItemFromHost($hostBase, $fileName, $fileHash);
			}
		}
	}
}


my $FILE = '/etc/sysconfig/network';
my $DIR = dirname($FILE);
print $DIR, "\n";


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

PullFeedFromHost("hike.qdb.us");