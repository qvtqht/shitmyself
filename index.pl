#!/usr/bin/perl

# indexes one file or all files eligible for indexing
# --all .... all eligible files
# [path] ... index specified file
# --chain .. chain.log file (contains timestamps)

use strict;
use warnings;
use utf8;

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

use Digest::SHA qw(sha512_hex);

require('./gpgpg.pl');
require('./utils.pl');

sub MakeChainIndex { # $import = 1; reads from log/chain.log and puts it into item_attribute table
	# note: this is kind of a hack, and non-importing validation should just be separate own sub
	# note: this hack seems to work ok

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

			my %return;

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
				DBAddItemAttribute($fileHash, 'chain_previous', $previousLine);
				WriteLog('MakeChainIndex: $sequenceNumber = ' . $sequenceNumber);
				WriteLog('MakeChainIndex: (next item stub/aka checksum) $previousLine = ' . $previousLine);

				$return{'chain_sequence'} = $sequenceNumber;
				$return{'chain_previous'} = $previousLine;
				$return{'chain_timestamp'} = $addedTime;

				$sequenceNumber = $sequenceNumber + 1;
				$previousLine = $currentLine;
			} # foreach $currentLine (@addedRecord)

			DBAddItemAttribute('flush');

			return %return;
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

sub GetTokenDefs {
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
			'mask'    => '^(\>\>)(\W?)([0-9a-f]{40})', # >>
			'mask_params' => 'mg',
			'message' => '[Parent]'
		},
	#				{ # reference to item
	#					'token'   => 'itemref',
	#					'mask'    => '(\W?)([0-9a-f]{8})(\W?)',
	#					'mask_params' => 'mg',
	#					'message' => '[Reference]'
	#				}, #todo make it ensure item exists before parsing
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
		{ # #sql token, returns sql results (for privileged users)
			# example: #sql select author_key, alias from author_alias
			# must be a select statement, no update etc
			# to begin with, limited to 1 line; #todo
			'token' => 'sql',
			'mask' => '^(sql)(\W).+$',
			'mask_params' => 'mgi',
			'message' => '[SQL]',
			'apply_to_parent' => 0
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

		# REGEX cheatsheet
		# ================
		#
		# \w word
		# \W NOT word
		# \s whitespace
		# \S NOT whitespace
		#
		# /s = single-line (changes behavior of . metacharacter to match newlines)
		# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
		# /g = global (all instances)
		# /i = case-insensitive
		# /e = eval

	return @tokenDefs;
} # GetTokenDefs()

