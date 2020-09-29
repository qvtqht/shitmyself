#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use POSIX qw(strftime);
use Cwd qw(cwd);
#use Encode qw( encode_utf8 );

my $SCRIPTDIR = cwd(); # where the perl scripts live
my $HTMLDIR = $SCRIPTDIR . '/html'; # web root
my $TXTDIR = $HTMLDIR . '/txt'; # text files root

require './utils.pl';
require './sqlite.pl';

WriteLog( "Using $SCRIPTDIR as install root...\n");

sub MakeChainIndex { # reads from log/chain.log and puts it into item_attribute table
	WriteLog("MakeChainIndex()\n");

	if (GetConfig('admin/read_added_log')) {
		# my $addedLog = GetFile('log/added.log');
		my $addedLog = GetFile('html/chain.log');

		if (defined($addedLog) && $addedLog) {
			my @addedRecord = split("\n", $addedLog);
			# my @addedRecord = split("\n", GetFile("log/added.log"));

			my $previousLine = '';
			my $sequenceNumber = 0;

			foreach my $currentLine (@addedRecord) {
				my ($fileHash, $addedTime, $proofHash) = split('\|', $currentLine);

				my $expectedHash = md5_hex($previousLine . '|' . $fileHash . '|' . $addedTime);

				if ($expectedHash ne $proofHash) {
					WriteLog('MakeChainIndex: warning: proof hash mismatch. abandoning chain import');

					my $curTime = GetTime();
					my $moveChain = `mv html/chain.log html/chain.log.$curTime ; head -n $sequenceNumber html/chain.log.$curTime > html/chain_new.log; mv html/chain_new.log html/chain.log`;

					my $moveChainMessage = 'Chain break detected. Timestamps for items may reset. #meta #warning ' . $curTime;
					PutFile('html/txt/chain_break_' . $curTime . '.txt');

					MakeChainIndex();

					return;
				}

				DBAddItemAttribute($fileHash, 'chain_timestamp', $addedTime);
				DBAddItemAttribute($fileHash, 'chain_sequence', $sequenceNumber);

				WriteLog('MakeChainIndex: $sequenceNumber = ' . $sequenceNumber);

				$sequenceNumber = $sequenceNumber + 1;

				$previousLine = $currentLine;
			}

			DBAddItemAttribute('flush');
		}
	}
} # MakeChainIndex()

