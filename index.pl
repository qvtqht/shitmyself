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
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush), flushes any queued queries

	my $file = shift;
	chomp($file);

	WriteLog("IndexFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexFile(flush)");

		DBAddAuthor('flush');
		DBAddKeyAlias('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddEventRecord('flush');
		DBAddItemParent('flush');
		DBAddVoteWeight('flush');
		DBAddPageTouch('flush');
		DBAddConfigValue('flush');
		DBAddTitle('flush');

		return;
	}

	# file's attributes
	my $txt = "";           # original text inside file
	my $message = "";       # outputted text after parsing
	my $isSigned = 0;       # was this item signed?

	my $addedTime;          # time added, epoch format
	my $gitHash;            # git's hash of file blob, used as identifier
	my $isAdmin = 0;        # was this posted by admin?

	# author's attributes
	my $gpgKey;             # author's gpg key, hex 16 chars
	my $alias;              # author's alias, as reported by gpg's parsing of their public key
	my $fingerprint;        # author's gpg key, long-ass format (not used currently)

	my $verifyError = 0;    # was there an error verifying the file with gpg?

	my $hasParent = 0;

	if (IsServer($gpgKey)) { #todo
		#push @allowedactions addedtime
	}
	if (IsAdmin($gpgKey)) { #todo
		#push @allowedactions addvouch
		#push @allowedactions setconfig
	}

