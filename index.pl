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

	my $txt = "";
	my $message = "";
	my $isSigned = 0;

	my $gpgKey;
	my $alias;
	my $fingerprint;
	my $addedTime;

	my $gitHash;
	my $isAdmin = 0;

	my $verifyError = 0;

	my $itemTypeMask = 0;

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
		$verifyError = $gpgResults{'verifyError'} ? 1 : 0;

		WriteLog('IndexFile: $file = ' . $file . ', $gitHash = ' . $gitHash);

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $gitHash) {
			#if the file is present in deleted.log, it has no business being around
			#delete it immediately and return, logging the action
			WriteLog("IndexFile: $gitHash exists in deleted.log, removing $file");

			unlink($file);
			unlink($gitHash . ".html");

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

			my $newAddedTime = time();

			my $logLine = $gpgResults{'gitHash'} . '|' . $newAddedTime;
			AppendFile('./log/added.log', $logLine);

			DBAddAddedTimeRecord($gpgResults{'gitHash'}, $newAddedTime);
			DBAddAddedTimeRecord('flush');
		}

		# if there is no admin set, and config/admin_imprint is true
		# and if this item is a public key
		# go ahead and make this user admin
		# and announce it via a new .txt file
		if (!GetAdminKey() && GetConfig('admin_imprint') && $gpgKey && $alias) {
			PutFile('./admin.key', $txt);

			PutFile('./html/txt/' . time() . '_admin.txt', "Server Message:\n\nThere was no admin, and $gpgKey came passing through, so I made them admin.\n\n(This happens when config/admin_imprint is true and there is no admin set.)\n\n" . time());
		}

		if ($isSigned && $gpgKey && ($gpgKey eq GetAdminKey())) {
			$isAdmin = 1;

			DBAddVoteRecord($gitHash, $addedTime, 'type:admin');
		}

		if ($isSigned && $gpgKey) {
			DBAddAuthor($gpgKey);
		}

		if ($alias) {
			DBAddKeyAlias ($gpgKey, $alias, $fingerprint);

			DBAddKeyAlias('flush');
		}

		my $itemName = TrimPath($file);

		# look for quoted message ids
		if ($message) {
			my @replyLines = ( $message =~ m/^\>\>([0-9a-f]{40})/mg );

			if (@replyLines) {
				while(@replyLines) {
					my $parentHash = shift @replyLines;

					if (IsSha1($parentHash)) {
						DBAddItemParent($gitHash, $parentHash);
					}
				}

				DBAddItemParent('flush');
			}
		}

		#look for addvouch, which adds a voting vouch for a user
		#
		# addvouch/F82FCD75AAEF7CC8/20
		if ($message) {
			my @weightLines = ( $message =~ m/^addvouch\/([0-9A-F]{16})\/([0-9]+)/mg );
			
			if (@weightLines) {
				my $lineCount = @weightLines / 2;

				if ($isSigned) {
					if ($gpgKey = GetAdminKey()) {
						while(@weightLines) {
							my $voterId = shift @weightLines;
							my $voterWt = shift @weightLines;
							#my $voterAvatar = GetAvatar($voterId);
							#bug calling GetAvatar before the index is generated results in an avatar without alias

							my $reconLine = "addvouch/$voterId/$voterWt";

							$message =~ s/$reconLine/[User $voterId has been vouched for with a weight of $voterWt.]/g;
						}

						DBAddVoteWeight('flush');

						DBAddVoteRecord($gitHash, $addedTime, 'type:vouch');

						DBAddVoteRecord('flush');
					}
				}
			}
		}

		#look for votes
		if ($message) {
			my @eventLines = ( $message =~ m/^addevent\/([0-9a-f]{40})\/([0-9]+)\/([0-9]+)\/([0-9a-f]{32})/mg );
			#                                 prefix   /description    /time     /duration /csrf

			if (@eventLines) {
				my $lineCount = @eventLines / 4;
				#todo assert no remainder

				WriteLog("DBAddEventRecord \$lineCount = $lineCount");

				while (@eventLines) {
					my $descriptionHash = shift @eventLines;
					my $eventTime = shift @eventLines;
					my $eventDuration = shift @eventLines;
					my $csrf = shift @eventLines;

					if ($isSigned) {
						DBAddEventRecord($gitHash, $descriptionHash, $eventTime, $eventDuration, $gpgKey);
					} else {
						DBAddEventRecord($gitHash, $descriptionHash, $eventTime, $eventDuration);
					}

					DBAddItemParent($gitHash, $descriptionHash);

					my $reconLine = "addevent/$descriptionHash/$eventTime/$eventDuration/$csrf";
					$message =~ s/$reconLine/[Event: $descriptionHash at $eventTime for $eventDuration]/g; #todo flesh out message

					DBAddVoteRecord ($gitHash, $addedTime, 'type:event');

					DBAddVoteRecord('flush');

					DBAddEventRecord('flush');

					DBAddItemParent('flush');
				}
			}

			my @voteLines = ( $message =~ m/^addvote\/([0-9a-f]{40})\/([0-9]+)\/([a-z]+)\/([0-9a-f]{32})/mg );
			#                                prefix  /file hash         /time     /tag      /csrf

			#addvote/d5145c4716ebe71cf64accd7d874ffa9eea6de9b/1542320741/informative/573defc376ff80e5181cadcfd2d4196c

			if (@voteLines) {
				my $lineCount = @voteLines / 4;
				#todo assert no remainder

#				if ($isSigned) {
#					$message = "$gpgKey is adding $lineCount votes:\n" . $message;
#				} else {
#					$message = "A mysterious stranger is adding $lineCount votes:\n" . $message;
#				}

				while(@voteLines) {
					my $fileHash   = shift @voteLines;
					my $ballotTime = shift @voteLines;
					my $voteValue  = shift @voteLines;
					my $csrf = shift @voteLines;
					#shift @voteLines;

					if ($isSigned) {
						DBAddVoteRecord($fileHash, $ballotTime, $voteValue, $gpgKey);
					} else {
						DBAddVoteRecord($fileHash, $ballotTime, $voteValue);
					}

					DBAddItemParent($gitHash, $fileHash);

					#$message .= "\nAt $ballotTime, a vote of \"$voteValue\" on the item $fileHash.";
					my $reconLine = "addvote/$fileHash/$ballotTime/$voteValue/$csrf";
					$message =~ s/$reconLine/[Vote on $fileHash at $ballotTime: $voteValue]/g;

					DBAddVoteRecord ($gitHash, $addedTime, 'type:vote');
				}

				DBAddVoteRecord('flush');

				DBAddItemParent('flush');
			}
		}

		if ($alias) {
			DBAddVoteRecord ($gitHash, $addedTime, 'type:pubkey');;

			DBAddVoteRecord('flush');
		}

		if ($message) {
			my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
			WriteLog("\n====\n" . $messageCacheName . "\n====\n" . $message . "\n====\n" . $txt . "\n====\n");
			PutFile($messageCacheName, $message);
		} else {
			WriteLog('I was going to save $messageCacheName, but $message is blank!');
		}

		if ($isSigned) {
			DBAddItem ($file, $itemName, $gpgKey, $gitHash, $itemTypeMask);
		} else {
			DBAddItem ($file, $itemName, '',      $gitHash, $itemTypeMask);
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
