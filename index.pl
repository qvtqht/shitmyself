#!/usr/bin/perl

use strict;
use warnings;
use utf8;
#use POSIX qw(strftime);
use Cwd qw(cwd);
use Digest::SHA qw(sha512_hex);

#use Encode qw( encode_utf8 );

my $SCRIPTDIR = cwd(); # where the perl scripts live
my $HTMLDIR = $SCRIPTDIR . '/html'; # web root
my $TXTDIR = $HTMLDIR . '/txt'; # text files root

require './utils.pl';
require './sqlite.pl';

WriteLog( "Using $SCRIPTDIR as install root...\n");

sub MakeChainIndex { # $import = 1; reads from log/chain.log and puts it into item_attribute table
	# note: this is kind of a hack, and non-importing validation should just be separate own sub
	my $import = shift;
	if (!defined($import)) {
		$import = 1;
	} else {
		chomp $import;
		$import = ($import ? 1 : 0);
	}
	WriteMessage("MakeChainIndex($import)");

	if (GetConfig('admin/read_chain_log')) {
		WriteLog('MakeChainIndex: admin/read_chain_log was TRUE');
		my $chainLog = GetFile('html/chain.log');

		if (defined($chainLog) && $chainLog) {
			WriteLog('MakeChainIndex: $chainLog was defined');
			my @addedRecord = split("\n", $chainLog);

			my $previousLine = '';
			my $sequenceNumber = 0;

			foreach my $currentLine (@addedRecord) {
				WriteLog("MakeChainIndex: $currentLine");
				WriteMessage("Verifying Chain: $sequenceNumber");

				my ($fileHash, $addedTime, $proofHash) = split('\|', $currentLine);
				my $expectedHash = md5_hex($previousLine . '|' . $fileHash . '|' . $addedTime);

				if ($expectedHash ne $proofHash) {
					WriteLog('MakeChainIndex: warning: proof hash mismatch. abandoning chain import');

					# save the current chain.log and create new one
					# new chain.log should go up to the point of the break
					my $curTime = GetTime();
					my $moveChain = `mv html/chain.log html/chain.log.$curTime ; head -n $sequenceNumber html/chain.log.$curTime > html/chain_new.log; mv html/chain_new.log html/chain.log`;

					# make a record of what just happened
					my $moveChainMessage = 'Chain break detected. Timestamps for items may reset. #meta #warning ' . $curTime;
					PutFile('html/txt/chain_break_' . $curTime . '.txt');

					if ($import) {
						MakeChainIndex($import); # recurse
					}

					WriteLog('MakeChainIndex: return 0');
					return 0;
				}

				DBAddItemAttribute($fileHash, 'chain_timestamp', $addedTime);
				DBAddItemAttribute($fileHash, 'chain_sequence', $sequenceNumber);
				WriteLog('MakeChainIndex: $sequenceNumber = ' . $sequenceNumber);

				$sequenceNumber = $sequenceNumber + 1;
				$previousLine = $currentLine;
			} # foreach $currentLine (@addedRecord)
			DBAddItemAttribute('flush');
			return 1;
		} # $chainLog
		else {
			WriteLog('MakeChainIndex: warning: $chainLog was NOT defined');
			return 0;
		}
	} # GetConfig('admin/read_chain_log')
	else {
		WriteLog('MakeChainIndex: admin/read_chain_log was FALSE');
		return 0;
	}

	WriteLog('MakeChainIndex: warning: unreachable was reached');
	return 0;
} # MakeChainIndex()