sub IndexTextFile { # $file | 'flush' ; indexes one text file into database
# Reads a given $file, parses it, and puts it into the index database
# If ($file eq 'flush'), flushes any queued queries
# Also sets appropriate task entries
	my $SCRIPTDIR = GetDir('script');
	my $HTMLDIR = GetDir('html');
	my $TXTDIR = GetDir('txt');

	my $file = shift;
	chomp($file);

	if ($file eq 'flush') {
		WriteLog("IndexTextFile(flush)");
		DBAddKeyAlias('flush');
		DBAddItem('flush');
		DBAddVoteRecord('flush');
		DBAddEventRecord('flush');
		DBAddItemParent('flush');
		DBAddPageTouch('flush');
		DBAddConfigValue('flush');
		DBAddItemAttribute('flush');
		DBAddLocationRecord('flush');
		return 1;
	}

	WriteLog('IndexTextFile(' . $file . ')');

	if (GetConfig('admin/organize_files')) {
		# renames files to their hashes
		$file = OrganizeFile($file);
	}

	my $fileHash; # hash of file contents
	$fileHash = GetFileHash($file);

	if (!$file || !$fileHash) {
		WriteLog('IndexTextFile: warning: $file or $fileHash missing; returning');
		return 0;
	}

	WriteLog('IndexTextFile: $fileHash = ' . $fileHash);
	if (GetConfig('admin/logging/write_chain_log')) {
		AddToChainLog($fileHash);
	}

	if (GetCache("indexed/$fileHash")) {
		WriteLog('IndexTextFile: aleady indexed, returning. $fileHash = ' . $fileHash);
		return $fileHash;
	}

	my $authorKey = '';

	if (substr(lc($file), length($file) -4, 4) eq ".txt") {
		if (GetConfig('admin/gpg/enable')) {
			$authorKey = GpgParse($file) || '';
		}
		my $message = GetFileMessage($file);

		if (!defined($message)) {
			WriteLog('IndexTextFile: warning: $message was not defined, setting to empty string');
			$message = '';
		}

		my $detokenedMessage = $message;
		my %hasToken;

		my @tokenMessages;
		my @tokensFound;
		{ #tokenize into @tokensFound
			###################################################
			# TOKEN FIRST PASS PARSING BEGINS HERE
			# token: identifier
			# mask: token string, separator, parameter
			# params: parameters for regex matcher
			# message: what's displayed in place of token for user
			my @tokenDefs = GetTokenDefs();

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
						WriteLog('IndexTextFile: sanity check passed');
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
					} # @tokenLines
				} # GetConfig("admin/token/$tokenName") && $detokenedMessage
			} # @tokenDefs

			# TOKEN FIRST PASS PARSING ENDS HERE
			# @tokensFound now has all the found tokens
			WriteLog('IndexTextFile: scalar(@tokensFound) = ' . scalar(@tokensFound));
			###################################################
		} #tokenize into @tokensFound

		my @itemParents;

		{ # first pass, look for cookie, parent, auth
			foreach my $tokenFoundRef (@tokensFound) {

				my %tokenFound = %$tokenFoundRef;
				if ($tokenFound{'token'} && $tokenFound{'param'}) {

					if ($tokenFound{'token'} eq 'cookie') {
						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							DBAddItemAttribute($fileHash, 'cookie_id', $tokenFound{'param'}, 0, $fileHash);
							$message = str_replace($tokenFound{'recon'}, $tokenFound{'message'}, $message);
							$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
							if (!$authorKey) {
								$authorKey = $tokenFound{'param'};
							}
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
				} #param
			} # foreach
		} # first pass, look for cookie, parent, auth

		WriteLog('IndexTextFile: %hasToken: ' . join(',', keys(%hasToken)));

		DBAddItem2($file, $fileHash, 'txt');

		if ($hasToken{'example'}) {
			push @tokenMessages, 'Token #example was found, other tokens will be ignored.';
		} # #example
		else { # not #example
			foreach my $tokenFoundRef (@tokensFound) {
				my %tokenFound = %$tokenFoundRef;
				if ($tokenFound{'token'} && $tokenFound{'param'}) {
					WriteLog('IndexTextFile: token, param: ' . $tokenFound{'token'} . ',' . $tokenFound{'param'});

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
									DBAddItemAttribute($itemParent, $tokenFound{'token'}, $tokenFound{'param'}, 0, $fileHash);
								}
							} else {
								DBAddItemAttribute($fileHash, $tokenFound{'token'}, $tokenFound{'param'}, 0, $fileHash);
							}
						} else {
							WriteLog('IndexTextFile: warning: ' . $tokenFound{'token'} . ' (generic): sanity check failed');
						}
					} # title, access_log_hash, url, alt

					if ($tokenFound{'token'} eq 'config') { #config
						if (
							IsAdmin($authorKey) || #admin can always config #todo
							GetConfig('admin/anyone_can_config') || # anyone can config
							(GetConfig('admin/signed_can_config') || 0) || # signed can config #todo
							(GetConfig('admin/cookied_can_config') || 0) # cookied can config #todo
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

								if (IsAdmin($authorKey) || ConfigKeyValid($configKeyActual)) { #todo
									# admins can write to any config
									# non-admins can only write to existing config keys (and not under admin/)

									# #todo create a whitelist of safe keys non-admins can change

									DBAddConfigValue($configKeyActual, $configValue, 0, 0, $fileHash);
									WriteIndexedConfig();
									$message = str_replace($tokenFound{'recon'}, "[Config: $configKeyActual = $configValue]", $message);
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
								} else {
									# token tried to pass unacceptable config key
									$message = str_replace($tokenFound{'recon'}, "[Not Accepted: $configKeyActual]", $message);
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
								}
							} # sanity check
						} # has permission to config
					} # #config


					if ($tokenFound{'token'} eq 'puzzle') { # puzzle
						my ($puzzleAuthorKey, $mintedAt, $checksum) = split(' ', $tokenFound{'param'});
						WriteLog("IndexTextFile: token: puzzle: $puzzleAuthorKey, $mintedAt, $checksum");

						#todo must match message author key
						if ($puzzleAuthorKey ne $authorKey) {
							WriteLog('IndexTextFile: puzzle: warning: $puzzleAuthorKey ne $authorKey');
						} else {
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
									($authorKey eq $puzzleAuthorKey) # key matches cookie or fingerprint
								) {
									$message =~ s/$tokenFound{'recon'}/[$puzzlePrefix]/g;
	#									$message =~ s/$tokenFound{'recon'}/[Solved puzzle with this prefix: $puzzlePrefix]/g;
									DBAddItemAttribute($fileHash, 'puzzle_timestamp', $mintedAt);
									DBAddVoteRecord($fileHash, $mintedAt, 'puzzle');
									$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
									$puzzleAccepted = 1;

									last;
									#DBAddItemAttribute('
									#$message .= 'puzzle valid!'; #$reconLine . "\n" . $hash;
								}
							}#foreach my $puzzlePrefix (@acceptPuzzlePrefix) {
						}
					} # puzzle


					if ($tokenFound{'token'} eq 'my_name_is') { # my_name_is
						if ($tokenFound{'recon'} && $tokenFound{'message'} && $tokenFound{'param'}) {
							WriteLog('IndexTextFile: my_name_is: sanity check PASSED');
							if ($authorKey) {
								$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
								my $nameGiven = $tokenFound{'param'};
								$message =~ s/$tokenFound{'recon'}/[my name is: $nameGiven]/g;

								DBAddKeyAlias($authorKey, $tokenFound{'param'}, $fileHash);
								DBAddItemAttribute($fileHash, 'title', $tokenFound{'param'} . ' has self-identified'); #todo templatize
								DBAddKeyAlias('flush');
							}
						} else {
							WriteLog('IndexTextFile: warning: my_name_is: sanity check FAILED');
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
									#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($authorKey) . '; $authorKey = ' . $authorKey . '; $parentItemAuthor = ' . $parentItemAuthor);
									WriteLog('IndexTextFile: #remove: $authorKey = ' . $authorKey);
									#WriteLog('IndexTextFile: #remove: IsAdmin = ' . IsAdmin($authorKey));
									WriteLog('IndexTextFile: #remove: $parentItemAuthor = ' . $parentItemAuthor);

									# at this time only signed requests to remove are honored
									if (
										$authorKey # is signed
											&&
											(
												IsAdmin($authorKey)                   # signed by admin
													||                             # OR
												($authorKey eq $parentItemAuthor) 	   # signed by same as author
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
							$tokenFound{'param'} eq 'admin' || #admin token needs permission
							$tokenFound{'param'} eq 'approve' #approve token needs permission
						) { # #admin #approve tokens which need permissions
							my $hashTag = $tokenFound{'param'};
							if (scalar(@itemParents)) {
								WriteLog('IndexTextFile: Found permissioned token ' . $tokenFound{'param'} . ', and item has parents');
								foreach my $itemParent (@itemParents) {
									# find the author of this item
									# this will help us determine whether the request can be fulfilled

									if (
										$authorKey # is signed
										&&
										IsAdmin($authorKey) # signed by admin
									) {
										WriteLog('IndexTextFile: #admin: Found seemingly valid request');
										DBAddVoteRecord($itemParent, 0, $hashTag, $authorKey, $fileHash);
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
							WriteLog('IndexTextFile: non-permissioned hashtag');
							if ($tokenFound{'param'} =~ /^[0-9a-zA-Z_]+$/) { #todo actual hashtag format
								WriteLog('IndexTextFile: hashtag sanity check passed');
								my $hashTag = $tokenFound{'param'};
								if (scalar(@itemParents)) { # item has parents to apply tag to
									WriteLog('IndexTextFile: parents found, applying hashtag to them');

									foreach my $itemParentHash (@itemParents) { # apply to all parents
										WriteLog('IndexTextFile: applying hashtag, $itemParentHash = ' . $itemParentHash);
										if ($authorKey) {
											WriteLog('IndexTextFile: $authorKey = ' . $authorKey);
											# include author's key if message is signed
											DBAddVoteRecord($itemParentHash, 0, $hashTag, $authorKey, $fileHash);
										}
										else {
											WriteLog('IndexTextFile: $authorKey was FALSE');
											DBAddVoteRecord($itemParentHash, 0, $hashTag, '', $fileHash);
										}
										DBAddPageTouch('item', $itemParentHash);
									} # @itemParents
								} # scalar(@itemParents)
							} # valid hashtag
						} # non-permissioned hashtags

						$detokenedMessage = str_replace($tokenFound{'recon'}, '', $detokenedMessage);
					} #hashtag
				} # if ($tokenFound{'token'} && $tokenFound{'param'}) {
			} # foreach @tokensFound
		} # not #example

		$detokenedMessage = trim($detokenedMessage);
		if ($detokenedMessage eq '') {
			# add #notext label/tag
			WriteLog('IndexTextFile: no $detokenedMessage, setting #notext; $fileHash = ' . $fileHash);
			DBAddVoteRecord($fileHash, 0, 'notext');
		}
		else { # has $detokenedMessage
			WriteLog('IndexTextFile: has $detokenedMessage $fileHash = ' . $fileHash);
			{ #title:
				my $firstEol = index($detokenedMessage, "\n");
				my $titleLength = GetConfig('title_length'); #default = 255
				if (!$titleLength) {
					$titleLength = 255;
					WriteLog('#todo: warning: $titleLength was false');
				}
				if ($firstEol == -1) {
					if (length($detokenedMessage) > 1) {
						$firstEol = length($detokenedMessage);
					}
				}
				if ($firstEol > $titleLength) {
					$firstEol = $titleLength;
				}
				if ($firstEol > 0) {
					my $title = '';
					if ($firstEol <= $titleLength) {
						$title = substr($detokenedMessage, 0, $firstEol);
					} else {
						$title = substr($detokenedMessage, 0, $titleLength) . '...';
					}
					DBAddItemAttribute($fileHash, 'title', $title, 0);
					DBAddVoteRecord($fileHash, 0, 'hastitle');
				}
			}

			DBAddVoteRecord($fileHash, 0, 'hastext');
			DBAddPageTouch('tag', 'hastext');
		} # has a $detokenedMessage

		if ($message) {
			# cache the processed message text
			my $messageCacheName = GetMessageCacheName($fileHash);
			WriteLog('IndexTextFile: Calling PutFile(), $fileHash = ' . $fileHash . '; $messageCacheName = ' . $messageCacheName);
			PutFile($messageCacheName, $message);
		} else {
			WriteLog('IndexTextFile: I was going to save $messageCacheName, but $message is blank!');
		}
	} # .txt

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

	if (!$fileHash) {
		WriteLog('AddToChainLog: warning: sanity check failed');
		return '';
	}

	chomp $fileHash;

	if (!IsItem($fileHash)) {
		WriteLog('AddToChainLog: warning: sanity check failed');
		return '';
	}

	my $HTMLDIR = GetDir('html');
	my $logFilePath = "$HTMLDIR/chain.log"; #public

	$fileHash = IsItem($fileHash);

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
			WriteLog('IndexImageFile: skipping because of flag: indexed/'.$fileHash);
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
			my $HTMLDIR = GetDir('html');

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

		PutCache('indexed/' . $fileHash, 1);
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

	my $TXTDIR = GetDir('txt');
	WriteLog('MakeIndex: $TXTDIR = ' . $TXTDIR);

	#my @filesToInclude = split("\n", `grep txt\$ ~/index/home.txt`); #homedir #~
	my @filesToInclude = split("\n", `find $TXTDIR -name \\\*.txt`);

	my $filesCount = scalar(@filesToInclude);
	my $currentFile = 0;
	foreach my $file (@filesToInclude) {
		#$file =~ s/^./../;

		$currentFile++;
		my $percent = ($currentFile / $filesCount) * 100;
		WriteMessage("*** MakeIndex: $currentFile/$filesCount ($percent %) $file");
		IndexFile($file);
	}
	IndexFile('flush');

	WriteIndexedConfig();

	if (GetConfig('admin/image/enable')) {
		my $HTMLDIR = GetDir('html');

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
} # MakeIndex()

sub IndexFile { # $file ; calls IndexTextFile() or IndexImageFile() based on extension
	my $file = shift;

	if ($file eq 'flush') {
		WriteLog('IndexFile: flush was requested');
		IndexImageFile('flush');
		IndexTextFile('flush');
		return '';
	}

	if (!$file) {
		WriteLog('IndexFile: warning: $file is false');
		return '';
	}

	chomp $file;

	WriteLog('IndexFile: $file = ' . $file);
	if (!-e $file) {
		WriteLog('IndexFile: warning: -e $file is false (file does not exist)');
		return '';
	}

	if (-d $file) {
		WriteLog('IndexFile: warning: -d $file was true (file is a directory)');
		return '';
	}

	my $fileHash = GetFileHash($file);
	if (GetCache("indexed/$fileHash")) {
		WriteLog('IndexFile: aleady indexed, returning. $fileHash = ' . $fileHash);
		return $fileHash;
	}

	my $indexSuccess = 0;

	my $ext = lc(GetFileExtension($file));

	if ($ext eq 'txt') {
		WriteLog('IndexFile: calling IndexTextFile()');
		$indexSuccess = IndexTextFile($file);

		if (!$indexSuccess) {
			WriteLog('IndexFile: warning: $indexSuccess was FALSE');
			$indexSuccess = 0;
		}
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

	if ($indexSuccess) {
		WriteLog('IndexFile: $indexSuccess = ' . $indexSuccess);
	} else {
		WriteLog('IndexFile: warning: $indexSuccess FALSE');
	}

	if ($indexSuccess && GetConfig('admin/index/stat_file')) {
		if (-e $file) {
			my @fileStat = stat($file);
			my $fileSize =    $fileStat[7];
			my $fileModTime = $fileStat[9];
			WriteLog('IndexFile: $fileModTime = ' . $fileModTime . '; $fileSize = ' . $fileSize);
			if ($fileModTime) {
				if (IsItem($indexSuccess)) {
					DBAddItemAttribute($indexSuccess, 'file_m_timestamp', $fileModTime);
					DBAddItemAttribute($indexSuccess, 'file_size', $fileSize);
				} else {
					WriteLog('IndexFile: warning: IsItem($indexSuccess) was FALSE');
				}
			}
		}
	}

	PutCache("indexed/$indexSuccess", 1);

	return $indexSuccess;
} # IndexFile()

while (my $arg1 = shift @argsFound) {
	WriteLog('index.pl: $arg1 = ' . $arg1);
	if ($arg1) {
		if ($arg1 eq '--all') {
			print "index.pl: --all\n";
			MakeIndex();
			MakeChainIndex();
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
}

#MakeTagIndex();
1;
