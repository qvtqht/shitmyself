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

sub MakeTagIndex {
	print "MakeTagIndex()\n";

	my $tagsWeight = GetConfig("tags_weight");

	if (defined($tagsWeight) && $tagsWeight) {
		my @tagsToAdd = split("\n", $tagsWeight);

		foreach (@tagsToAdd) {
			my ($voteValue, $weight) = split('\|', $_);

			DbAddVoteWeight($voteValue, $weight);
		}
	}
}

sub MakeVoteIndex {
	print "MakeVoteIndex()\n";

	my $voteLog = GetFile("log/votes.log");

	#This is how long anonymous votes are counted for;
	my $voteLimit = GetConfig('vote_limit');

	my $currentTime = time();

	if (defined($voteLog) && $voteLog) {
		my @voteRecord = split("\n", GetFile("log/votes.log"));

		foreach (@voteRecord) {
			my ($fileHash, $ballotTime, $voteValue) = split('\|', $_);

			if ($currentTime - $ballotTime <= $voteLimit) {
				DBAddVoteRecord($fileHash, $ballotTime, $voteValue);
			}
		}
	}
}

sub MakeAddedIndex {
	print "MakeAddedIndex()\n";

	my $addedLog = GetFile('log/added.log');

	if (defined($addedLog) && $addedLog) {
		my @addedRecord = split("\n", GetFile("log/added.log"));

		foreach(@addedRecord) {
			my ($filePath, $fileHash, $addedTime) = split('\|', $_);

			DBAddAddedRecord($filePath, $fileHash, $addedTime);
		}
	}
}

sub IndexFile {
	my $file = shift;

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

		my $parentHash = '';

		if ($message =~ m/parent=(.+)/) {
			if (IsSha1($1)) {
				$parentHash = $1;
			}
		}

		if ($isSigned) {
			DBAddItem ($file, $itemName, $gpgKey, $gitHash, $parentHash);

			PutFile("./cache/message/$gitHash.message", $message);
		} else {
			DBAddItem ($file, $itemName, '', $gitHash, $parentHash);
		}
	}
}

sub MakeIndex {
	print "MakeIndex()...\n";

	my @filesToInclude = @{$_[0]};

	foreach my $file (@filesToInclude) {
		IndexFile($file);
	}
}

SqliteUnlinkDb();
SqliteMakeTables();

# This holds all the files we will list in the primary index
my @filesToInclude = `find ./txt/ | grep \.txt\$ | sort -r`;

MakeIndex(\@filesToInclude);

MakeVoteIndex();

MakeAddedIndex();

MakeTagIndex();