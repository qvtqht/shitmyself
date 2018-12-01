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
			my ($filePath, $addedTime) = split('\|', $_);

			DBAddAddedTimeRecord($filePath, $addedTime);
		}

		DBAddAddedTimeRecord('flush');
	}
}

sub IndexFile {
	my $file = shift;
	chomp($file);

	WriteLog("IndexFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexFile(flush)");

		DBAddAuthor('flush');
		DBAddKeyAlias('flush');
		DBAddItem('flush');

		return;
	}

	my $newFile = shift;
	if ($newFile) {
		chomp($newFile);
	} else {
		$newFile = 0;
	}

	my $txt = "";
	my $message = "";
	my $isSigned = 0;

	my $gpgKey;
	my $alias;
	my $fingerprint;
	my $addedTime;

	my $gitHash;
	my $isAdmin = 0;

	#my $isAction = 0;

	if (substr($file, length($file) -4, 4) eq ".txt") {
		my %gpgResults = GpgParse($file);

		$txt = $gpgResults{'text'};
		$message = $gpgResults{'message'};
		$isSigned = $gpgResults{'isSigned'};
		$gpgKey = $gpgResults{'key'};
		$alias = $gpgResults{'alias'};
		$gitHash = $gpgResults{'gitHash'};
		$fingerprint = $gpgResults{'fingerprint'};
		$addedTime = DBGetAddedTime($gpgResults{'gitHash'});

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $gitHash) {
			WriteLog("IndexFile: $gitHash exists in deleted.log, removing $file");

			unlink($file);
			unlink($file . ".html");

			return;
		}

		WriteLog("\$addedTime = $addedTime");
		WriteLog($gpgResults{'gitHash'});

		if (!$addedTime) {
			# This file was not added through access.pl, and has
			# not been indexed before, so it should get an added_time
			# record. This is what we'll do here. It will be picked
			# up and put into the database on the next cycle
			# unless we add provisions for that here #todo

			WriteLog("No added time found for " . $gpgResults{'gitHash'} . " setting it to now.");

			my $logLine = $gpgResults{'gitHash'} . '|' . time();
			AppendFile('./log/added.log', $logLine);
		}

		if ($isSigned && $gpgKey eq GetAdminKey()) {
			$isAdmin = 1;
		}

		if ($isSigned && $gpgKey) {
			DBAddAuthor($gpgKey);
			if ($newFile) {
				UnlinkCache("key/$gpgKey");
			}
		}

		if ($alias) {
			DBAddKeyAlias ($gpgKey, $alias, $fingerprint);
		}

		my $itemName = TrimPath($file);

		my $parentHash = '';

		# look for quoted message ids
		{
			if ($message =~ m/^\>>([0-9a-fA-F]{40})/) {
				if (IsSha1($1)) {
					$parentHash = $1;
				}
			}
		}
		#addtag/d5145c4716ebe71cf64accd7d874ffa9eea6de9b/1542320741/informative/573defc376ff80e5181cadcfd2d4196c

		#look for votes
		{
			my @voteLines = ( $message =~ m/^addtag\/([0-9a-fA-F]{40})\/([0-9]+)\/([a-z]+)\/([0-9a-zA-F]{32})/mg );
			#								 prefix /file hash         /time     /tag      /csrf

			my $lineCount = @voteLines / 4;

			if (@voteLines) {
				if ($isSigned) {
					$message = "$gpgKey is adding $lineCount votes:\n";
				} else {
					$message = "A mysterious stranger is adding $lineCount votes:\n";
				}

				while(@voteLines) {
					my $fileHash   = shift @voteLines;
					my $ballotTime = shift @voteLines;
					my $voteValue  = shift @voteLines;
					#my $csrf = shift @voteLines;
					shift @voteLines;

					if ($isSigned) {
						DBAddVoteRecord($fileHash, $ballotTime, $voteValue, $gpgKey);
					} else {
						DBAddVoteRecord($fileHash, $ballotTime, $voteValue);
					}

					$message .= "\nAt $ballotTime, a vote of \"$voteValue\" on the item $fileHash.";
				}

				DBAddVoteRecord('flush');

				#$isAction = 1;
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
