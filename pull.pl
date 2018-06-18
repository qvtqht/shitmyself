#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

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

		foreach my $item (@items) {
			my @itemArray = split('\|', $item);

			my $fileName = $itemArray[0];
			my $fileHash = $itemArray[1];
			if (-e '.' . $fileName) {
				print 'Exists: ' . $fileName . "\n";

				my $fileLocalHash = GetFileHash('.' . $fileName);

				print 'Remote: ' . $fileHash . "\n";
				print ' Local: ' . $fileLocalHash . "\n";
			} else {
				my $fileUrl = $hostBase . $fileName;

				print 'Absent: ' . $fileUrl . "\n";

				PullItemFromHost($fileUrl, $fileHash);
			}
		}
	}
}

sub PullItemFromHost {
	my $url = shift;
	my $hash = shift;

	chomp $url;
	chomp $hash;

	print "Pull $url\n";

}

PullFeedFromHost("localhost:3001");