sub IndexTextFile { # $file | 'flush' ; indexes one text file into database
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush'), flushes any queued queries
# Also sets appropriate task entries
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

		return 1;
	}

	WriteLog("IndexTextFile($file)");

	# admin/organize_files
	# renames files to their hashes

	if (GetConfig('admin/organize_files')) {
		$file = OrganizeFile($file);
	}

	my $fileHash; # hash of file contents
	$fileHash = GetFileHash($file);                # hash

	if (GetCache('indexed/'.$fileHash)) {
		return $fileHash;
	}

	# file's attributes
	my $txt = "";           # original text inside file
	my $message = "";       # outputted text after parsing
	#my $fileMeta = "";
	my $isSigned = 0;       # was this item signed?
	my $hasCookie = 0;

	my $addedTime;          # time added, epoch format
	my $isAdmin = 0;        # was this posted by admin?

	# author's attributes
	my $gpgKey;             # author's gpg key, hexadecimal 16 chars, uppercase
	my $gpgKeyLong;			# author's gpg key, hexadecimal 40 chars, uppercase
	my $alias;              # author's alias, as reported by gpg's parsing of their public key

	my $verifyError = 0;    # was there an error verifying the file with gpg?

	my $hasParent = 0;		# has 1 or more parent items?

	my $gpgTimestamp = 0;

	my %hasToken; # tokens found in message for secondary parsing
	my @tokensFound; # array of hashes, tokens found with arguments
	my @itemParents;

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		my %gpgResults = GpgParse($file);

		# see what gpg says about the file.
		# if there is no gpg content, the attributes are still populated as possible
		$txt = $gpgResults{'text'};          # contents of the text file
		$message = $gpgResults{'message'};   # message which will be displayed once tokens are processed
		$isSigned = $gpgResults{'isSigned'}; # is it signed with pgp?
		$gpgKey = $gpgResults{'key'};        # if it is signed, fingerprint of signer
		$gpgTimestamp = $gpgResults{'signTimestamp'} || '';        # signature timestamp
		$gpgKeyLong = $gpgResults{'key_long'};

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

		my %authorHasTag;

		my $detokenedMessage = $message;
		# this is used to store $message minus any tokens found
		# in the end, we will see if it is empty, and set flags accordingly

		$addedTime = DBGetAddedTime($fileHash);
		# get the file's added time.

		if (!$file || !$fileHash) {
			WriteLog('IndexTextFile: warning: $file or $fileHash missing; returning');
			return 0;
		}

		# debug output
		WriteLog('IndexTextFile: $file = ' . $file . ', $fileHash = ' . $fileHash);

		# if the file is present in deleted.log, get rid of it and its page, return
		if (IsFileDeleted($file, $fileHash)) {
			WriteLog('IndexTextFile: IsFileDeleted() returned true, returning');
			return 0;
		}

		# debug output
		WriteLog('IndexTextFile: $fileHash = ' . $fileHash);
		if ($addedTime) {
			WriteLog('IndexTextFile: $addedTime = ' . $addedTime);
		} else {
			WriteLog('IndexTextFile: $addedTime is not set');

			if (GetConfig('admin/logging/write_chain_log')) {
				$addedTime = AddToChainLog($fileHash);
			}
		}

		# admin_imprint
		if (
			$gpgKey &&
			$alias &&
			!GetRootAdminKey() &&
			GetConfig('admin/admin_imprint') &&
			$alias eq 'Operator'
		) {
			# if there is no admin set, and config/admin/admin_imprint is true
			# and if this item is a public key
			# go ahead and make this user admin
			# and announce it via a new .txt file
			PutFile('./admin.key', $txt);
			my $newAdminMessage = $TXTDIR . '/' . GetTime() . '_newadmin.txt';
			PutFile(
				$newAdminMessage,
				"Server Message:\n\n".
				"There was no admin, and $gpgKey came passing through, so I made them admin.\n\n".
				"(This happens when config/admin/admin_imprint is true and there is no admin set.)\n\n#meta #notice\n\n".
				"Timestamp: " . GetTime()
			);
			ServerSign($newAdminMessage);

			RemoveHtmlFile('stats.html');
			RemoveHtmlFile('stats-footer.html');
			ExpireAvatarCache('*'); # expire avatar cache

		} # admin_imprint

		if ($isSigned && $gpgKey && IsAdmin($gpgKey)) {
			# it was posted by admin
			$isAdmin = 1;
			$authorHasTag{'admin'} = 1;

			if (
				!GetConfig('admin/latest_admin_action') ||
				GetConfig('admin/latest_admin_action') < $addedTime
			) {
				# reset counter for latest admin action
				PutConfig('admin/latest_admin_action', $addedTime);
			}

			#DBAddVoteRecord($fileHash, $addedTime, 'admin');
		} # $isSigned && $gpgKey && IsAdmin($gpgKey)

		if ($isSigned && $gpgKey) {
			# it was signed and there's a gpg key
			DBAddAuthor($gpgKey);
			DBAddPageTouch('author', $gpgKey);

			if ( ! ($gpgKey =~ m/\s/)) {
				# no spaces in gpg key; \s is whitespace
				ExpireAvatarCache($gpgKey); # expire avatar cache
			} else {
				WriteLog('IndexTextFile: warning: $gpgKey contains space(s)');
			}
		}

		if ($alias) {
			# pubkey
			DBAddKeyAlias($gpgKey, $alias, $fileHash);
			DBAddItemAttribute($fileHash, 'gpg_alias', $alias);
			DBAddItemAttribute($fileHash, 'gpg_fingerprint', $gpgKey);
			ExpireAvatarCache($gpgKey); # expire alias cache
		}

		my $itemName = TrimPath($file);

		{
			###################################################
			# TOKEN FIRST PASS PARSING BEGINS HERE
			my @tokenDefs = (
				{ # cookie of user who posted the message
					'token'   => 'cookie',
					'mask'    => '^(cookie)(\W+)([0-9A-F]{16})',
					'mask_params'    => 'mgi',
					'message' => '[Cookie]'
				},
				{ # allows cookied user to set own name
					'token'   => 'my_name_is',
					'mask'    => '^(my name is)(\W+)([A-Za-z0-9\'_\., ]+)\r?$',
					'mask_params'    => 'mgi',
					'message' => '[MyNameIs]'
				},
				{ # parent of item (to which item is replying)
					'token'   => 'parent',
					'mask'    => '^(\>\>)(\W?)([0-9a-f]{40})',
					'mask_params' => 'mg',
					'message' => '[Parent]'
				},
				{ # title of item, either self or parent. used for display when title is needed #title title:
					'token'   => 'title',
					'mask'    => '^(title)(\W)(.+)$',
					'mask_params'    => 'mg',
					'apply_to_parent' => 1,
					'message' => '[Title]'
				},
				{ # used for image alt tags #todo
					'token'   => 'alt',
					'mask'    => '^(alt)(\W+)(.+)$',
					'mask_params'    => 'mg',
					'apply_to_parent' => 1,
					'message' => '[Alt]'
				},
				{ # hash of line from access.log where item came from (for parent item)
					'token'   => 'access_log_hash',
					'mask'    => '^(AccessLogHash)(\W+)(.+)$',
					'mask_params'    => 'mgi',
					'apply_to_parent' => 1,
					'message' => '[AccessLogHash]'
				},
				{ # solved puzzle (user id, timestamp, random number between 0 and 1
					# together they must hash to the prefix specified in config/puzzle/accept
					# the default prefix (also accepted) is specified in config/puzzle/prefix
					'token' => 'puzzle',
					'mask' => '^()()([0-9A-F]{16} [0-9]{10} 0\.[0-9]+)',
					'mask_params' => 'mg',
					'message' => '[Puzzle]'
				},
				{ # anything beginning with http and up to next space character (or eof)
					'token' => 'url',
					'mask' => '()()(http[\S]+)',
					'mask_params' => 'mg',
					'message' => '[URL]',
					'apply_to_parent' => 0
				},
				{ # hashtags, currently restricted to latin alphanumeric and underscore
					'token' => 'hashtag',
					'mask'  => '(\#)()([a-zA-Z0-9_]{1,32})',
					'mask_params' => 'mgi',
					'message' => '[HashTag]',
					'apply_to_parent' => 1
				},
				{ # verify token, for third-party identification
					# example: verify http://www.example.com/user/JohnSmith/
					# must be child of pubkey item
					'token' => 'verify',
					'mask'  => '^(verify)(\W)(.+)$',
					'mask_params' => 'mgi',
					'message' => '[Verify]',
					'apply_to_parent' => 1
				},
				{ # config token for setting configuration
					# config/admin/anyone_can_config = allow anyone to config (for open-access boards)
					# config/admin/signed_can_config = allow only signed users to config
					# config/admin/cookied_can_config = allow any user (including cookies) to config
					# otherwise, only admin user can config
					# also, anything under config/admin/ is still restricted to admin user only
					# admin user must have a pubkey
					'token' => 'config',
					'mask'  => '(config)(\W)(.+)$',
					'mask_params' => 'mgi',
					'message' => '[Config]',
					'apply_to_parent' => 1
				}
			);

			# \w word
			# \W NOT word
			# \s whitespace
			# \S NOT whitespace
			#
			# REGEX cheatsheet
			# ================
			# /s = single-line (changes behavior of . metacharacter to match newlines)
			# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
			# /g = global (all instances)
			# /i = case-insensitive
			# /e = eval

			# parses standard issue tokens, definitions above
			# stores into @tokensFound

			my $limitTokensPerFile = int(GetConfig('admin/index/limit_tokens_per_file'));
			if (!$limitTokensPerFile) {
				$limitTokensPerFile = 100;
			}

			#todo sanity check on $limitTokensPerFile;

			foreach my $tokenDefRef (@tokenDefs) {
				my %tokenDef = %$tokenDefRef;
				my $tokenName = $tokenDef{'token'};
				my $tokenMask = $tokenDef{'mask'};
				my $tokenMaskParams = $tokenDef{'mask_params'};
				my $tokenMessage = $tokenDef{'message'};

				WriteLog('IndexTextFile: $tokenMask = ' . $tokenMask);

				if (GetConfig("admin/token/$tokenName") && $detokenedMessage) {
					# token is enabled, and there is still something left to parse
					
					my @tokenLines;

					if ($tokenMaskParams eq 'mg') {
						# probably an easier way to do this, but i haven't found it yet
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/mg);
					} elsif ($tokenMaskParams eq 'mgi') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/mgi);
					} elsif ($tokenMaskParams eq 'gi') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/gi);
					} elsif ($tokenMaskParams eq 'g') {
						@tokenLines = ($detokenedMessage =~ m/$tokenMask/g);
					} else {
						WriteLog('IndexTextFile: warning: sanity check failed: $tokenMaskParams unaccounted for');
					}

					WriteLog('IndexTextFile: found ' . scalar(@tokenLines));

					if (scalar(@tokensFound) + scalar(@tokenLines) > $limitTokensPerFile) {
						WriteLog('IndexTextFile: warning: found too many tokens, skipping');
						return 0;
					} else {
						WriteLog('IndexTextFile: sanity check passed, token count: ' . scalar(@tokensFound) + scalar(@tokenLines));
					}

					while (@tokenLines) {
						my $foundTokenName = shift @tokenLines;
						my $foundTokenSpacer = shift @tokenLines;
						my $foundTokenParam = shift @tokenLines;

						$foundTokenParam = trim($foundTokenParam);

						my $reconLine = $foundTokenName . $foundTokenSpacer . $foundTokenParam;
						WriteLog('IndexTextFile: token/' . $tokenName . ' : ' . $reconLine);

						my %newTokenFound;
						$newTokenFound{'token'} = $tokenName;
						$newTokenFound{'param'} = $foundTokenParam;
						$newTokenFound{'recon'} = $reconLine;
						$newTokenFound{'message'} = $tokenMessage;
						push(@tokensFound, \%newTokenFound);

						if ($tokenName eq 'hashtag') {
							$hasToken{$foundTokenParam} = 1;
						}
					}
				} # GetConfig("admin/token/$tokenName") && $detokenedMessage
			} # @tokenDefs

			# TOKEN FIRST PASS PARSING ENDS HERE
			# @tokensFound now has all the found tokens
			WriteLog('IndexTextFile: scalar(@tokensFound) = ' . scalar(@tokensFound));
			###################################################
		}

		if ($alias) { # if $alias is set, means this is a pubkey
			DBAddVoteRecord($fileHash, $addedTime, 'pubkey'); # add the "pubkey" tag
			DBAddPageTouch('tag', 'pubkey'); # add a touch to the pubkey tag page
			DBAddPageTouch('author', $gpgKey);	# add a touch to the author page

			ExpireAvatarCache($gpgKey);
		} else { # not a pubkey
			$detokenedMessage = trim($detokenedMessage);
			# there may be whitespace remaining after all the tokens have been removed


			if (GetConfig('admin/dev_mode')) {
				# dev mode helps developer by automatically
				# adding messages tagged #todo, #brainstorm, and #bug
				# to their respective files under doc/*.txt

				if ($hasToken{'meta'}) {
					# only if already tagged #meta

					#todo this can go under tagset/meta ?????
					my @arrayOfMetaTokens = qw(todo brainstorm bug scratch known notes);

					#todo instead of hard-coded list use tagset
					#todo apply to parents if parents
					foreach my $devTokenName (@arrayOfMetaTokens) {
						if ($hasToken{$devTokenName}) {
							if ($message) {
								my $docContents = GetFile("doc/$devTokenName.txt");
								if (!$docContents || index($docContents, $message) == -1) {
									AppendFile("doc/$devTokenName.txt", "\n\n===\n\n" . $message);
									last; # one is ennough
								}
							}
						}
					}
				}
			} # admin/dev_mode

			# first pass, look for cookie, parent, auth
			{
				foreach my $tokenFoundRef (@tokensFound) {
					my %tokenFound = %$tokenFoundRef;
					if ($tokenFound{'token'} && $tokenFound{'param'}) {
						if ($tokenFound{'token'} eq 'cookie') {
							if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
								WriteLog('IndexTextFile: DBAddAuthor(' . $tokenFound{'param'} . ')');
								DBAddAuthor($tokenFound{'param'});
								$hasCookie = $tokenFound{'param'};

								$message = str_replace($tokenFound{'recon'}, $tokenFound{'message'}, $message);
								$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
							} else {
								WriteLog('IndexTextFile: warning: cookie: sanity check failed');
							}
						} # cookie

						if ($tokenFound{'token'} eq 'parent') {
							if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
								WriteLog('IndexTextFile: DBAddItemParent(' . $fileHash . ',' . $tokenFound{'param'} . ')');
								DBAddItemParent($fileHash, $tokenFound{'param'});
								push(@itemParents, $tokenFound{'param'});

								# $message = str_replace($tokenFound{'recon'}, $tokenFound{'message'}, $message);
								$message = str_replace($tokenFound{'recon'}, '>>' . $tokenFound{'param'}, $message); #hacky
								$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
							} else {
								WriteLog('IndexTextFile: warning: parent: sanity check failed');
							}
						} # parent
					} # parametrized token
				}
			}

			if (!$hasToken{'example'} || !$hasToken{'notice'}) { #example token negates most other tokens.
				# second pass, after parents and user established

				foreach my $tokenFoundRef (@tokensFound) {
					my %tokenFound = %$tokenFoundRef;
					if ($tokenFound{'token'} && $tokenFound{'param'}) {
						WriteLog('IndexTextFile: $tokenFound{token} = ' . $tokenFound{'token'});
						if (
							$tokenFound{'token'} eq 'title' ||
							$tokenFound{'token'} eq 'alt' ||
							$tokenFound{'token'} eq 'access_log_hash' ||
							$tokenFound{'token'} eq 'url'
						) {
							# these tokens are applied to:
							# 	if item has parent, then to the parent
							# 		otherwise: to self
							WriteLog('IndexTextFile: token_found: ' . $tokenFound{'recon'});

							if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
								if (@itemParents) {
									foreach my $itemParent (@itemParents) {
										DBAddItemAttribute($itemParent, $tokenFound{'token'}, $tokenFound{'param'}, $addedTime, $fileHash);
									}
								} else {
									DBAddItemAttribute($fileHash, $tokenFound{'token'}, $tokenFound{'param'}, $addedTime, $fileHash);
								}
							} else {
								WriteLog('IndexTextFile: warning: ' . $tokenFound{'token'} . ' (generic): sanity check failed');
							}
						} # title, access_log_hash, url, alt

						if ($tokenFound{'token'} eq 'config') {
							if (
								IsAdmin($gpgKey) || #admin can always config
								GetConfig('admin/anyone_can_config') || # anyone can config
								(GetConfig('admin/signed_can_config') && $isSigned) || # signed can config
								(GetConfig('admin/cookied_can_config') && $hasCookie) # cookied can config
							) {
								my ($configKey, $configSpacer, $configValue) = ($tokenFound{'param'} =~ m/(.+)(\W)(.+)/);

								WriteLog('IndexTextFile: $configKey = ' . (defined($configKey) ? $configKey : '(undefined)'));
								WriteLog('IndexTextFile: $configSpacer = ' . (defined($configSpacer) ? $configSpacer : '(undefined)'));
								WriteLog('IndexTextFile: $configValue = ' . (defined($configValue) ? $configValue : '(undefined)'));

								if (!defined($configKey) || !$configKey || !defined($configValue)) {
									WriteLog('IndexTextFile: warning: $configKey or $configValue missing from $tokenFound token');
								} else {
									my $configKeyActual = $configKey;
									if ($configKey && defined($configValue) && $configValue ne '') {
										# alias 'theme' to 'html/theme'
										# $configKeyActual = $configKey;
										if ($configKey eq 'theme') {
											# alias theme to html/theme
											$configKeyActual = 'html/theme';
										}
										#todo merge html/clock and html/clock_format
										# if ($configKey eq 'clock') {
										# 	# alias theme to html/theme
										# 	$configKeyActual = 'clock_format';
										# }
										$configValue = trim($configValue);
									}

									if (IsAdmin($gpgKey) || ConfigKeyValid($configKeyActual)) {
										# admins can write to any config
										# non-admins can only write to existing config keys (and not under admin/)

										# #todo create a whitelist of safe keys non-admins can change

										DBAddConfigValue($configKeyActual, $configValue, $addedTime, 0, $fileHash);
										$message = str_replace($tokenFound{'recon'}, "[Config: $configKeyActual = $configValue]", $message);
										$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									} else {
										# token tried to pass unacceptable config key
										$message = str_replace($tokenFound{'recon'}, "[Not Accepted: $configKeyActual]", $message);
										$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									}
								}
							}
						}

						if ($tokenFound{'token'} eq 'puzzle') { # puzzle
							my ($authorKey, $mintedAt, $checksum) = split(' ', $tokenFound{'param'});
							WriteLog("IndexTextFile: token: puzzle: $authorKey, $mintedAt, $checksum");

							#todo must match message author key

							my $hash = sha512_hex($tokenFound{'recon'});
							my $configPuzzleAccept = GetConfig('puzzle/accept');
							if (!$configPuzzleAccept) {
								$configPuzzleAccept = '';
							}
							my @acceptPuzzlePrefix = split("\n", $configPuzzleAccept);
							push @acceptPuzzlePrefix, GetConfig('puzzle/prefix');
							my $puzzleAccepted = 0;

							foreach my $puzzlePrefix (@acceptPuzzlePrefix) {
								$puzzlePrefix = trim($puzzlePrefix);
								if (!$puzzlePrefix) {
									next;
								}

								my $puzzlePrefixLength = length($puzzlePrefix);
								if (
									(substr($hash, 0, $puzzlePrefixLength) eq $puzzlePrefix) && # hash matches
									($authorKey eq $gpgKey || $authorKey eq $hasCookie) # key matches cookie or fingerprint
								) {
									$message =~ s/$tokenFound{'recon'}/[Solved puzzle with this prefix: $puzzlePrefix]/g;
									DBAddItemAttribute($fileHash, 'puzzle_timestamp', $mintedAt);
									DBAddVoteRecord($fileHash, $mintedAt, 'puzzle');
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									$puzzleAccepted = 1;

									last;
									#DBAddItemAttribute('
									#$message .= 'puzzle valid!'; #$reconLine . "\n" . $hash;
								}
							}#foreach my $puzzlePrefix (@acceptPuzzlePrefix) {
						} # puzzle

						if ($tokenFound{'token'} eq 'my_name_is') { # my_name_is
							if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
								if ($hasCookie) {
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									my $nameGiven = $tokenFound{'param'};
									$message =~ s/$tokenFound{'recon'}/[my name is: $nameGiven]/g;

									DBAddKeyAlias($hasCookie, $tokenFound{'param'}, $fileHash);
									DBAddKeyAlias('flush');
								}
							} else {
								WriteLog('IndexTextFile: warning: my_name_is: sanity check failed');
							}
						} # my_name_is

						if ($tokenFound{'token'} eq 'hashtag') { #hashtag
							if ($tokenFound{'param'} eq 'remove') { #remove
								if (scalar(@itemParents)) {
									WriteLog('IndexTextFile: Found #remove token, and item has parents');
									foreach my $itemParent (@itemParents) {
										# find the author of the item in question.
										# this will help us determine whether the request can be fulfilled
										my $parentItemAuthor = DBGetItemAuthor($itemParent) || '';
										#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($gpgKey) . '; $gpgKey = ' . $gpgKey . '; $parentItemAuthor = ' . $parentItemAuthor);
										WriteLog('IndexTextFile: #remove: $gpgKey = ' . $gpgKey);
										#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($gpgKey));
										WriteLog('IndexTextFile: #remove: $parentItemAuthor = ' . $parentItemAuthor);

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
							elsif (
								$tokenFound{'param'} eq 'admin' ||
								$tokenFound{'param'} eq 'approve'
							) { # #admin #approve tokens which need permissions
								my $hashTag = $tokenFound{'param'};
								if (scalar(@itemParents)) {
									WriteLog('IndexTextFile: Found permissioned token ' . $tokenFound{'param'} . ', and item has parents');
									foreach my $itemParent (@itemParents) {
										# find the author of this item
										# this will help us determine whether the request can be fulfilled

										if (
											$gpgKey # is signed
											&&
											IsAdmin($gpgKey)                   # signed by admin
										) {
											WriteLog('IndexTextFile: #admin: Found seemingly valid request');
											DBAddVoteRecord($itemParent, $addedTime, $hashTag, $gpgKey, $fileHash);
											my $authorGpgFingerprint = DBGetItemAttribute($itemParent, 'gpg_fingerprint');
											if ($authorGpgFingerprint =~ m/([0-9A-F]{16})/) {
												#todo this is dirty, dirty hack
												$authorGpgFingerprint = $1;
											} else {
												$authorGpgFingerprint = '';
											}

											WriteLog('IndexTextFile: #admin: $authorGpgFingerprint = ' . $authorGpgFingerprint);

											if ($authorGpgFingerprint) {
												WriteLog('IndexTextFile: #admin: found $authorGpgFingerprint');
												ExpireAvatarCache($authorGpgFingerprint);
											} else {
												WriteLog('IndexTextFile: #admin: did NOT find $authorGpgFingerprint');
											}
											DBAddVoteRecord('flush');
										} # has permission to remove
										else {
											WriteLog('IndexTextFile: Request to admin file was not found to be valid');
										}
									} # foreach my $itemParent (@itemParents)
								} # has parents
							} # #admin #approve
							else { # non-permissioned hashtags
								if ($tokenFound{'param'} =~ /^[0-9a-zA-Z_]+$/) { #todo actual hashtag format
									my $hashTag = $tokenFound{'param'};
									if (scalar(@itemParents)) { # item has parents to apply tag to
										foreach my $itemParentHash (@itemParents) { # apply to all parents
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
										} # @itemParents
									} # scalar(@itemParents)
								} # valid hashtag
							} # non-permissioned hashtags
							$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
						} #hashtag

					} #hashtag tokens
				} # @tokensFound
			} # not #example

			$detokenedMessage = trim($detokenedMessage);
			if ($detokenedMessage eq '') {
				# add #notext label/tag
				DBAddVoteRecord($fileHash, $addedTime, 'notext');
			}
			else { # has $detokenedMessage
				{ #title:
					my $firstEol = index($detokenedMessage, "\n");
					my $titleLengthCutoff = GetConfig('title_length_cutoff'); #default = 42
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
		} # not pubkey

		if ($message) {
			# cache the processed message text
			my $messageCacheName = GetMessageCacheName($fileHash);
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
		DBAddPageTouch('flush'); #todo shouldn't be here
	}

	PutCache('indexed/'.$fileHash, 1);
	return $fileHash;
} # IndexTextFile()

sub AddToChainLog { # $fileHash ; add line to log/chain.log
	# line format is:
	# file_hash|timestamp|checksum
	# file_hash = hash of file, a-f0-9 40
	# timestamp = epoch time in seconds, no decimal
	# checksum  = hash of new line with previous line
	#
	# if success, returns timestamp of item (epoch seconds)

	my $fileHash = shift;
	chomp $fileHash;

	if (!$fileHash || !IsItem($fileHash)) {
		WriteLog('AddToChainLog: warning: sanity check failed');
		return;
	}

	my $logFilePath = "$HTMLDIR/chain.log"; #public

	{
		#look for existin entry, exit if found
		my $findExistingCommand = "grep ^$fileHash $logFilePath";
		my $findExistingResult = `$findExistingCommand`;
		WriteLog("AddToChainLog: $findExistingCommand returned $findExistingResult");
		if ($findExistingResult) { #todo remove fork
			# hash already exists in chain, return
			#todo return timestamp
			my ($exHash, $exTime, $exChecksum) = split('|', $findExistingResult);

			if ($exTime) {
				return $exTime;
			} else {
				return 0;
			}
		}
	}

	# get components of new line: hash, timestamp, and previous line
	my $newAddedTime = GetTime();
	my $logLine = $fileHash . '|' . $newAddedTime;
	my $lastLineAddedLog = `tail -n 1 $logFilePath`; #note the backticks
	if (!$lastLineAddedLog) {
		$lastLineAddedLog = '';
	}
	chomp $lastLineAddedLog;
	my $lastAndNewTogether = $lastLineAddedLog . '|' . $logLine;
	my $checksum = md5_hex($lastAndNewTogether);
	my $newLineAddedLog = $logLine . '|' . $checksum;

	WriteLog('AddToChainLog: $lastLineAddedLog = ' . $lastLineAddedLog);
	WriteLog('AddToChainLog: $lastAndNewTogether = ' . $lastAndNewTogether);
	WriteLog('AddToChainLog: md5(' . $lastAndNewTogether . ') = $checksum  = ' . $checksum);
	WriteLog('AddToChainLog: $newLineAddedLog = ' . $newLineAddedLog);

	if (!$lastLineAddedLog || ($newLineAddedLog ne $lastLineAddedLog)) {
		# write new line to file
		AppendFile($logFilePath, $newLineAddedLog);

		# figure out how many existing entries for chain sequence value
		my $chainSequenceNumber = (`wc -l html/chain.log | cut -d " " -f 1`) - 1;
		if ($chainSequenceNumber < 0) {
			WriteLog('AddToChainLog: warning: $chainSequenceNumber < 0');
			$chainSequenceNumber = 0;
		}

		# add to index database
		DBAddItemAttribute($fileHash, 'chain_timestamp', $newAddedTime);
		DBAddItemAttribute($fileHash, 'chain_sequence', $chainSequenceNumber);
		DBAddItemAttribute('flush'); #todo shouldn't be here
	}

	return $newAddedTime;
} # AddToChainLog()

sub IndexImageFile { # $file ; indexes one image file into database
	# Reads a given $file, gets its attributes, puts it into the index database
	# If ($file eq 'flush), flushes any queued queries
	# Also sets appropriate task entries

	my $file = shift;
	chomp($file);
	WriteLog("IndexImageFile($file)");

	if ($file eq 'flush') {
		WriteLog("IndexImageFile(flush)");
		DBAddItemAttribute('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddPageTouch('flush');
		return 1;
	}

	my $addedTime;          # time added, epoch format
	my $fileHash;            # git's hash of file blob, used as identifier

	if (IsImageFile($file)) {
		my $fileHash = GetFileHash($file);

		if (GetCache('indexed/'.$fileHash)) {
			return $fileHash;
		}

		WriteLog('IndexImageFile: $fileHash = ' . ($fileHash ? $fileHash : '--'));

		$addedTime = DBGetAddedTime($fileHash);
		# get the file's added time.

		# debug output
		WriteLog('IndexImageFile: $file = ' . ($file?$file:'false'));
		WriteLog('IndexImageFile: $fileHash = ' . ($fileHash?$fileHash:'false'));
		WriteLog('IndexImageFile: $addedTime = ' . ($addedTime?$addedTime:'false'));

		# if the file is present in deleted.log, get rid of it and its page, return
		if (IsFileDeleted($file, $fileHash)) {
			# write to log
			WriteLog('IndexImageFile: IsFileDeleted() returned true, returning');
			return 0;
		}

		if (!$addedTime) {
			WriteLog('IndexImageFile: file missing $addedTime');
			if (GetConfig('admin/logging/write_chain_log')) {
				$addedTime = AddToChainLog($fileHash);
			} else {
				$addedTime = GetTime();
			}
			if (!$addedTime) {
				# sanity check
				WriteLog('IndexImageFile: warning: sanity check failed for $addedTime');
				$addedTime = GetTime();
			}
		}

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

			my $fileShellEscaped = EscapeShellChars($file); #todo this is still a hack, should rename file if it has shell chars?

			# make 800x800 thumbnail
			if (!-e "$HTMLDIR/thumb/thumb_800_$fileHash.gif") {
			# if (!-e "$HTMLDIR/thumb/thumb_420_$fileHash.gif") {
				my $convertCommand = "convert \"$fileShellEscaped\" -thumbnail 800x800 -strip $HTMLDIR/thumb/thumb_800_$fileHash.gif";
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
		DBAddVoteRecord($fileHash, $addedTime, 'image'); # add image tag

		DBAddPageTouch('read');
		DBAddPageTouch('tag', 'image');
		DBAddPageTouch('item', $fileHash);
		DBAddPageTouch('stats');
		DBAddPageTouch('rss');
		DBAddPageTouch('index');
		DBAddPageTouch('flush');

		PutCache('indexed/'.$fileHash, 1);
		return $fileHash;
	}
} # IndexImageFile()

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
		IndexFile($file);
	}
	IndexFile('flush');

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

sub IndexFile { # $file ; calls IndexTextFile() or IndexImageFile() based on extension
	my $file = shift;

	if ($file eq 'flush') {
		WriteLog('IndexFile: flush was requested');
		IndexImageFile('flush');
		IndexTextFile('flush');
		return;
	}

	chomp $file;
	if (!$file || !-e $file || -d $file) {
		WriteLog('IndexFile: warning: sanity check failed.');
		return;
	}

	my $indexSuccess = 0;

	my $ext = lc(GetFileExtension($file));

	if ($ext eq 'txt') {
		WriteLog('IndexFile: calling IndexTextFile()');
		$indexSuccess = IndexTextFile($file);
	}

	if (
		$ext eq 'png' ||
		$ext eq 'gif' ||
		$ext eq 'jpg' ||
		$ext eq 'bmp' ||
		$ext eq 'svg' ||
		$ext eq 'webp' ||
		$ext eq 'jfif'
	) {
		WriteLog('IndexFile: calling IndexImageFile()');
		$indexSuccess = IndexImageFile($file);
	}

	WriteLog('IndexFile: $indexSuccess = ' . $indexSuccess);

	if (GetConfig('admin/index/stat_file') && $indexSuccess) {
		if (-e $file) {
			my @fileStat = stat($file);
			my $fileSize =    $fileStat[7];
			my $fileModTime = $fileStat[9];
			WriteLog('IndexFile: $fileModTime = ' . $fileModTime . '; $fileSize = ' . $fileSize);
			if ($fileModTime) {
				if (IsItem($indexSuccess)) {
					DBAddItemAttribute($indexSuccess, 'file_m_timestamp', $fileModTime);
					DBAddItemAttribute($indexSuccess, 'file_size', $fileSize);
				}
			}
		}
	}

	return $indexSuccess;
} # IndexFile()

my $arg1 = shift;
if ($arg1) {
	if ($arg1 eq '--all') {
		print "index.pl: --all\n";

		MakeIndex();

	}

	if ($arg1 eq '--chain') {
		# html/chain.log
		print "index.pl: --chain\n";
		MakeChainIndex();
	}

	if (-e $arg1) {
		IndexFile($arg1);
		IndexFile('flush');
	}
}

#MakeTagIndex();
1;