#	if (substr(lc($file), length($file) -4, 4) eq ".txt" || substr(lc($file), length($file) -3, 3) eq ".md") {
#todo add support for .md (markdown) files

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		my %gpgResults = GpgParse($file);
		# see what gpg says about the file.
		# if there is no gpg content, the attributes are still populated as possible

		$txt = $gpgResults{'text'};
		$message = $gpgResults{'message'};
		$isSigned = $gpgResults{'isSigned'};
		$gpgKey = $gpgResults{'key'};
		$alias = $gpgResults{'alias'};
		$gitHash = $gpgResults{'gitHash'};
		$fingerprint = $gpgResults{'fingerprint'};
		$verifyError = $gpgResults{'verifyError'} ? 1 : 0;

		WriteLog("\$alias = $alias");

		my $detokenedMessage = $message;
		# this is used to store $message minus any tokens found
		# in the end, we will see if it is empty, and set flags accordingly

		$addedTime = DBGetAddedTime($gpgResults{'gitHash'});
		# get the file's added time.

		# debug output
		WriteLog('... $file = ' . $file . ', $gitHash = ' . $gitHash);

		# if the file is present in deleted.log, get rid of it and its page, return
		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $gitHash) {
			# write to log
			WriteLog("... $gitHash exists in deleted.log, removing $file");

			# unlink the file itself
			if (-e $file) {
				unlink($file);
			}

			# find the html file and unlink it too
			#my $htmlFilename = 'html/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";
			my $htmlFilename = 'html/' .GetHtmlFilename($gitHash);

			if (-e $htmlFilename) {
				unlink($htmlFilename);
			}

			return;
		}

		# debug output
		WriteLog("... " . $gpgResults{'gitHash'});
		if ($addedTime) {
			WriteLog("... \$addedTime = $addedTime");
		} else {
			WriteLog("... \$addedTime is not set");
		}

		if (!$addedTime) {
			# This file was not added through access.pl, and has
			# not been indexed before, so it should get an added_time
			# record. This is what we'll do here. It will be picked
			# up and put into the database on the next cycle
			# unless we add provisions for that here #todo

			WriteLog("... No added time found for " . $gpgResults{'gitHash'} . " setting it to now.");

			# current time
			my $newAddedTime = time();
			$addedTime = $newAddedTime; #todo is this right? confirm

			# add new line to added.log
			my $logLine = $gpgResults{'gitHash'} . '|' . $newAddedTime;
			AppendFile('./log/added.log', $logLine);

			# store it in index, since that's what we're doing here
			DBAddAddedTimeRecord($gpgResults{'gitHash'}, $newAddedTime);
			DBAddAddedTimeRecord('flush');
		}

		# if there is no admin set, and config/admin_imprint is true
		# and if this item is a public key
		# go ahead and make this user admin
		# and announce it via a new .txt file
		if (!GetAdminKey() && GetConfig('admin_imprint') && $gpgKey && $alias) {
			PutFile('./admin.key', $txt);

			my $newAdminMessage = 'html/txt/' . time() . '_newadmin.txt';
			PutFile($newAdminMessage, "Server Message:\n\nThere was no admin, and $gpgKey came passing through, so I made them admin.\n\n(This happens when config/admin_imprint is true and there is no admin set.)\n\n" . time());
			ServerSign($newAdminMessage);
		}

		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
			$isAdmin = 1;

			DBAddVoteRecord($gitHash, $addedTime, 'admin');

			DBAddPageTouch('tag', ' admin');
		}

		if ($isSigned && $gpgKey) {
			DBAddAuthor($gpgKey);

			DBAddPageTouch('author', $gpgKey);
		}

		if ($alias) {
			DBAddKeyAlias ($gpgKey, $alias, $fingerprint);

			DBAddPageTouch('author', $gpgKey);
		}

		my $itemName = TrimPath($file);

		# look for quoted message ids
		if ($message) {
			# >> token
			my @replyLines = ( $message =~ m/^\>\>([0-9a-f]{40})/mg );

			if (@replyLines) {
				while(@replyLines) {
					my $parentHash = shift @replyLines;

					if (IsSha1($parentHash)) {
						DBAddItemParent($gitHash, $parentHash);
						DBAddVoteRecord($gitHash, $addedTime, 'reply');
					}

					my $reconLine = ">>$parentHash";

					$message =~ s/$reconLine/$reconLine/;
					#$message =~ s/$reconLine/[In response to message $parentHash]/;
					# replace with itself, no change needed

					$detokenedMessage =~ s/$reconLine//;

					DBAddPageTouch('item', $parentHash);
				}
			}

			$hasParent = 1;
		}

		# look for hash tags
		if ($message) {
			WriteLog("... check for hashtags");
			my @hashTags = ( $message =~ m/\#([a-zA-Z]+)/mg );

			if (@hashTags) {
				WriteLog("... hashtag(s) found");

				while(@hashTags) {
					my $hashTag = shift @hashTags;

					if ($hashTag) { #todo add sanity checks here
						DBAddVoteRecord($gitHash, $addedTime, $hashTag);

						DBAddPageTouch('tag', $hashTag);
					}
				}
			}
		}

		if ($message) {
			if (IsAdmin($gpgKey)) {
				if (trim($message) eq 'upgrade_now') {
					my $time = time();

					my $upgradeNow = system('perl ./upgrade.pl');

					PutFile('html/txt/upgrade_' . $time . '.txt', $upgradeNow);

#					PutConfig('upgrade_now', time());
					AppendFile('log/deleted.log', $gitHash);
				}
			}
		}

		if ($message) {
			#look for setconfig
			if (IsAdmin($gpgKey)) {
				#must be admin

				my @setConfigLines = ( $message =~ m/^setconfig\/([a-z0-9_\/]+)=(.+)/mg );

				if (@setConfigLines) {
					my $lineCount = @setConfigLines / 2;

					if ($isSigned) {
						while (@setConfigLines) {
							my $configKey = shift @setConfigLines;
							my $configValue = shift @setConfigLines;

							if (ConfigKeyValid($configKey)) {
								my $reconLine = "setconfig/$configKey=$configValue";

								$message =~ s/$reconLine/[Config changed at $addedTime: $configKey = $configValue]/g;
								$detokenedMessage =~ s/$reconLine//g;

								DBAddConfigValue($configKey, $configValue, $addedTime);

								#todo factor this out? maybe?

								chomp $configValue;

								PutConfig($configKey, $configValue);
							}
						}
					}
				}
			}
		}

		#look for addvouch
		if ($message) {
			# look for addvouch, which adds a voting vouch for a user
			# addvouch/F82FCD75AAEF7CC8/20

			if (IsAdmin($gpgKey)) {
				my @weightLines = ( $message =~ m/^addvouch\/([0-9A-F]{16})\/([0-9]+)/mg );

				if (@weightLines) {
					my $lineCount = @weightLines / 2;

					if ($isSigned) {
						while(@weightLines) {
							my $voterId = shift @weightLines;
							my $voterWt = shift @weightLines;
							#my $voterAvatar = GetAvatar($voterId);
							#bug calling GetAvatar before the index is generated results in an avatar without alias

							my $reconLine = "addvouch/$voterId/$voterWt";

							$message =~ s/$reconLine/[User $voterId has been vouched for with a weight of $voterWt.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							DBAddPageTouch('author', $voterId);
						}

						DBAddVoteRecord($gitHash, $addedTime, 'vouch');

						DBAddPageTouch('tag', 'vouch');
					}
				}
			}
		}

		if ($message) {
			# look for addedtime, which adds an added time for an item
			# #token
			# addedtime/759434a7a060aaa5d1c94783f1a80187c4020226/1553658911

			my @addedLines = ( $message =~ m/^addedtime\/([0-9a-f]{40})\/([0-9]+)/mg );

			if (@addedLines) {
				WriteLog (". addedtime token found!");
				my $lineCount = @addedLines / 2;

				if ($isSigned) {
					WriteLog("... isSigned");
					if (IsServer($gpgKey)) {
						WriteLog("... isServer");
						while(@addedLines) {
							WriteLog("... \@addedLines");
							my $itemHash = shift @addedLines;
							my $itemAddedTime = shift @addedLines;

							WriteLog("... $itemHash, $itemAddedTime");

							my $reconLine = "addedtime/$itemHash/$itemAddedTime";

							WriteLog("... $reconLine");

							$message =~ s/$reconLine/[Item $itemHash was added at $itemAddedTime.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							DBAddItemParent($gitHash, $itemHash);

							DBAddPageTouch('item', $itemHash);
						}

						DBAddVoteRecord($gitHash, $addedTime, 'timestamp');

						DBAddPageTouch('tag', 'timestamp');
					} else {
						#todo
					}
				}
			}

			$hasParent = 1;
		}

		if ($message) {
			# look for addedby, which adds an added time for an item
			# #token
			# addedby/766053fcfb4e835c4dc2770e34fd8f644f276305/2d451ec533d4fd448b15443af729a1c6

			my @addedByLines = ( $message =~ m/^addedby\/([0-9a-f]{40})\/([0-9a-f]{32})/mg );

			if (@addedByLines) {
				WriteLog (". addedby token found!");
				my $lineCount = @addedByLines / 2;

				if ($isSigned) {
					WriteLog("... isSigned");
					if (IsServer($gpgKey)) {
						WriteLog("... isServer");
						while(@addedByLines) {
							WriteLog("... \@addedByLines");
							my $itemHash = shift @addedByLines;
							my $itemAddedBy = shift @addedByLines;

							WriteLog("... $itemHash, $itemAddedBy");

							my $reconLine = "addedby/$itemHash/$itemAddedBy";

							WriteLog("... $reconLine");

							$message =~ s/$reconLine/[Item $itemHash was added by $itemAddedBy.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							#DBAddItemParent($gitHash, $itemHash);
							DBAddItemClient($gitHash, $itemAddedBy);
						}

						#DBAddVoteWeight('flush');

						DBAddVoteRecord($gitHash, $addedTime, 'device');

						DBAddPageTouch('tag', 'device');
					}
				}
			}
		}

		# look for addevent tokens
		# addevent/1551234567/3600/csrf
		if ($message) {
			my @eventLines = ( $message =~ m/^addevent\/([0-9]+)\/([0-9]+)\/([0-9a-f]{32})/mg );
			#                                 prefix   /time     /duration /csrf

			if (@eventLines) {
				my $lineCount = @eventLines / 4;
				#todo assert no remainder

				WriteLog("... DBAddEventRecord \$lineCount = $lineCount");

				while (@eventLines) {
					my $descriptionHash = shift @eventLines;
					my $eventTime = shift @eventLines;
					my $eventDuration = shift @eventLines;
					my $csrf = shift @eventLines;

					if ($isSigned) {
						DBAddEventRecord($gitHash, $descriptionHash, $eventTime, $eventDuration, $gpgKey);
					} else {
						#todo csrf check
						DBAddEventRecord($gitHash, $descriptionHash, $eventTime, $eventDuration);
					}

					DBAddItemParent($gitHash, $descriptionHash);

					my $reconLine = "addevent/$descriptionHash/$eventTime/$eventDuration/$csrf";
					$message =~ s/$reconLine/[Event: $descriptionHash at $eventTime for $eventDuration]/g; #todo flesh out message
					$detokenedMessage =~ s/$reconLine//g;

					DBAddVoteRecord ($gitHash, $addedTime, 'event');

					DBAddPageTouch('tag', 'event');
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

					$detokenedMessage =~ s/$reconLine//g;

					DBAddPageTouch('item', $fileHash);

					DBAddVoteRecord ($gitHash, $addedTime, 'vote');

					DBAddPageTouch('tag', 'vote');

					if (IsAdmin($gpgKey) || IsServer($gpgKey)) {
						if ($voteValue eq 'remove') {
							AppendFile('log/deleted.log', $fileHash);
							#my $htmlFilename = 'html/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
							my $htmlFilename = 'html/' . GetHtmlFilename($fileHash);
							if (-e $htmlFilename) {
								unlink ($htmlFilename);
							}
							if (-e $file) {
								unlink ($file);
							}
							#todo unlink and refresh, or at least tag as needing refresh, any pages which include deleted item
						}
					}
				}

				$hasParent = 1;
			}
		}

		if ($alias) {
			DBAddVoteRecord ($gitHash, $addedTime, 'pubkey');;

			DBAddPageTouch('tag', 'pubkey');

			DBAddPageTouch('author', $gpgKey);
		} else {
			$detokenedMessage = trim($detokenedMessage);
			if ($detokenedMessage eq '') {
				DBAddVoteRecord($gitHash, $addedTime, 'notext');

				DBAddPageTouch('tag', 'notext');
			} else {
				if ($detokenedMessage) {
					my $firstEol = index($detokenedMessage, "\n");
					if ($firstEol <= 80 && $firstEol > 0) {
						my $title = substr($detokenedMessage, 0, $firstEol);

						DBAddTitle($gitHash, $title);
					}
				}

				DBAddVoteRecord($gitHash, $addedTime, 'hastext');

				DBAddPageTouch('tag', 'hastext');
			}

		}

		if ($message) {
			my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
			WriteLog("\n====\n" . $messageCacheName . "\n====\n" . $message . "\n====\n" . $txt . "\n====\n");
			PutFile($messageCacheName, $message);
		} else {
			WriteLog('... I was going to save $messageCacheName, but $message is blank!');
		}

		if ($isSigned) {
			DBAddItem ($file, $itemName, $gpgKey, $gitHash);
		} else {
			DBAddItem ($file, $itemName, '',      $gitHash);
		}

		if ($hasParent == 0) {
#			DBAddVoteRecord($gitHash, $addedTime, 'hasparent');
#		} else {
			DBAddVoteRecord($gitHash, $addedTime, 'topic');
		}

		DBAddPageTouch('item', $gitHash);
	}

	IndexFile('flush')
}

sub MakeIndex {
	WriteLog( "MakeIndex()...\n");

	my @filesToInclude = @{$_[0]};

	foreach my $file (@filesToInclude) {
		WriteLog("MakeIndex: $file");

		IndexFile($file);
	}

	IndexFile('flush');
}


#MakeTagIndex();
1;
