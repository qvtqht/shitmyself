#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use POSIX qw(strftime);

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

sub MakeVoteIndex { # Indexes any votes recorded in log/votes.log into database
	WriteLog( "MakeVoteIndex()\n");

	my $voteLog = GetFile("log/votes.log");

	#This is how long anonymous votes are counted for;
	my $voteLimit = GetConfig('admin/vote_limit');

	my $currentTime = GetTime();

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

sub MakeAddedIndex { # reads from log/added.log and puts it into added_time table
	WriteLog( "MakeAddedIndex()\n");

	if (GetConfig('admin/read_added_log')) {
		my $addedLog = GetFile('log/added.log');

		if (defined($addedLog) && $addedLog) {
			my @addedRecord = split("\n", GetFile("log/added.log"));

			foreach(@addedRecord) {
				my ($fileHash, $addedTime) = split('\|', $_);

				DBAddAddedTimeRecord($fileHash, $addedTime);
			}

			DBAddAddedTimeRecord('flush');
		}
	}
}

sub GetPathFromHash {
	my $fileHash = shift;
	chomp $fileHash;

	if (!-e 'html/txt/' . substr($fileHash, 0, 2)) {
		system('mkdir html/txt/' . substr($fileHash, 0, 2));
	}

	if (!-e 'html/txt/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)) {
		system('mkdir html/txt/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2));
	}

	my $fileHashSubDir = substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2);

	if ($fileHash) {
		my $fileHashPath = 'html/txt/' . $fileHashSubDir . '/' . $fileHash . '.txt';

		WriteLog("\$fileHashPath = $fileHashPath");

		return $fileHashPath;
	}
}

sub GetFileHashPath { # Returns text file's standardized path given its filename
# e.g. /01/23/0123abcdef0123456789abcdef0123456789a.txt
# also creates its subdirectories, #todo fixme

	my $file = shift;
	# take parameter

	WriteLog("GetFileHashPath(\$file = $file)");

	# file should exist and not be a directory
	if (!-e $file || -d $file) {
		WriteLog("GetFileHashPath(): Validation failed for $file");
		return;
	}

	if ($file) {
		my $fileHash = GetFileHash($file);
		
		my $fileHashPath = GetPathFromHash($fileHash);
		
		return $fileHashPath;
	}
}

sub IndexTextFile { # indexes one text file into database
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush), flushes any queued queries
# Also sets appropriate page_touch entries

	my $file = shift;
	chomp($file);

	WriteLog("IndexTextFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexTextFile(flush)");

		DBAddAddedTimeRecord('flush');
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
		DBAddItemClient('flush');
		DBAddItemAttribute('flush');
		DBAddLocationRecord('flush');
		DBAddBrcRecord('flush');

		return;
	}

	# admin/organize_files
	# renames files to their hashes
	if (GetConfig('admin/organize_files')) {
		# don't touch server.key.txt or html/txt directory or directories in general
		if ($file ne 'html/txt/server.key.txt' && $file ne 'html/txt' && !-d $file) {
			WriteLog('IndexTextFile: admin/organize_files is set, do we need to organize?');

			# Figure out what the file's path should be
			my $fileHashPath = GetFileHashPath($file);
			
			if ($fileHashPath) {
				# Does it match?
				if ($file eq $fileHashPath) {
					# No action needed
					WriteLog('IndexTextFile: hash path matches, no action needed');
				}
				# It doesn't match, fix it
				elsif ($file ne $fileHashPath) {
					WriteLog('IndexTextFile: hash path does not match, organize');
					WriteLog('Before: ' . $file);
					WriteLog('After: ' . $fileHashPath);
	
					if (-e $fileHashPath) {
						WriteLog("Warning: $fileHashPath already exists!");
					}
	
					rename ($file, $fileHashPath);
	
					# if new file exists
					if (-e $fileHashPath) {
						$file = $fileHashPath; #don't see why not... is it a problem for the calling function?
					} else {
						WriteLog("Very strange... \$fileHashPath doesn't exist? $fileHashPath");
					}
				}
			}
		}
		else {
			WriteLog('IndexTextFile: organizing not needed');
		}
	}


	# file's attributes
	my $txt = "";           # original text inside file
	my $message = "";       # outputted text after parsing
	my $isSigned = 0;       # was this item signed?

	my $addedTime;          # time added, epoch format
	my $addedTimeIsNew = 0; # set to 1 if $addedTime is missing and we just created a new entry
	my $gitHash;            # git's hash of file blob, used as identifier
	my $isAdmin = 0;        # was this posted by admin?

	# author's attributes
	my $gpgKey;             # author's gpg key, hex 16 chars
	my $alias;              # author's alias, as reported by gpg's parsing of their public key

	my $verifyError = 0;    # was there an error verifying the file with gpg?

	my $hasParent = 0;		# has 1 or more parent items?

	my @allowedActions;		# contains actions allowed to signer of message

