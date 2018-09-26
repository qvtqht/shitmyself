#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;


require './utils.pl';
require './sqlite.pl';

WriteLog( "Using $SCRIPTDIR as install root...\n");

#sub MakeTagIndex {
#	print "MakeTagIndex()\n";
#
#	my $tagsWeight = GetConfig("tags_weight");
#
#	if (defined($tagsWeight) && $tagsWeight) {
#		my @tagsToAdd = split("\n", $tagsWeight);
#
#		foreach (@tagsToAdd) {
#			my ($voteValue, $weight) = split('\|', $_);
#
#			DbAddVoteWeight($voteValue, $weight);
#		}
#	}
#}

sub MakeVoteIndex {
	WriteLog( "MakeVoteIndex()\n");

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
		DBAddVoteRecord("flush");
	}
}

sub MakeAddedIndex {
	WriteLog( "MakeAddedIndex()\n");

	my $addedLog = GetFile('log/added.log');

	if (defined($addedLog) && $addedLog) {
		my @addedRecord = split("\n", GetFile("log/added.log"));

		foreach(@addedRecord) {
			my ($filePath, $fileHash, $addedTime) = split('\|', $_);

			DBAddAddedRecord($filePath, $fileHash, $addedTime);
		}

		DBAddAddedRecord('flush');
	}
}

sub IndexFile {
	my $file = shift;

	chomp($file);

	if ($file eq 'flush') {
		WriteLog("IndexFile(flush)");

		DBAddAuthor('flush');
		DBAddKeyAlias('flush');
		DBAddItem('flush');

		return;
	}

	my $txt = "";
	my $message = "";
	my $isSigned = 0;

	my $gpgKey;
	my $alias;
	my $fingerprint;

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
		$fingerprint = $gpgResults{'fingerprint'};

		if ($isSigned && $gpgKey eq GetAdminKey()) {
			$isAdmin = 1;
		}

		if ($isSigned && $gpgKey) {
			DBAddAuthor($gpgKey);
		}

		if ($alias) {
			DBAddKeyAlias ($gpgKey, $alias, $fingerprint);
		}

		my $itemName = TrimPath($file);

		my $parentHash = '';

		if ($message =~ m/parent=(.+)/) {
			if (IsSha1($1)) {
				$parentHash = $1;
			}
		}

		my $isPubKey;
		if ($alias) {
			$isPubKey = 1;
		} else {
			$isPubKey = 0;
		}

		if ($isSigned) {
			DBAddItem ($file, $itemName, $gpgKey, $gitHash, $parentHash, $isPubKey);

			PutFile("./cache/message/$gitHash.message", $message);
		} else {
			DBAddItem ($file, $itemName, '', $gitHash, $parentHash, 0);
		}
	}
}

sub MakeIndex {
	WriteLog( "MakeIndex()...\n");

	my @filesToInclude = @{$_[0]};

	foreach my $file (@filesToInclude) {
		IndexFile($file);
	}

	IndexFile('flush');
}


#MakeTagIndex();
1;