sub IndexTextFile { # $file | 'flush' ; indexes one text file into database
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush'), flushes any queued queries
# Also sets appropriate page_touch entries

	my $file = shift;
	chomp($file);

	if ($file eq 'flush') {
		WriteLog("IndexTextFile(flush)");

		DBAddAuthor('flush');
		DBAddKeyAlias('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddEventRecord('flush');
		DBAddItemParent('flush');
		DBAddPageTouch('flush');
		DBAddConfigValue('flush');
		DBAddItemAttribute('flush');
		DBAddLocationRecord('flush');
		DBAddBrcRecord('flush');

		return;
	}

	WriteLog("IndexTextFile($file)");

	# admin/organize_files
	# renames files to their hashes
	if (GetConfig('admin/organize_files') && substr(lc($file), length($file) -4, 4) eq ".txt") {
		# don't touch server.key.txt or $TXTDIR directory or directories in general
		if ($file ne "$TXTDIR/server.key.txt" && $file ne $TXTDIR && !-d $file) {
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
						# new file already exists, rename only if not larger
						WriteLog("Warning: $fileHashPath already exists!");

						if (-s $fileHashPath > -s $file) {
							unlink ($file);
						} else {
							rename ($file, $fileHashPath);
						}
					} else {
						# new file does not exist, safe to rename
						rename ($file, $fileHashPath);
					}

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
	#my $fileMeta = "";
	my $isSigned = 0;       # was this item signed?
	my $hasCookie = 0;

	my $addedTime;          # time added, epoch format
	my $addedTimeIsNew = 0; # set to 1 if $addedTime is missing and we just created a new entry
	my $fileHash;            # git's hash of file blob, used as identifier
	my $isAdmin = 0;        # was this posted by admin?

	# author's attributes
	my $gpgKey;             # author's gpg key, hex 16 chars
	my $alias;              # author's alias, as reported by gpg's parsing of their public key

	my $verifyError = 0;    # was there an error verifying the file with gpg?

	my $hasParent = 0;		# has 1 or more parent items?

	my $gpgTimestamp = 0;

	my %hasToken; # tokens found in message for secondary parsing

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		my %gpgResults = GpgParse($file);

		# see what gpg says about the file.
		# if there is no gpg content, the attributes are still populated as possible

		# $txt = $gpgResults{'text'};          # contents of the text file
		$txt = $gpgResults{'text'};          # contents of the text file
		$message = $gpgResults{'message'};   # message which will be displayed once tokens are processed
		$isSigned = $gpgResults{'isSigned'}; # is it signed with pgp?
		$gpgKey = $gpgResults{'key'};        # if it is signed, fingerprint of signer
		$gpgTimestamp = $gpgResults{'signTimestamp'} || '';        # signature timestamp

		if (!$isSigned && !$message) {
			$message = GetFile($file);
		}

		if ($gpgKey) {
			chomp $gpgKey;
		} else {
			$gpgKey = '';
		}

		WriteLog('IndexTextFile: $gpgKey = ' . ($gpgKey ? $gpgKey : '--'));
		WriteLog('IndexTextFile: $gpgTimestamp = ' . ($gpgTimestamp ? $gpgTimestamp : '--'));

		$alias = $gpgResults{'alias'};                     # alias of signer (from public key)
		$fileHash = GetFileHash($file);                # hash provided by git for the file
		$verifyError = $gpgResults{'verifyError'} ? 1 : 0; #

		# $fileMeta = GetItemMeta($fileHash, $file);

		# $message .= "\n-- \n" . $fileMeta;

		if (!$alias) {
			$alias = '';
		}
		WriteLog('IndexTextFile: $alias = ' . $alias);

		if ($gpgKey) {
			WriteLog('IndexTextFile: $gpgKey = ' . $gpgKey);
		} else {
			WriteLog('IndexTextFile: $gpgKey is false');
		}

		my $detokenedMessage = $message;
		# this is used to store $message minus any tokens found
		# in the end, we will see if it is empty, and set flags accordingly

		$addedTime = DBGetAddedTime($fileHash);
		# get the file's added time.

		if (!$file || !$fileHash) {
			WriteLog('IndexTextFile: warning: $file or $fileHash missing; returning');
			return;
		}

		# debug output
		WriteLog('IndexTextFile: $file = ' . $file . ', $fileHash = ' . $fileHash);

		# if the file is present in deleted.log, get rid of it and its page, return
		if (IsFileDeleted($file, $fileHash)) {
			WriteLog('IndexTextFile: IsFileDeleted() returned true, returning');

			return;
		}

		# debug output
		WriteLog('IndexTextFile: ' . $fileHash);
		if ($addedTime) {
			WriteLog('IndexTextFile: $addedTime = ' . $addedTime);
		}
		else {
			WriteLog('IndexTextFile: $addedTime is not set');
		}

		if (!$addedTime) {
			# This file has not been indexed before,
			# so it should get an added_time record.
			# This is what we'll do here.

			if (GetConfig('admin/logging/write_chain_log')) {
				AddToChainLog($fileHash);
			}

			WriteLog("... No added time found for " . $fileHash . " setting it to now.");

			# current time
			my $newAddedTime = GetTime();
			$addedTime = $newAddedTime;

			# if (GetConfig('admin/logging/write_added_log')) {
			# 	# add new line to added.log
			# 	my $logLine = $gpgResults{'gitHash'} . '|' . $newAddedTime;
			# 	AppendFile('./log/added.log', $logLine);
			# }

			# store it in index, since that's what we're doing here
			DBAddItemAttribute($fileHash, 'chain_timestamp', $newAddedTime);

			$addedTimeIsNew = 1;
		}

		# admin_imprint
		if ($gpgKey && $alias && !GetAdminKey() && GetConfig('admin/admin_imprint')) {
			# if there is no admin set, and config/admin/admin_imprint is true
			# and if this item is a public key
			# go ahead and make this user admin
			# and announce it via a new .txt file

			PutFile('./admin.key', $txt);

			my $newAdminMessage = $TXTDIR . '/' . GetTime() . '_newadmin.txt';
			PutFile($newAdminMessage, "Server Message:\n\nThere was no admin, and $gpgKey came passing through, so I made them admin.\n\n(This happens when config/admin/admin_imprint is true and there is no admin set.)\n\n#meta\n\n" . GetTime());
			ServerSign($newAdminMessage);
		}

		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
			# it was posted by admin
			$isAdmin = 1;

			if (GetConfig('admin/admin_last_action') < $addedTime) {
				PutConfig('admin/admin_last_action', $addedTime);
			}

			DBAddVoteRecord($fileHash, $addedTime, 'admin');

			DBAddPageTouch('tag', 'admin');

			DBAddPageTouch('scores');

			DBAddPageTouch('stats');
		}

		if ($isSigned && $gpgKey) {
			# it was signed and there's a gpg key
			DBAddAuthor($gpgKey);

			DBAddPageTouch('author', $gpgKey);

			if (! ($gpgKey =~ m/\s/)) {
				#DBAddPageTouch() may be a better place for this
				# sanity check for gpgkey having any whitespace in it before using it in a glob for unlinking cache items
				WriteLog('IndexTextFile: proceeding to unlink avatar caches for ' . $gpgKey);

				#todo make this less "dangerous"
				unlink(glob("cache/*/avatar/*/$gpgKey"));
				unlink(glob("cache/*/avatar.plain/*/$gpgKey"));
			} else {
				WriteLog('IndexTextFile: NOT unlinking avatar caches for ' . $gpgKey);
			}

			DBAddPageTouch('scores');

			DBAddPageTouch('stats');
		}

		if ($alias) {
			# pubkey

			DBAddKeyAlias($gpgKey, $alias, $fileHash);

			UnlinkCache('avatar/' . $gpgKey);
			UnlinkCache('avatar.color/' . $gpgKey);
			UnlinkCache('pavatar/' . $gpgKey);

			DBAddKeyAlias('flush');

			DBAddPageTouch('author', $gpgKey);

			if (GetConfig('admin/index/make_primary_pages')) {
				MakePage('author', $gpgKey);
			}

			DBAddPageTouch('scores');

			DBAddPageTouch('stats');
		}

		DBAddPageTouch('rss');

		my $itemName = TrimPath($file);

		if (GetConfig('admin/token/cookie') && $message) {
			#look for cookies
			my @cookieLines = ($message =~ m/^Cookie:\s(.+)/mg);

			if (@cookieLines) {
				while (@cookieLines) {
					my $cookieValue = shift @cookieLines;

					$hasCookie = $cookieValue; #only the last cookie is used below
					my $reconLine = "Cookie: $cookieValue";
					$detokenedMessage =~ s/$reconLine/[Cookie: $hasCookie]/;

					DBAddAuthor($cookieValue);
					DBAddPageTouch('author', $cookieValue);
					DBAddPageTouch('scores');
					DBAddPageTouch('stats');

					$hasToken{'cookie'} = 1;
				}
			}
		}

		my @itemParents;

		if (GetConfig('admin/token/quote')) {
			# > token
			my @quoteLines = ($message =~ m/^\>([0-9a-f]{40})/mg);

			if (@quoteLines) {
				# wrap it in blockquote or something
			}
		}

		# look for quoted message ids
		if (GetConfig('admin/token/reply') && $message) {
			# >> token
			my @replyLines = ($message =~ m/^\>\>([0-9a-f]{40})/mg);

			if (@replyLines) {
				while (@replyLines) {
					my $parentHash = shift @replyLines;

					if (IsSha1($parentHash)) {
						push @itemParents, $parentHash;
						DBAddItemParent($fileHash, $parentHash);
						DBAddVoteRecord($fileHash, $addedTime, 'reply');
						$hasToken{'reply'} = 1;

						my $reconLine = ">>$parentHash";

						$detokenedMessage =~ s/$reconLine//;
						DBAddPageTouch('item', $parentHash);

						if (GetConfig('admin/index/make_primary_pages')) {
							MakePage('item', $parentHash, 1);
						}
						$hasParent = 1;
					}
				}
			}
		}

		# look for hash tags aka hashtags hash tag hashtag
		if (GetConfig('admin/token/hashtag') && $message) {
			WriteLog("IndexTextFile: check for hashtags...");
			my @hashTags = ($message =~ m/\#([a-zA-Z0-9_]+)/mg);

			if (@hashTags) {
				WriteLog("IndexTextFile: hashtag(s) found");
			}

			while (@hashTags) {
				my $hashTag = shift @hashTags;
				$hashTag = trim($hashTag);

				if ($hashTag) {
					WriteLog('IndexTextFile: $hashTag = ' . $hashTag);

					$hasToken{$hashTag} = 1;

					if ($hasParent) {
						WriteLog('$hasParent');

						if (scalar(@itemParents)) {
							foreach my $itemParentHash (@itemParents) {
								if ($isSigned) {
									# include author's key if message is signed
									DBAddVoteRecord($itemParentHash, $addedTime, $hashTag, $gpgKey, $fileHash);
								}
								else {
									if ($hasCookie) {
										# include author's key if message is cookied
										DBAddVoteRecord($itemParentHash, $addedTime, $hashTag, $hasCookie, $fileHash);
									} else {
										DBAddVoteRecord($itemParentHash, $addedTime, $hashTag, '', $fileHash);
									}
								}
								DBAddPageTouch('item', $itemParentHash);
							}
						}
					} # if ($hasParent)
					else { # no parent, !($hasParent)
						WriteLog('$hasParent is FALSE');

						if ($isSigned) {
							# include author's key if message is signed
							DBAddVoteRecord($fileHash, $addedTime, $hashTag, $gpgKey, $fileHash);
						}
						else {
							if ($hasCookie) {
								DBAddVoteRecord($fileHash, $addedTime, $hashTag, $hasCookie, $fileHash);
							} else {
								DBAddVoteRecord($fileHash, $addedTime, $hashTag, '', $fileHash);
							}
						}
					}

					DBAddPageTouch('tag', $hashTag);

					$detokenedMessage =~ s/#$hashTag//g;
				} # if ($hashTag)
			} # while (@hashTags)
		} # if (GetConfig('admin/token/hashtag') && $message)

		if (GetConfig('admin/token/my_name_is')) {
			# "my name is" token
			if ($hasCookie) {
				my @myNameIsLines = ($message =~ m/^(my name is )([A-Za-z0-9'_\. ]+)\r?$/mig);

				WriteLog('@myNameIsLines = ' . scalar(@myNameIsLines));

				if (@myNameIsLines) {
					#my $lineCount = @myNameIsLines / 2;

					while (@myNameIsLines) {
						my $myNameIsToken = shift @myNameIsLines;
						my $nameGiven = shift @myNameIsLines;

						chomp $nameGiven;
						$nameGiven = trim($nameGiven);

						my $reconLine;
						$reconLine = $myNameIsToken . $nameGiven;

						if ($nameGiven && $hasCookie) {
							$hasToken{'myNameIs'} = 1;

							# # remove alias caches
							# UnlinkCache('avatar/' . $hasCookie);
							# UnlinkCache('avatar.color/' . $hasCookie);
							# UnlinkCache('pavatar/' . $hasCookie);
							#todo make this less "dangerous"
							unlink(glob("cache/*/avatar/*/$gpgKey"));
							unlink(glob("cache/*/avatar.plain/*/$gpgKey"));


							# add alias
							DBAddKeyAlias($hasCookie, $nameGiven, $fileHash);
							DBAddKeyAlias('flush');

							# touch author page
							DBAddPageTouch('author', $hasCookie);

							if (GetConfig('admin/index/make_primary_pages')) {
								MakePage('author', $hasCookie);
							}

							# touch pages which are affected
							DBAddPageTouch('scores');
							DBAddPageTouch('stats');
						}

						$message =~ s/$reconLine/[My name is: $nameGiven for $hasCookie.]/g;
					}
				}
			}
		}

		# title:
		if ($message && GetConfig('admin/token/title')) {
			# #title token is enabled

			# looks for lines beginning with title: and text after
			# only these characters are currently allowed: a-z, A-Z, 0-9, _, and space.
			my @setTitleToLines = ($message =~ m/^(title)(\W+)(.+)$/mig);
			# m = multi-line
			# s = multi-line
			# g = all instances
			# i = case-insensitive

			WriteLog('@setTitleToLines = ' . scalar(@setTitleToLines));

			if (@setTitleToLines) { # means we found at least one title: token;
				WriteLog('#title token found for ' . $fileHash);
				WriteLog('$message = ' . $message);

				#my $lineCount = @setTitleToLines / 3;
				while (@setTitleToLines) {
					# loop through all found title: token lines
					my $setTitleToToken = shift @setTitleToLines;
					my $titleSpace = shift @setTitleToLines;
					my $titleGiven = shift @setTitleToLines;

					chomp $setTitleToToken;
					chomp $titleSpace;
					chomp $titleGiven;
					$titleGiven = trim($titleGiven);

					my $reconLine;
					$reconLine = $setTitleToToken . $titleSpace . $titleGiven;

					WriteLog('title $reconLine = ' . $reconLine);

					if ($titleGiven) {
						$hasToken{'title'} = 1;

						chomp $titleGiven;
						if ($hasParent) {
							# has parent(s), so add title to each parent
							foreach my $itemParent (@itemParents) {
								DBAddItemAttribute($itemParent, 'title', $titleGiven, $addedTime, $fileHash);

								DBAddVoteRecord($itemParent, $addedTime, 'hastitle');

								DBAddPageTouch('item', $itemParent);

								if (GetConfig('admin/index/make_primary_pages')) {
									#todo this may not be the right place for this?
									MakePage('item', $itemParent, 1);
								}
							}
						} else {
							# no parents, so set title to self

							WriteLog('Item has no parent, adding title to itself');

							DBAddVoteRecord($fileHash, $addedTime, 'hastitle');
							DBAddItemAttribute($fileHash, 'title', $titleGiven, $addedTime);
						}
					}

					$message = str_replace($reconLine, '[Title: ' . $titleGiven . ']', $message);
				}
			}
		} # title: token

		# accessloghash: AccessLogHash
		if ($message && GetConfig('admin/token/access_log_hash')) {
			# #title token is enabled

			# looks for lines beginning with title: and text after
			# only these characters are currently allowed: a-z, A-Z, 0-9, _, and space.
			my @lines = ($message =~ m/^(AccessLogHash)(\W+)(.+)$/mig); #todo format instead of .+
			# m = multi-line
			# s = multi-line
			# g = all instances
			# i = case-insensitive

			WriteLog('@lines = ' . scalar(@lines));

			if (@lines) { # means we found at least one line
				WriteLog('#AccessLogHash token found for ' . $fileHash);
				WriteLog('$message = ' . $message);

				#my $lineCount = @setTitleToLines / 3;
				while (@lines) {
					# loop through all found title: token lines
					my $token = shift @lines;
					my $space = shift @lines;
					my $value = shift @lines;

					chomp $token;
					chomp $space;
					chomp $value;
					$value = trim($value);

					my $reconLine; # reconciliation
					$reconLine = $token . $space . $value;

					WriteLog('AccessLogHash $reconLine = ' . $reconLine);

					if ($value) {
						$hasToken{'AccessLogHash'} = 1;

						chomp $value;
						if ($hasParent) {
							# has parent(s), so add title to each parent
							foreach my $itemParent (@itemParents) {
								DBAddItemAttribute($itemParent, 'AccessLogHash', $value, $addedTime, $fileHash);
								DBAddVoteRecord($itemParent, $addedTime, 'hasAccessLogHash');
								DBAddPageTouch('item', $itemParent);

								if (GetConfig('admin/index/make_primary_pages')) {
									#todo this may not be the right place for this?
									MakePage('item', $itemParent, 1);
								}
							}
						} else {
							# no parents, so set title to self
							WriteLog('Item has no parent, ignoring');

							# DBAddVoteRecord($fileHash, $addedTime, 'hasAccessLogHash');
							# DBAddItemAttribute($fileHash, 'AccessLogHash', $titleGiven, $addedTime);
						}
					}

					$message = str_replace($reconLine, '[AccessLogHash: ' . $value . ']', $message);
				}
			}
		} # AccessLogHash token

		#look for #config and #resetconfig
		if (GetConfig('admin/token/config') && $message) {
			if (
				IsAdmin($gpgKey) #admin can always config
					||
				GetConfig('admin/anyone_can_config') # anyone can config
					||
				(
					# signed can config
					GetConfig('admin/signed_can_config')
						&&
					$isSigned
				)
					||
				(
					# cookied can config
					GetConfig('admin/cookied_can_config')
						&&
					$hasCookie
				)
			) {
				# preliminary conditions met

				my @configLines = ($message =~ m/(config)(\W)([a-z0-9\/_]+)(\W?)(.+)$/mg);
				WriteLog('@configLines = ' . scalar(@configLines));

				my @resetConfigLines = ($message =~ m/(resetconfig)(\W)([a-z0-9\/_]+)/mg);
				WriteLog('@resetConfigLines = ' . scalar(@resetConfigLines));
				push @configLines, @resetConfigLines;

				my @setConfigLines = ($message =~ m/(setconfig)\W([a-z0-9\/_.]+)(\W)(.+?)/mg);
				WriteLog('@setConfigLines = ' . scalar(@setConfigLines));
				push @configLines, @setConfigLines;
				# setconfig is alias for previously used token name

				WriteLog('@configLines = ' . scalar(@configLines));

				if (@configLines) {
					#my $lineCount = @configLines / 5;

					while (@configLines) {
						my $configAction = shift @configLines;
						my $space1 = shift @configLines;
						my $configKey = shift @configLines;
						my $space2 = '';
						my $configValue;

						if ($configAction eq 'config' || $configAction eq 'setconfig') {
							$space2 = shift @configLines;
							$configValue = shift @configLines;
						}
						else {
							$configValue = 'reset';
						}
						$configValue = trim($configValue);

						if ($configAction && $configKey && $configValue) {

							my $reconLine;
							if ($configAction eq 'config' || $configAction eq 'setconfig') {
								$reconLine = $configAction . $space1 . $configKey . $space2 . $configValue;
							}
							elsif ($configAction eq 'resetconfig') {
								$reconLine = "$configAction$space1$configKey";
							}
							else {
								WriteLog('IndexTextFile: warning: $configAction fall-through when selecting $reconLine');
								$reconLine = '';
							}
							WriteLog('IndexTextFile: #config: $reconLine = ' . $reconLine);

							if (ConfigKeyValid($configKey) && $reconLine) {
								WriteLog(
									'ConfigKeyValid() passed! ' .
										$reconLine .
										'; IsAdmin() = ' . IsAdmin($gpgKey) .
										'; isSigned = ' . ($isSigned ? $isSigned : '(no)') .
										'; begins with admin = ' . (substr(lc($configKey), 0, 5) ne 'admin') .
										'; signed_can_config = ' . GetConfig('admin/signed_can_config') .
										'; anyone_can_config = ' . GetConfig('admin/anyone_can_config')
								);

								my $canConfig = 0;
								if (IsAdmin($gpgKey)) {
									$canConfig = 1;
								}
								if (substr(lc($configKey), 0, 5) ne 'admin') {
									if (GetConfig('admin/signed_can_config')) {
										if ($isSigned) {
											$canConfig = 1;
										}
									}
									if (GetConfig('admin/cookied_can_config')) {
										if ($hasCookie) {
											$canConfig = 1;
										}
									}
									if (GetConfig('admin/anyone_can_config')) {
										$canConfig = 1;
									}
								}

								if ($canConfig)	{
									# checks passed, we're going to update/reset a config entry
									DBAddVoteRecord($fileHash, $addedTime, 'config');

									$reconLine = quotemeta($reconLine);

									if ($configAction eq 'resetconfig') {
										DBAddConfigValue($configKey, $configValue, $addedTime, 1, $fileHash);
										$message =~ s/$reconLine/[Successful config reset: $configKey will be reset to default.]/g;
									}
									else {
										DBAddConfigValue($configKey, $configValue, $addedTime, 0, $fileHash);
										$message =~ s/$reconLine/[Successful config change: $configKey = $configValue]/g;
									}

									$detokenedMessage =~ s/$reconLine//g;

									if ($configKey eq 'html/theme') {
										# unlink cache/avatar.plain
									}
								} # if ($canConfig)
								else {
									$message =~ s/$reconLine/[Attempted change to $configKey ignored. Reason: Not operator.]/g;
									$detokenedMessage =~ s/$reconLine//g;
								}
							} # if (ConfigKeyValid($configKey))
							else {
								#$message =~ s/$reconLine/[Attempted change to $configKey ignored. Reason: Config key has no default.]/g;
								#$detokenedMessage =~ s/$reconLine//g;
							}
						}
					} # while
				}
			}
		}

		if (GetConfig('admin/token/addedtime') && $message) {
			# look for addedtime, which adds an added time for an item
			# #token
			# addedtime/759434a7a060aaa5d1c94783f1a80187c4020226/1553658911

			my @addedLines = ($message =~ m/^addedtime\/([0-9a-f]{40})\/([0-9]+)/mg);

			if (@addedLines) {
				WriteLog(". addedtime token found!");
				my $lineCount = @addedLines / 2;

				while (@addedLines) {
					WriteLog("... \@addedLines");
					my $itemHash = shift @addedLines;
					my $itemAddedTime = shift @addedLines;

					WriteLog("... $itemHash, $itemAddedTime");

					my $reconLine = "addedtime/$itemHash/$itemAddedTime";

					WriteLog("... $reconLine");

					my $validated = 0;

					if ($isSigned) {
						WriteLog("... isSigned");
						if (IsServer($gpgKey)) {
							WriteLog("... isServer");

							$validated = 1;

							$message =~ s/$reconLine/[Server discovered $itemHash at $itemAddedTime.]/g;
							$detokenedMessage =~ s/$reconLine//g;

							DBAddItemParent($fileHash, $itemHash);

							DBAddPageTouch('item', $itemHash);

							DBAddVoteRecord($fileHash, $addedTime, 'timestamp');

							DBAddPageTouch('tag', 'timestamp');
						}
					}

					if (!$validated) {
						$message =~ s/$reconLine/[Claim that $itemHash was added at $itemAddedTime.]/g;
						$detokenedMessage =~ s/$reconLine//g;
					}
				}
			}

			$hasParent = 1;
		}

		# look for coins #coin #hascoin
		if (GetConfig('admin/token/coin') && $message) {
			my @coinLines = ($message =~ m/^([0-9A-F]{16}) ([0-9]{10}) (0\.[0-9]+)/mg);

			if (@coinLines) {
				WriteLog(". coin token found!");
				#my $lineCount = @coinLines / 3;
				#
				# 	if ($isSigned) {
				# 		WriteLog("... isSigned");
				# 		if (IsServer($gpgKey)) {
				# 			WriteLog("... isServer");
				while (@coinLines) {
					WriteLog("... \@coinLines");
					my $authorKey = shift @coinLines;
					my $mintedAt = shift @coinLines;
					my $checksum = shift @coinLines;

					WriteLog("... $authorKey, $mintedAt, $checksum");

					my $reconLine = "$authorKey $mintedAt $checksum";

					#$message .= sha512_hex($reconLine);

					my $hash = sha512_hex($reconLine);

					my @acceptedCoinPrefix = split("\n", GetConfig('coin/accepted'));
					push @acceptedCoinPrefix, GetConfig('coin/prefix');

					my $coinAccepted = 0;

					foreach my $coinPrefix (@acceptedCoinPrefix) {
						$coinPrefix = trim($coinPrefix);
						if (!$coinPrefix) {
							next;
						}

						my $coinPrefixLength = length($coinPrefix);
						if (
							substr($hash, 0, $coinPrefixLength) eq $coinPrefix
								&&
							(
								$authorKey eq $gpgKey
									||
								$authorKey eq $hasCookie
							)
						) {
							$message =~ s/$reconLine/[coin: $coinPrefix]/g;

							DBAddVoteRecord($fileHash, $addedTime, 'hascoin');

							DBAddItemAttribute($fileHash, 'coin_timestamp', $mintedAt);

							WriteLog("... $reconLine");

							$detokenedMessage =~ s/$reconLine//g;

							$coinAccepted = 1;

							last;
							#DBAddItemAttribute('
							#$message .= 'coin valid!'; #$reconLine . "\n" . $hash;
						}

					}#foreach my $coinPrefix (@acceptedCoinPrefix) {

					if (!$coinAccepted) {
						$message =~ s/$reconLine/[coin not accepted]/g;
					}

				}
				#
				# 			DBAddVoteRecord($fileHash, $addedTime, 'device');
				#
				# 			DBAddPageTouch('tag', 'device');
				# 		}
				# 	}
			}
		}


		# brc/2:00/AA
		# brc/([2-10]:[00-59])/([0A-Z]{1-2})

		# look for location (latlong) tokens
		# latlong/44.1234567,-44.433435454

		# sha512:

		# addedby:

		# latlong:

		# event:

		# # look for event tokens
		# # event/1551234567/3600
		# if (GetConfig('admin/token/event') && $message) {
		# 	# get any matching token lines
		# 	my @eventLines = ($message =~ m/^event\/([0-9]+)\/([0-9]+)/mg);
		# 	#                                 prefix/time     /duration
		#
		# 	if (@eventLines) {
		# 		my $lineCount = @eventLines / 2;
		#
		# 		WriteLog("... DBAddEventRecord \$lineCount = $lineCount");
		#
		# 		while (@eventLines) {
		# 			my $eventTime = shift @eventLines;
		# 			my $eventDuration = shift @eventLines;
		#
		# 			if ($isSigned) {
		# 				DBAddEventRecord($fileHash, $eventTime, $eventDuration, $gpgKey);
		# 			}
		# 			else {
		# 				DBAddEventRecord($fileHash, $eventTime, $eventDuration);
		# 			}
		#
		# 			my $reconLine = "event/$eventTime/$eventDuration";
		#
		# 			#$message =~ s/$reconLine/[Event: $eventTime for $eventDuration]/g; #todo flesh out message
		#
		# 			my ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime($eventTime);
		# 			$year = $year + 1900;
		# 			$month = $month + 1;
		#
		# 			my $eventDurationText = $eventDuration;
		# 			if ($eventDurationText >= 60) {
		# 				$eventDurationText = $eventDurationText / 60;
		# 				if ($eventDurationText >= 60) {
		# 					$eventDurationText = $eventDurationText / 60;
		# 					if ($eventDurationText >= 24) {
		# 						$eventDurationText = $eventDurationText / 24;
		# 						$eventDurationText = $eventDurationText . " days";
		# 					}
		# 					else {
		# 						$eventDurationText = $eventDurationText . " hours";
		# 					}
		# 				}
		# 				else {
		# 					$eventDurationText = $eventDurationText . " minutes";
		# 				}
		# 			}
		# 			else {
		# 				$eventDurationText = $eventDurationText . " seconds";
		# 			}
		#
		# 			if ($month < 10) {
		# 				$month = '0' . $month;
		# 			}
		# 			if ($day_of_month < 10) {
		# 				$day_of_month = '0' . $day_of_month;
		# 			}
		# 			if ($hours < 10) {
		# 				$hours = '0' . $hours;
		# 			}
		# 			if ($minutes < 10) {
		# 				$minutes = '0' . $minutes;
		# 			}
		# 			if ($seconds < 10) {
		# 				$seconds = '0' . $seconds;
		# 			}
		#
		# 			my $dateText = "$year/$month/$day_of_month $hours:$minutes:$seconds";
		#
		# 			$message =~ s/$reconLine/[Event: $dateText for $eventDurationText]/g;
		#
		# 			$detokenedMessage =~ s/$reconLine//g;
		#
		# 			DBAddVoteRecord($fileHash, $addedTime, 'event');
		#
		# 			DBAddPageTouch('tag', 'event');
		#
		# 			DBAddPageTouch('events');
		# 		}
		# 	}
		# } # event token

		if ($alias) { # if $alias is set, means this is a pubkey
			DBAddVoteRecord($fileHash, $addedTime, 'pubkey');
			# add the "pubkey" tag

			DBAddPageTouch('tag', 'pubkey');
			# add a touch to the pubkey tag page

			DBAddPageTouch('author', $gpgKey);
			# add a touch to the author page

			my $themeName = GetConfig('html/theme');

			UnlinkCache('avatar/' . $themeName . $gpgKey);
			UnlinkCache('avatar.color/' . $themeName . $gpgKey);
			UnlinkCache('pavatar/' . $themeName . $gpgKey);
		} else { # not a pubkey
			$detokenedMessage = trim($detokenedMessage);
			# there may be whitespace remaining after all the tokens have been removed

			if ($detokenedMessage eq '') {
				# add #notext label/tag
				DBAddVoteRecord($fileHash, $addedTime, 'notext');
			} else {
				{ #title
					my $firstEol = index($detokenedMessage, "\n");
					my $titleLengthCutoff = GetConfig('title_length_cutoff'); #default = 80
					if ($firstEol == -1) {
						if (length($detokenedMessage) > 1) {
							$firstEol = length($detokenedMessage);
						}
					}
					# if ($firstEol > $titleLengthCutoff) {
					# 	$firstEol = $titleLengthCutoff;
					# }
					if ($firstEol > 0) {
						my $title = '';
						if ($firstEol <= $titleLengthCutoff) {
							$title = substr($detokenedMessage, 0, $firstEol);
						} else {
							$title = substr($detokenedMessage, 0, $titleLengthCutoff) . '...';
						}

						DBAddItemAttribute($fileHash, 'title', $title, $addedTime);
						DBAddVoteRecord($fileHash, $addedTime, 'hastitle');
					}
				}

				DBAddVoteRecord($fileHash, $addedTime, 'hastext');
				DBAddPageTouch('tag', 'hastext');
			} # has a $detokenedMessage

			if (GetConfig('admin/dev_mode')) {
				# dev mode helps developer by automatically
				# adding messages tagged #todo, #brainstorm, and #bug
				# to their respective files under doc/*.txt

				if (!$hasToken{'changelog'} || index($message, 'Software Updated to Version') == -1) {
					# exclude changelog messages

					#todo instead of hard-coded list use tagset
					foreach my $devTokenName (qw(todo brainstorm bug scratch known meta)) {
						if ($hasToken{$devTokenName}) {
							if ($message) {
								my $todoContents = GetFile("doc/$devTokenName.txt");
								if (!$todoContents || index($todoContents, $message) == -1) {
									AppendFile("doc/$devTokenName.txt", "\n\n===\n\n" . $message);
									last; # one is ennough
								}
							}
						}
					}
				}
			} # admin/dev_mode

			if (!$hasToken{'example'}) { #example token negates most other tokens.
				if ($hasToken{'remove'}) { #remove
					if ($hasParent && scalar(@itemParents)) {
						WriteLog('IndexTextFile: Found #remove token, and item has parents');
						foreach my $itemParent (@itemParents) {
							# find the author of the item in question.
							# this will help us determine whether the request can be fulfilled
							my $parentItemAuthor = DBGetItemAuthor($itemParent) || '';
							WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($gpgKey) . '; $gpgKey = ' . $gpgKey . '; $parentItemAuthor = ' . $parentItemAuthor);

							# at this time only signed requests to remove are honored
							if (
								$gpgKey # is signed
									&&
									(
										IsAdmin($gpgKey)                   # signed by admin
											||                             # OR
										($gpgKey eq $parentItemAuthor) 	   # signed by same as author
									)
							) {
								WriteLog('IndexTextFile: #remove: Found seemingly valid request to remove');

								AppendFile('log/deleted.log', $itemParent);
								DBDeleteItemReferences($itemParent);

								my $htmlFilename = $HTMLDIR . '/' . GetHtmlFilename($itemParent);
								if (-e $htmlFilename) {
									WriteLog('IndexTextFile: #remove: ' . $htmlFilename . ' exists, calling unlink()');
									unlink($htmlFilename);
								}
								else {
									WriteLog('IndexTextFile: #remove: ' . $htmlFilename . ' does NOT exist, very strange');
								}

								my $itemParentPath = GetPathFromHash($itemParent);
								if (-e $itemParentPath) {
									# this only works if organize_files is on and file was put into its path
									# otherwise it will be removed at another time
									WriteLog('IndexTextFile: removing $itemParentPath = ' . $itemParentPath);
									unlink($itemParentPath);
								}

								if (-e $file) {
									#todo unlink the file represented by $voteFileHash, not $file
									if (!GetConfig('admin/logging/record_remove_action')) {
										# this removes the remove call itself
										if (!$detokenedMessage) {
											WriteLog('IndexTextFile: ' . $file . ' exists, calling unlink()');
											unlink($file);
										}
									}
								}
								else {
									WriteLog('IndexTextFile: ' . $file . ' does NOT exist, very strange');
								}

								#todo unlink and refresh, or at least tag as needing refresh, any pages which include deleted item
							} # has permission to remove
							else {
								WriteLog('IndexTextFile: Request to remove file was not found to be valid');
							}
						} # foreach my $itemParent (@itemParents)
					} # has parents
				} # #remove
			} # not #example
		} # not pubkey

		if ($message) {
			# cache the processed message text
			my $messageCacheName = "./cache/" . GetMyCacheVersion() . "/message/$fileHash";
			WriteLog("IndexTextFile: \n====\n" . $messageCacheName . "\n====\n" . $message . "\n====\n" . $txt . "\n====\n");
			PutFile($messageCacheName, $message);
		} else {
			WriteLog('IndexTextFile: I was going to save $messageCacheName, but $message is blank!');
		}

		# below we call DBAddItem, which accepts an author key
		if ($isSigned) {
			# If message is signed, use the signer's key
			DBAddItem($file, $itemName, $gpgKey, $fileHash, 'txt', $verifyError);

			if ($gpgTimestamp) {
				my $gpgTimestampEpoch = `date -d "$gpgTimestamp" +%s`;

				DBAddItemAttribute($fileHash, 'gpg_timestamp', $gpgTimestampEpoch);
			}
		} else {
			if ($hasCookie) {
				# Otherwise, if there is a cookie, use the cookie
				DBAddItem($file, $itemName, $hasCookie, $fileHash, 'txt', $verifyError);
			} else {
				# Otherwise add with an empty author key
				DBAddItem($file, $itemName, '', $fileHash, 'txt', $verifyError);
			}
		}

		DBAddPageTouch('read');
		DBAddPageTouch('item', $fileHash);
		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
			$isAdmin = 1;
			DBAddVoteRecord($fileHash, $addedTime, 'admin');
			DBAddPageTouch('tag', 'admin');
		}
		if ($isSigned) {
			DBAddPageTouch('author', $gpgKey);
			DBAddPageTouch('scores');
		} elsif ($hasCookie) {
			DBAddPageTouch('author', $hasCookie);
			DBAddPageTouch('scores');
		}
		DBAddPageTouch('stats');
		DBAddPageTouch('events');
		DBAddPageTouch('rss');
		DBAddPageTouch('index');
		DBAddPageTouch('flush');
	}
} # IndexTextFile

sub AddToChainLog { # $fileHash ; add line to log/chain.log
	my $fileHash = shift;
	chomp $fileHash;

	my $logFilePath = "$HTMLDIR/chain.log";

	my $findExistingCommand = "grep ^$fileHash $logFilePath";
	my $findExistingResult = `$findExistingCommand`;

	WriteLog("AddToChainLog: $findExistingCommand returned $findExistingResult");

	if ($findExistingResult) { #todo remove fork
		# hash already exists in chain, return
		return;
	}

	my $newAddedTime = GetTime();
	my $logLine = $fileHash . '|' . $newAddedTime;

	my $lastLineAddedLog = `tail -n 1 $logFilePath`; #todo remove fork
	if (!$lastLineAddedLog) {
		$lastLineAddedLog = '';
	}
	chomp $lastLineAddedLog;
	my $lastAndNewTogether = $lastLineAddedLog . '|' . $logLine;
	my $checksum = md5_hex($lastAndNewTogether);

	WriteLog('AddToChainLog: $lastLineAddedLog = ' . $lastLineAddedLog);
	WriteLog('AddToChainLog: $lastAndNewTogether = ' . $lastAndNewTogether);
	WriteLog('AddToChainLog: md5(' . $lastAndNewTogether . ') = $checksum  = ' . $checksum);

	my $newLineAddedLog = $logLine . '|' . $checksum;

	WriteLog('AddToChainLog: $newLineAddedLog = ' . $newLineAddedLog);

	if (!$lastLineAddedLog || ($newLineAddedLog ne $lastLineAddedLog)) {
		#todo replace hard-coded path with $LOGPATH
		AppendFile($logFilePath, $newLineAddedLog);
	}
}

sub IndexImageFile { # indexes one image file into database, $file = path to file
	# Reads a given $file, gets its attributes, puts it into the index database
	# If ($file eq 'flush), flushes any queued queries
	# Also sets appropriate page_touch entries

	my $file = shift;
	chomp($file);

	WriteLog("IndexImageFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexTextFile(flush)");

		DBAddItemAttribute('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddPageTouch('flush');

		return;
	}

	# # admin/organize_files
	# # renames files to their hashes
	# if (GetConfig('admin/organize_files')) {
	# 	# don't touch server.key.txt or $TXTDIR directory or directories in general
	# 	if ($file ne $TXTDIR.'/server.key.txt' && $file ne $TXTDIR && !-d $file) {
	# #todo there's a bug here because of relative vs absolute paths, i think
	# 		WriteLog('IndexTextFile: admin/organize_files is set, do we need to organize?');
	#
	# 		# Figure out what the file's path should be
	# 		my $fileHashPath = GetFileHashPath($file);
	#
	# 		if ($fileHashPath) {
	# 			# Does it match?
	# 			if ($file eq $fileHashPath) {
	# 				# No action needed
	# 				WriteLog('IndexTextFile: hash path matches, no action needed');
	# 			}
	# 			# It doesn't match, fix it
	# 			elsif ($file ne $fileHashPath) {
	# 				WriteLog('IndexTextFile: hash path does not match, organize');
	# 				WriteLog('Before: ' . $file);
	# 				WriteLog('After: ' . $fileHashPath);
	#
	# 				if (-e $fileHashPath) {
	# 					WriteLog("Warning: $fileHashPath already exists!");
	# 				}
	#
	# 				rename ($file, $fileHashPath);
	#
	# 				# if new file exists
	# 				if (-e $fileHashPath) {
	# 					$file = $fileHashPath; #don't see why not... is it a problem for the calling function?
	# 				} else {
	# 					WriteLog("Very strange... \$fileHashPath doesn't exist? $fileHashPath");
	# 				}
	# 			}
	# 		}
	# 	}
	# 	else {
	# 		WriteLog('IndexTextFile: organizing not needed');
	# 	}
	# }

	my $addedTime;          # time added, epoch format
	my $addedTimeIsNew = 0; # set to 1 if $addedTime is missing and we just created a new entry
	my $fileHash;            # git's hash of file blob, used as identifier


	if (
		-e $file &&
			(
				substr(lc($file), length($file) -4, 4) eq ".jpg" ||
					substr(lc($file), length($file) -4, 4) eq ".gif" ||
					substr(lc($file), length($file) -4, 4) eq ".png" ||
					substr(lc($file), length($file) -4, 4) eq ".bmp" ||
					substr(lc($file), length($file) -4, 4) eq ".svg" ||
					substr(lc($file), length($file) -5, 5) eq ".jfif" ||
					substr(lc($file), length($file) -5, 5) eq ".webp"
				#todo config/admin/upload/allow_files
			)
	) {
		my $fileHash = GetFileHash($file);
		WriteLog('IndexImageFile: $fileHash = ' . ($fileHash ? $fileHash : '--'));

		$addedTime = DBGetAddedTime($fileHash);
		# get the file's added time.

		# debug output
		WriteLog('IndexImageFile: $file = ' . ($file?$file:'false') . '; $fileHash = ' . ($fileHash?$fileHash:'false') . '; $addedTime = ' . ($addedTime?$addedTime:'false'));

		# if the file is present in deleted.log, get rid of it and its page, return
		if (IsFileDeleted($file, $fileHash)) {
			# write to log
			WriteLog("... IsFileDeleted() returned true, returning");

			return;
		}

		if (!$addedTime) {
			# This file was not added through access.pl, and has
			# not been indexed before, so it should get an added_time
			# record. This is what we'll do here. It will be picked
			# up and put into the database on the next cycle
			# unless we add provisions for that here #todo

			WriteLog("... No added time found for " . $fileHash . " setting it to now.");

			# current time
			my $newAddedTime = GetTime();
			$addedTime = $newAddedTime; #todo is this right? confirm

			# if (GetConfig('admin/logging/write_added_log')) {
			# 	# add new line to added.log
			# 	my $logLine = $fileHash . '|' . $newAddedTime;
			# 	AppendFile('./log/added.log', $logLine);
			# }

			if (GetConfig('admin/logging/write_chain_log')) {
				AddToChainLog($fileHash);
			}

			# store it in index, since that's what we're doing here
			DBAddItemAttribute($fileHash, 'chain_timestamp', $newAddedTime);

			$addedTimeIsNew = 1;
		}

		DBAddPageTouch('rss');

		my $itemName = TrimPath($file);

		{
			# # make 1024x1024 thumbnail
			# if (!-e "$HTMLDIR/thumb/thumb_1024_$fileHash.gif") {
			# 	my $convertCommand = "convert \"$file\" -thumbnail 1024x1024 -strip $HTMLDIR/thumb/thumb_1024_$fileHash.gif";
			# 	WriteLog('IndexImageFile: ' . $convertCommand);
			#
			# 	my $convertCommandResult = `$convertCommand`;
			# 	WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			# }

			my $fileShellEscaped = EscapeShellChars($file); #todo this is still a hack, should rename file if it has shell chars

			# make 420x420 thumbnail
			if (!-e "$HTMLDIR/thumb/thumb_800_$fileHash.gif") {
			# if (!-e "$HTMLDIR/thumb/thumb_420_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 420x420 -strip $HTMLDIR/thumb/thumb_800_$fileHash.gif";
				# my $convertCommand = "convert \"$file\" -thumbnail 420x420 -strip $HTMLDIR/thumb/thumb_420_$fileHash.gif";
				WriteLog('IndexImageFile: ' . $convertCommand);

				my $convertCommandResult = `$convertCommand`;
				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			}
			# make 42x42 thumbnail
			if (!-e "$HTMLDIR/thumb/thumb_42_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 42x42 -strip $HTMLDIR/thumb/thumb_42_$fileHash.gif";
				WriteLog('IndexImageFile: ' . $convertCommand);

				my $convertCommandResult = `$convertCommand`;
				WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			}

			# # make 48x48 thumbnail
			# if (!-e "$HTMLDIR/thumb/thumb_48_$fileHash.gif") {
			# 	my $convertCommand = "convert \"$file\" -thumbnail 48x48 -strip $HTMLDIR/thumb/thumb_48_$fileHash.gif";
			# 	WriteLog('IndexImageFile: ' . $convertCommand);
			#
			# 	my $convertCommandResult = `$convertCommand`;
			# 	WriteLog('IndexImageFile: convert result: ' . $convertCommandResult);
			# }
		}

		DBAddItem($file, $itemName, '', $fileHash, 'image', 0);

		DBAddItem('flush');

		DBAddItemAttribute($fileHash, 'title', $itemName, $addedTime);

		DBAddVoteRecord($fileHash, $addedTime, 'image');
		# add image tag

		DBAddPageTouch('read');

		DBAddPageTouch('tag', 'image');

		DBAddPageTouch('item', $fileHash);

		DBAddPageTouch('stats');

		DBAddPageTouch('rss');

		DBAddPageTouch('index');

		DBAddPageTouch('flush');
	}
} #IndexImageFile

sub WriteIndexedConfig { # writes config indexed in database into config/
	my @indexedConfig = DBGetLatestConfig();

	foreach my $configLine(@indexedConfig) {
		my $configKey = $configLine->{'key'};
		my $configValue = $configLine->{'value'};

		chomp $configValue;
		$configValue = trim($configValue);

		if (IsSha1($configValue)) {
			WriteLog("It's a hash, try to look it up...");

			if (-e 'cache/' . GetMyCacheVersion() . "/message/$configValue") {
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

	GetConfig('unmemo');
}

sub MakeIndex { # indexes all available text files, and outputs any config found
	WriteLog( "MakeIndex()...\n");

	my @filesToInclude = split("\n", `find $TXTDIR -name \\\*.txt`);

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

	if (GetConfig('admin/image/enable')) {
		my @imageFiles = split("\n", `find $HTMLDIR/image`);

		my $imageFilesCount = scalar(@imageFiles);
		my $currentImageFile = 0;

		WriteLog('MakeIndex: $imageFilesCount = ' . $imageFilesCount);

		foreach my $imageFile (@imageFiles) {
			$currentImageFile++;

			my $percentImageFiles = $currentImageFile / $imageFilesCount * 100;

			WriteMessage("*** MakeIndex: $currentImageFile/$imageFilesCount ($percentImageFiles %) $imageFile");

			IndexImageFile($imageFile);
		}

		IndexImageFile('flush');
	} # admin/image/enable
}

sub IndexFile {
	# if textfile indextextfile
	# if imagefile indeximagefile
	# and so on
}

my $arg1 = shift;
if ($arg1) {
	if ($arg1 eq '--all') {
		print "index.pl: --all\n";

		MakeIndex();

	}

	if ($arg1 eq '--chain') {
		print "index.pl: --chain\n";

		MakeChainIndex();
	}

	if (-e $arg1) {
		IndexTextFile($arg1);
		IndexTextFile('flush');

		#todo IndexFile instead
	}
}


#MakeTagIndex();
1;