#	if (substr(lc($file), length($file) -4, 4) eq ".txt" || substr(lc($file), length($file) -3, 3) eq ".md") {
#todo add support for .md (markdown) files

#	if (substr(lc($file), length($file) -4, 4) eq ".jpg") {
#		my $itemName = 'image...';
#		my $gitHash = GetFileHash($file);
#		DBAddItem ($file, $itemName, '',      $gitHash, 'jpg');
#	} #aug29

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		my %gpgResults =  GpgParse($file);

		# see what gpg says about the file.
		# if there is no gpg content, the attributes are still populated as possible

		$txt = $gpgResults{'text'}; # contents of the text file
		$message = $gpgResults{'message'}; # message which will be displayed once tokes are processed
		$isSigned = $gpgResults{'isSigned'}; # is it signed with pgp?
		$gpgKey = $gpgResults{'key'}; # if it is signed, fingerprint of signer
		
		WriteLog('IndexTextFile: $gpgKey = ' . ($gpgKey ? $gpgKey : '--'));
		
		$alias = $gpgResults{'alias'}; # alias of signer (from public key)
		$gitHash = $gpgResults{'gitHash'}; # hash provided by git for the file
		$verifyError = $gpgResults{'verifyError'} ? 1 : 0; # 

		if (GetConfig('admin/gpg/capture_stderr_output')) {
			if (index($message, 'gpg: Signature made ')) {
				$message =~ s/gpg: Signature made /\n-- \ngpg: Signature made /g;
			}
		}

		if (IsServer($gpgKey)) { #todo
			push @allowedActions, 'addedtime';
			push @allowedActions, 'addedby';
		}
		if (IsAdmin($gpgKey)) { #todo
			#push @allowedactions vouch
			#push @allowedactions setconfig
		}

		WriteLog("IndexTextFile: \$alias = $alias");

		if ($gpgKey) {
			WriteLog("\$gpgKey = $gpgKey");
		} else {
			WriteLog("\$gpgKey = false");
		}

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

			WriteLog('$gitHash = ' . $gitHash);

			my $htmlFilename = GetHtmlFilename($gitHash);

			if ($htmlFilename) {
				$htmlFilename = 'html/' . $htmlFilename;
	
				if (-e $htmlFilename) {
					unlink($htmlFilename);
				}
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
			my $newAddedTime = GetTime();
			$addedTime = $newAddedTime; #todo is this right? confirm

			if (GetConfig('admin/logging/write_added_log')) {
				# add new line to added.log
				my $logLine = $gpgResults{'gitHash'} . '|' . $newAddedTime;
				AppendFile('./log/added.log', $logLine);
			}

			# store it in index, since that's what we're doing here
			DBAddAddedTimeRecord($gpgResults{'gitHash'}, $newAddedTime);

			$addedTimeIsNew = 1;
		}

		# if there is no admin set, and config/admin/admin_imprint is true
		# and if this item is a public key
		# go ahead and make this user admin
		# and announce it via a new .txt file
		if (!GetAdminKey() && GetConfig('admin/admin_imprint') && $gpgKey && $alias) {
			PutFile('./admin.key', $txt);

			my $newAdminMessage = 'html/txt/' . GetTime() . '_newadmin.txt';
			PutFile($newAdminMessage, "Server Message:\n\nThere was no admin, and $gpgKey came passing through, so I made them admin.\n\n(This happens when config/admin/admin_imprint is true and there is no admin set.)\n\n" . GetTime());
			ServerSign($newAdminMessage);
		}

		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
		# it was posted by admin
			$isAdmin = 1;

			DBAddVoteRecord($gitHash, $addedTime, 'admin');

			DBAddPageTouch('tag', 'admin');

			DBAddPageTouch('scores', 0);

			DBAddPageTouch('stats', 0);
		}

		if ($isSigned && $gpgKey) {
		# it was signed and there's a gpg key
			DBAddAuthor($gpgKey);

			DBAddPageTouch('author', $gpgKey);
			
			DBAddPageTouch('scores', 0);

			DBAddPageTouch('stats', 0);
		}

		if ($alias) {
			DBAddKeyAlias ($gpgKey, $alias, $gitHash);
			
			UnlinkCache('avatar/' . $gpgKey);
			UnlinkCache('avatar.color/' . $gpgKey);
			UnlinkCache('pavatar/' . $gpgKey);

			DBAddKeyAlias('flush');

			DBAddPageTouch('author', $gpgKey);

			DBAddPageTouch('scores', 'foo');

			DBAddPageTouch('stats', 'foo');
		}

		DBAddPageTouch('rss', 'foo');

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
			my @hashTags = ( $message =~ m/\#([a-zA-Z0-9]+)/mg );

			if (@hashTags) {
				WriteLog("... hashtag(s) found");

				while(@hashTags) {
					my $hashTag = shift @hashTags;

					if ($hashTag) { #todo add sanity checks here
						DBAddVoteRecord($gitHash, $addedTime, $hashTag);

						DBAddPageTouch('tag', $hashTag);

#						my $hashTagLinkTemplate = GetTemplate('hashtaglink.template');

						#todo
					}
				}
			}
		}

		# look for 'upgrade_now' token
		if ($message) {
			if (IsAdmin($gpgKey)) {
				if (trim($message) eq 'upgrade_now') {
					my $time = GetTime();

					my $upgradeNow = system('perl ./upgrade.pl');

					PutFile('html/txt/upgrade_' . $time . '.txt', $upgradeNow);

#					PutConfig('upgrade_now', time());
					AppendFile('log/deleted.log', $gitHash);
				}
			}
		}

		#look for setconfig and resetconfig
		if ($message) {
			if (IsAdmin($gpgKey) || GetConfig('admin/anyone_can_config') || GetConfig('admin/signed_can_config')) {
				# preliminary conditions

				my @setConfigLines = ( $message =~ m/^(setconfig)\/([a-z0-9\/_.]+)=(.+?)$/mg );

				WriteLog('@setConfigLines = ' . scalar(@setConfigLines));

				my @resetConfigLines = ( $message =~ m/^(resetconfig)\/([a-z0-9\/_]+)/mg );

				WriteLog('@resetConfigLines = ' . scalar(@resetConfigLines));

				push @setConfigLines, @resetConfigLines;

				WriteLog('@setConfigLines = ' . scalar(@setConfigLines));

				if (@setConfigLines) {
					#my $lineCount = @setConfigLines / 3;

					if ($isSigned) {
						while (@setConfigLines) {
							my $configAction = shift @setConfigLines;
							my $configKey = shift @setConfigLines;
							my $configValue;
							if ($configAction eq 'setconfig') {
								$configValue = shift @setConfigLines;
							} else {
								$configValue = 'reset';
							}

							my $reconLine;
							if ($configAction eq 'setconfig') {
								$reconLine = "setconfig/$configKey=$configValue";
							} else {
								$reconLine = "resetconfig/$configKey";
							}

							if (ConfigKeyValid($configKey)) {

								WriteLog(
									'ConfigKeyValid() passed! ' .
									$reconLine .
									'; IsAdmin() = ' . IsAdmin($gpgKey) .
									'; isSigned = ' . $isSigned .
									'; begins with admin = ' . (substr(lc($configKey), 0, 5) ne 'admin') .
									'; signed_can_config = ' . GetConfig('admin/signed_can_config') .
									'; anyone_can_config = ' . GetConfig('admin/anyone_can_config')
								);

								if
								(
									( # either user is admin ...
										IsAdmin($gpgKey)
									)
										||
									( # ... or it can't be under admin/
										substr(lc($configKey), 0, 5) ne 'admin'
									)
										&&
									( # not admin, but may be allowed to edit key ...
										( # if signed and signed editing allowed
											$isSigned
												&&
											GetConfig('admin/signed_can_config')
										)
											||
										( # ... or if anyone is allowed to edit
											GetConfig('admin/anyone_can_config')
										)
									)
								) # condition 1
								{
									DBAddVoteRecord($gitHash, $addedTime, 'config');

									if ($configAction eq 'resetconfig') {
										DBAddConfigValue($configKey, $configValue, $addedTime, 1, $gitHash);
										$message =~ s/$reconLine/[Successful config reset: $configKey will be reset to default.]/g;
									} else {
										DBAddConfigValue($configKey, $configValue, $addedTime, 0, $gitHash);
										$message =~ s/$reconLine/[Successful config change: $configKey = $configValue]/g;
									}

									$detokenedMessage =~ s/$reconLine//g;

								} else {

									$message =~ s/$reconLine/[Attempted change to $configKey ignored. Reason: Not allowed.]/g;
									$detokenedMessage =~ s/$reconLine//g;

								}
							} else {
								$message =~ s/$reconLine/[Attempted change to $configKey ignored. Reason: Config key has no default.]/g;
								$detokenedMessage =~ s/$reconLine//g;
							}
						}
					}
				}
			}
		}

		#look for vouch
		if ($message) {
			# look for vouch, which adds a voting vouch for a user
			# vouch/F82FCD75AAEF7CC8/20

			if (IsAdmin($gpgKey) || $isSigned) {
				my @weightLines = ( $message =~ m/^vouch\/([0-9A-F]{16})\/([0-9]+)/mg );

				if (@weightLines) {
					my $lineCount = @weightLines / 2;

					if ($isSigned) {
						while(@weightLines) {
							my $voterId = shift @weightLines;
							my $voterWt = shift @weightLines;
							#my $voterAvatar = GetAvatar($voterId);
							#bug calling GetAvatar before the index is generated results in an avatar without alias

							my $reconLine = "vouch/$voterId/$voterWt";

							$message =~ s/$reconLine/[User $voterId has been vouched for with a weight of $voterWt.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							DBAddVoteWeight($voterId, $voterWt);

							DBAddPageTouch('author', $voterId);

							DBAddPageTouch('scores', 0);
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

		# look for addedby, which adds an added time for an item token
		# addedby/766053fcfb4e835c4dc2770e34fd8f644f276305/2d451ec533d4fd448b15443af729a1c6
		if ($message) {
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

							DBAddItemParent($gitHash, $itemHash);

							DBAddItemClient($gitHash, $itemAddedBy);
						}

						#DBAddVoteWeight('flush');

						DBAddVoteRecord($gitHash, $addedTime, 'device');

						DBAddPageTouch('tag', 'device');
					}
				}
			}
		}

		# look for sha512 tokens, which adds a sha512 hash for an item token
		# sha512/766053fcfb4e835c4dc2770e34fd8f644f276305/07a1fdc887e71547178dc45b115eac83bc86c4a4a34f8fc468dc3bda0738a47a49bd27a3428b28a0419a5bd2bf926f1ac43964c7614e1cce9438265c008c4cd3
		if ($message) {
			my @sha512Lines = ( $message =~ m/^sha512\/([0-9a-f]{40})\/([0-9a-f]{128})/mg );

			if (@sha512Lines) {
				WriteLog (". sha512 token found!");
				my $lineCount = @sha512Lines / 2;

				if ($isSigned) {
					WriteLog("... isSigned");
					if (IsServer($gpgKey)) {
						WriteLog("... isServer");
						while(@sha512Lines) {
							WriteLog("... \@sha512Lines");
							my $itemHash = shift @sha512Lines;
							my $itemSha512 = shift @sha512Lines;

							WriteLog("... $itemHash, $itemSha512");

							my $reconLine = "sha512/$itemHash/$itemSha512";

							WriteLog("... $reconLine");

							my $itemSha512Shortened = substr($itemSha512, 0, 16) . '...';

							$message =~ s/$reconLine/[Item $itemHash was added with SHA512 hash $itemSha512Shortened.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							DBAddItemParent($gitHash, $itemHash);
						}

						#DBAddVoteWeight('flush');

						DBAddVoteRecord($gitHash, $addedTime, 'sha');

						DBAddPageTouch('tag', 'sha');
					}
				}
			}
		}
#
#		# look for latlong tokens
#		# 40.6905529,-73.9406216
#		# -40.6905529,73.9406216
#		# 40,-73
#		# -73,40
#		# 40/-73
#
#		if ($message) {
#			# get any matching token lines
#			my @latLongLines = ( $message =~ m/^latlong\/(-?[0-9]+\.?[0-9]+?)[\/,](-?[0-9]+\.?[0-9]+?)/mg );
#			#
#
#			if (@latLongLines) {
#				my $lineCount = @latLongLines / 2;
#				#todo assert no remainder
#
#				WriteLog("... DBAddLatLong \$lineCount = $lineCount");
#
#				while (@latLongLines) {
#					my $lat = shift @latLongLines;
#					my $long = shift @latLongLines;
#
#					if ($isSigned) {
#						DBAddLatLongRecord($gitHash, $lat, $long, $gpgKey);
#					} else {
#						DBAddLatLongRecord($gitHash, $lat, $long);
#					}
#				}
#			}
#		}

		# point/x,y
		# line/x1,y1/x2,y2
		# area/x1,y1/x2,y2
		# used for map
		# map definition includes boundaries and included points
		#
		if ($message) {
		}


		# brc/2:00/AA
		# brc/([2-10]:[00-59])/([0A-Z]{1-2})
		if ($message) {
			my @burningManLines = ($message =~ m/^brc\/([0-9]{1,2}):([0-9]{0,2})\/([0A-Z]{1,2})/mg );

			if (@burningManLines) {
				my $lineCount = @burningManLines / 3;
				#todo assert no remainder

				while (@burningManLines) {
					my $aveHours = shift @burningManLines;
					my $aveMinutes = shift @burningManLines;
					my $streetLetter = shift @burningManLines;

					if ($aveHours < 2 || $aveHours > 10) {
						next;
					}

					if ($aveHours == 10 && $aveMinutes > 0) {
						next;
					}

					if ($aveMinutes > 60) {
						next;
					}

					my $reconLine = "brc/$aveHours:$aveMinutes/$streetLetter";
					
					my $streetLetterFormatted = '';
					if ($streetLetter eq '0') {
						$streetLetterFormatted = 'Esplanade';
					} else {
						$streetLetterFormatted = $streetLetter;
					} 
					
					$message =~ s/$reconLine/[BRC Location: $aveHours:$aveMinutes at $streetLetter]/g;

					$detokenedMessage =~ s/$reconLine//g;

					if ($isSigned) {
						DBAddBrcRecord($gitHash, $aveHours, $aveMinutes, $streetLetter, $gpgKey);
					} else {
						DBAddBrcRecord($gitHash, $aveHours, $aveMinutes, $streetLetter);
					}

					DBAddVoteRecord ($gitHash, $addedTime, 'brc');

					DBAddPageTouch('tag', 'brc');
				}
			}
		}


		# look for location (latlong) tokens
		# latlong/44.1234567,-44.433435454
		if ($message) {
			# get any matching token lines
			my @latlongLines = ( $message =~ m/^latlong\/(\-?[0-9]{1,2}\.[0-9]{0,9}),(\-?[0-9]{1,2}\.[0-9]{0,9})/mg );
			#                                   prefix   /lat     /long

			if (@latlongLines) {
				my $lineCount = @latlongLines / 2;
				#todo assert no remainder

				while (@latlongLines) {
					my $latValue = shift @latlongLines;
					my $longValue = shift @latlongLines;

					WriteLog("About to DBAddLocationRecord() ... $latValue, $longValue");

					if ($isSigned) {
						DBAddLocationRecord($gitHash, $latValue, $longValue, $gpgKey);
					} else {
						DBAddLocationRecord($gitHash, $latValue, $longValue);
					}

					my $reconLine = "latlong/$latValue,$longValue";

					$message =~ s/$reconLine/[Location: $latValue,$longValue]/g; #todo flesh out message

					$detokenedMessage =~ s/$reconLine//g;

					DBAddVoteRecord ($gitHash, $addedTime, 'location');

					DBAddPageTouch('tag', 'location');
				}
			}
		}


		# look for event tokens
		# event/1551234567/3600
		if ($message) {
			# get any matching token lines
			my @eventLines = ( $message =~ m/^event\/([0-9]+)\/([0-9]+)/mg );
			#                                 prefix/time     /duration

			if (@eventLines) {
				my $lineCount = @eventLines / 2;
				#todo assert no remainder

				WriteLog("... DBAddEventRecord \$lineCount = $lineCount");

				while (@eventLines) {
					my $eventTime = shift @eventLines;
					my $eventDuration = shift @eventLines;

					if ($isSigned) {
						DBAddEventRecord($gitHash, $eventTime, $eventDuration, $gpgKey);
					} else {
						DBAddEventRecord($gitHash, $eventTime, $eventDuration);
					}

					my $reconLine = "event/$eventTime/$eventDuration";

					#$message =~ s/$reconLine/[Event: $eventTime for $eventDuration]/g; #todo flesh out message

					my ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime($eventTime);
					$year = $year + 1900;
					$month = $month + 1;

					my $eventDurationText = $eventDuration;
					if ($eventDurationText >= 60) {
						$eventDurationText = $eventDurationText / 60;
						if ($eventDurationText >= 60) {
							$eventDurationText = $eventDurationText / 60;
							if ($eventDurationText >= 24) {
								$eventDurationText = $eventDurationText / 24;
								$eventDurationText = $eventDurationText . " days";
							} else {
								$eventDurationText = $eventDurationText . " hours";
							}
						} else {
							$eventDurationText = $eventDurationText . " minutes";
						}
					} else {
						$eventDurationText = $eventDurationText . " seconds";
					}

					if ($month < 10) {
						$month = '0' . $month;
					}
					if ($day_of_month < 10) {
						$day_of_month = '0' . $day_of_month;
					}
					if ($hours < 10) {
						$hours = '0' . $hours;
					}
					if ($minutes < 10) {
						$minutes = '0' . $minutes;
					}
					if ($seconds < 10) {
						$seconds = '0' . $seconds;
					}

					my $dateText = "$year/$month/$day_of_month $hours:$minutes:$seconds";

					$message =~ s/$reconLine/[Event: $dateText for $eventDurationText]/g; #todo flesh out message

					$detokenedMessage =~ s/$reconLine//g;

					DBAddVoteRecord ($gitHash, $addedTime, 'event');

					DBAddPageTouch('tag', 'event');

					DBAddPageTouch('events', 1);
				}
			}
		}

		# look for vote tokens
		if ($message) {
			my @voteLines = ( $message =~ m/^(vote)\/([0-9a-f]{40})\/([0-9]+)\/([a-zé -]+)\/([0-9a-f]{32})/mg );
			#                                prefix  /file hash      /time     /tag      /csrf

			#vote/d5145c4716ebe71cf64accd7d874ffa9eea6de9b/1542320741/informative/573defc376ff80e5181cadcfd2d4196c

			my @addVoteLines = ( $message =~ m/^(addvote)\/([0-9a-f]{40})\/([0-9]+)\/([a-zé -]+)\/([0-9a-f]{32})/mg );
			#                                    prefix   /file hash      /time     /tag      /csrf

			push @voteLines, @addVoteLines;

			if (@voteLines) {
				my $lineCount = @voteLines / 5;
				#todo assert no remainder

#				if ($isSigned) {
#					$message = "$gpgKey is adding $lineCount votes:\n" . $message;
#				} else {
#					$message = "A mysterious stranger is adding $lineCount votes:\n" . $message;
#				}

				while(@voteLines) {
					my $tokenPrefix = shift @voteLines;
					my $voteFileHash   = shift @voteLines;
					my $voteBallotTime = shift @voteLines;
					my $voteValue  = shift @voteLines;
					my $voteCsrf = shift @voteLines;
					#shift @voteLines;

					if ($isSigned) {
						DBAddVoteRecord($voteFileHash, $voteBallotTime, $voteValue, $gpgKey);
					} else {
						DBAddVoteRecord($voteFileHash, $voteBallotTime, $voteValue);
					}

					DBAddVoteRecord($voteFileHash, $addedTime, 'hasvote');

					DBAddItemParent($gitHash, $voteFileHash);

					#$message .= "\nAt $ballotTime, a vote of \"$voteValue\" on the item $fileHash.";
					my $reconLine = "$tokenPrefix/$voteFileHash/$voteBallotTime/$voteValue/$voteCsrf";
					# $message =~ s/$reconLine/[$voteValue] (vote on $fileHash)/g;
					# $message =~ s/$reconLine/[Vote on $fileHash at $ballotTime: $voteValue]/g;
					$message =~ s/$reconLine/>>$voteFileHash\n[$voteValue]/g;

					$detokenedMessage =~ s/$reconLine//g;

					DBAddPageTouch('item', $voteFileHash);

					DBAddVoteRecord ($gitHash, $addedTime, 'vote');

					DBAddPageTouch('tag', 'vote');

					if ($voteValue eq 'remove') {
						my $voteItemAuthor = DBGetItemAuthor($voteFileHash) || '';

						if ($gpgKey && (IsAdmin($gpgKey) || ($gpgKey eq $voteItemAuthor))) {
							WriteLog('Found post requesting remove of file');

							#todo there are bugs here somewhere, messages are not removed completely

							AppendFile('log/deleted.log', $voteFileHash);
							#my $htmlFilename = 'html/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
							my $htmlFilename = 'html/' . GetHtmlFilename($voteFileHash);
							if (-e $htmlFilename) {
								WriteLog($htmlFilename . ' exists, calling unlink()');
								unlink ($htmlFilename);
							} else {
								WriteLog($htmlFilename . ' does NOT exist, very strange');
							}

							if (-e $file) {
								#todo unlink the file represented by $voteFileHash, not $file
								
								if (!GetConfig('admin/logging/record_remove_action')) {
									# this removes the remove call itself
									WriteLog($file . ' exists, calling unlink()');
									unlink($file);
								}

								my $votedFileHashPath = GetPathFromHash($voteFileHash);
								if (-e $votedFileHashPath) {
									WriteLog("removing $votedFileHashPath");
									unlink($votedFileHashPath);
								}

							} else {
								WriteLog($file . ' does NOT exist, very strange');
							}

							#todo unlink and refresh, or at least tag as needing refresh, any pages which include deleted item
						}
					}
				}

				$hasParent = 1;
			}
		}

		# if $alias is set, means this is a pubkey
		if ($alias) {
			DBAddVoteRecord ($gitHash, $addedTime, 'pubkey');
			# add the "pubkey" tag

			DBAddPageTouch('tag', 'pubkey');
			# add a touch to the pubkey tag page

			DBAddPageTouch('author', $gpgKey);
			# add a touch to the author page
			
			UnlinkCache('avatar/' . $gpgKey);
			UnlinkCache('avatar.color/' . $gpgKey);
			UnlinkCache('pavatar/' . $gpgKey);
		} else {
			$detokenedMessage = trim($detokenedMessage);

			if ($detokenedMessage eq '') {
				DBAddVoteRecord($gitHash, $addedTime, 'notext');

				DBAddPageTouch('tag', 'notext');
			} else {
				if ($detokenedMessage) {
					my $firstEol = index($detokenedMessage, "\n");

					my $titleLengthCutoff = GetConfig('title_length_cutoff'); #default = 140
					
					if ($firstEol >= 0) {
						my $title = '';

						if ($firstEol <= $titleLengthCutoff) {
							$title = substr($detokenedMessage, 0, $firstEol);
						} else {
							$title = substr($detokenedMessage, 0, $titleLengthCutoff) . '[...]';
						}						

						DBAddTitle($gitHash, $title);

						DBAddTitle('flush'); #todo refactor this out

						DBAddVoteRecord($gitHash, $addedTime, 'hastitle');
					}

					DBAddVoteRecord($gitHash, $addedTime, 'hastext');

					DBAddPageTouch('tag', 'hastext');
				} else {
					
				}
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
			DBAddItem ($file, $itemName, $gpgKey, $gitHash, 'txt', $verifyError);
		} else {
			DBAddItem ($file, $itemName, '',      $gitHash, 'txt', $verifyError);
		}

		DBAddPageTouch('top', 1);

		if ($hasParent == 0) {
#			DBAddVoteRecord($gitHash, $addedTime, 'hasparent');
#		} else {
			DBAddVoteRecord($gitHash, $addedTime, 'topic');
		}

		DBAddPageTouch('item', $gitHash);

		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
			$isAdmin = 1;

			DBAddVoteRecord($gitHash, $addedTime, 'admin');

			DBAddPageTouch('tag', 'admin');
		}

		if ($isSigned) {
			DBAddKeyAlias('flush');

			DBAddPageTouch('author', $gpgKey);

			DBAddPageTouch('scores', 1);
		}

		DBAddPageTouch('stats', 1);
		
		DBAddPageTouch('events', 1);
											 
		DBAddPageTouch('rss', 'foo');

		DBAddPageTouch('index', 1); #todo verify this works

		DBAddPageTouch('flush');
	}
}

sub WriteIndexedConfig { # writes config indexed in database into config/
	my @indexedConfig = DBGetLatestConfig();

	foreach my $configLine(@indexedConfig) {
		my $configKey = $configLine->{'key'};
		my $configValue = $configLine->{'value'};

		chomp $configValue;
		$configValue = trim($configValue);

		if (IsSha1($configValue)) {
			WriteLog("It's a hash, try to look it up...");

			if (-e 'cache/' . GetMyVersion() . "/message/$configValue") {
				WriteLog("Lookup of $configValue successful");
				$configValue = GetCache("message/$configValue");
			} else {
				WriteLog("Lookup of $configValue UNsuccessful");
			}
		}

		if ($configLine->{'reset_flag'}) {
			ResetConfig($configKey);
		} else {
			PutConfig($configKey, $configValue);
		}
	}
}

sub MakeIndex { # indexes all available text files, and outputs any config found
	WriteLog( "MakeIndex()...\n");

	my @filesToInclude = @{$_[0]}; # ?

	my $filesCount = scalar(@filesToInclude);
	my $currentFile = 0;

	foreach my $file (@filesToInclude) {
		$currentFile++;

		my $percent = $currentFile / $filesCount * 100;

		WriteMessage("*** MakeIndex: $currentFile/$filesCount ($percent %) $file");

		IndexTextFile($file);
	}

	IndexTextFile('flush');

	WriteIndexedConfig();
}

my $arg1 = shift;
if ($arg1) {
	if (-e $arg1) {
		IndexTextFile($arg1);
	}
}


#MakeTagIndex();
1;
