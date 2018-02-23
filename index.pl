#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

require './utils.pl';
require './sqlite.pl';

# This holds all the files we will list in the primary index
my @filesToInclude = `find ./txt/ -name \*.txt | sort -r`;

sub MakeVoteIndex {
	my $voteLog = GetFile("log/votes.log");

	if (defined($voteLog) && $voteLog) {
		my @voteRecord = split("\n", GetFile("log/votes.log"));

		foreach (@voteRecord) {
			my ($fileHash, $voteHash, $voteValue) = split('\|', $_);

			DBAddVoteRecord($fileHash, $voteHash, $voteValue);
		}
	}
}

sub MakeIndex {
	foreach my $file (@filesToInclude) {
		chomp($file);

		my $txt = "";
		my $message = "";
		my $isSigned = 0;

		my $gpgKey;
		my $alias;

		my $gitHash;
		my $isAdmin = 0;

		if (substr($file, length($file) -4, 4) eq ".txt") {
			my %gpgResults = GpgParse($file);

			$txt = $gpgResults{'text'};
			$message = $gpgResults{'message'};
			$isSigned = $gpgResults{'isSigned'};
			$gpgKey = $gpgResults{'key'};
			$alias = $gpgResults{'alias'};
			$gitHash = $gpgResults{'gitHash'};

			if ($isSigned && $gpgKey eq GetAdminKey()) {
				$isAdmin = 1;
			}

			if ($isSigned && $gpgKey) {
				DBAddAuthor($gpgKey);
			}

			if ($alias) {
				DBAddKeyAlias ($gpgKey, $alias);
			}

			my $itemName = TrimPath($file);

			if ($isSigned) {
				DBAddItem ($file, $itemName, $gpgKey, $gitHash);

				PutFile("./cache/message/$gitHash.message", $message);
			} else {
				DBAddItem ($file, $itemName, '', $gitHash);
			}
		}
	}
}

SqliteUnlinkDb();
SqliteMakeTables();

MakeVoteIndex();

MakeIndex(@filesToInclude);
