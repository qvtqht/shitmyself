#!/usr/bin/perl -T

# access.pl
# #todo rename to accesslog.pl?
# Parses access.log
# Posts new messages to $TXTDIR -- GetDir('txt');
my $arg1 = shift;

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use lib qw(lib);

use Digest::MD5 qw(md5_hex);
use HTML::Entities qw(decode_entities);
use URI::Encode qw(uri_decode);
use Digest::SHA qw(sha512_hex);
use POSIX qw( mktime );
use Cwd qw(cwd);
use Date::Parse;
#use POSIX::strptime qw( strptime );

## CONFIG AND SANITY CHECKS ##
if (!-e './utils.pl') {
	die ('Sanity check failed, no utils.pl');
}
require './index.pl';

#my $SCRIPTDIR = GetDir('scrpt');
#my $HTMLDIR = $SCRIPTDIR . '/html';
#my $TXTDIR = GetDir('txt');
#my $IMAGEDIR = $HTMLDIR . '/txt';

##################

# Prefixes we will look for in access log to find comments
# and their corresponding drop folders
# Wherever there is a post.html exists
my @submitReceivers;
push @submitReceivers, '/post.php';
push @submitReceivers, '/post.html';
push @submitReceivers, '/stats.html';
foreach (@submitReceivers) {
	s/$/\?comment=/;
	chomp;
}

##################

sub AddHost { # $host, $ownAlias ; add host to config/system/my_hosts
# $host
# $ownAlias = whether it belongs to this instance
	my $host = shift;
	chomp ($host);

	# don't need to do it more than once per script run
	state %hostsAdded;
	if ($hostsAdded{$host}) {
		return;
	}

	my $ownAlias = shift;
	chomp ($ownAlias);

	WriteLog("AddHost($host, $ownAlias)");

	if ($ownAlias) {
		AddItemToConfigList('system/my_hosts', $host);
	} else {
		AddItemToConfigList('system/pull_hosts', $host);
	}

	$hostsAdded{$host} = 1;

	return;
}

sub GenerateFilenameFromTime { # generates a .txt filename based on timestamp
	WriteLog('GenerateFilenameFromTime()');

	# Generate filename from date and time
	my $filename;
	my $filenameDir;

	my $dateYear = shift; #yyyy
	my $dateMonth = shift; # Sep
	my $dateDay = shift; # 01
	my $timeHour = shift; #23
	my $timeMinute = shift; #37
	my $timeSecond = shift; # 59

	# Get the directory name
	$filenameDir = GetDir('txt');

	WriteLog('GenerateFilenameFromTime: $filenameDir = ' . $filenameDir);

	# The filename will be placed in sub-dirs based on date
	$filename = "$dateYear/$dateMonth/$dateDay";

	# Make any necessary directories
	$filename = 'asdffdsfadsf';
	my $TXTDIR = GetDir('txt');

	if (!-d "$TXTDIR$filename") {
		my $TXTDIR = GetDir('txt');
		WriteLog('GenerateFilenameFromTime: mkdir -p $TXTDIR$filename');
		system("mkdir -p $TXTDIR$filename");
	}

	#This is the full filename, except for the .txt extension
	$filename .= "/$dateYear$dateMonth$dateDay$timeHour$timeMinute$timeSecond";

	# Make sure we don't clobber an existing file
	# If filename exists, add (1), (2), and so on
	my $filename_root = $filename;
	my $i = 0;
	while (-e $filenameDir . $filename . ".txt") {
		$i++;
		$filename = $filename_root . "(" . $i . ")";
	}

	#Add the .txt extension
	$filename .= '.txt';

	return $filename;
}

sub LogError {
	my $TXTDIR = GetDir('txt');

	my $errorText = shift;

	my $debugInfo = '#error #meta ' . $errorText;
	
	my $time = GetTime();

	my $debugFilename = 'error_' . $time . '.txt';
	
	$debugFilename = $TXTDIR . $debugFilename;

	WriteLog('PutFile($debugFilename = ' . $debugFilename . ', $debugInfo = ' . $debugInfo . ');');

	PutFile($debugFilename, $debugInfo);
}

sub ProcessAccessLog { # reads an access log and writes .txt files as needed
# ProcessAccessLog(
#	access log file path
#   parse mode:
#		0 = default site log
#		1 = vhost log
# )
	WriteLog("ProcessAccessLog() begin");

	# Processes the specified access.log file
	# Returns the number of new items and/or actions found

	#Parameters

	my $logfile = shift;
	# Path to log file

	my $vhostParse = shift;
	# Whether we use the vhost log format

	#Count of the new items/actions
	my $newItemCount = 0;

	#This hash will hold the previous lines we've already processed
	my %prevLines;
	{
		WriteLog("ProcessAccessLog: Loading processed.log...\n");

		#If processed.log exists, we load it into %prevLines
		#This is how we will know if we've already looked at a line in the log file
		if (-e "./log/processed.log") {
			open(LOGFILELOG, "./log/processed.log");
			foreach my $procLine (<LOGFILELOG>) {
				chomp $procLine;
				$prevLines{$procLine} = 0;
			}
			close(LOGFILELOG);
		}
	}

	WriteLog("ProcessAccessLog: Processing $logfile...\n");

	# The log file should always be there
	if (!open(LOGFILE, $logfile)) {
		WriteLog('ProcessAccessLog: Could not open: $logfile = ' . $logfile);
		return;
	}

	# anti-CSRF secret salt
	my $mySecret = GetConfig("admin/secret");

	# The following section parses the access log
	# Thank you, StackOverflow
	my $lineCounter = 0;
	foreach my $line (<LOGFILE>) {
		WriteLog('ProcessAccessLog: $lineCounter = ' . $lineCounter . '; $line = ' . $line);
		$lineCounter++;

		#Check to see if we've already processed this line
		# by hashing it and looking for its hash in %prevLines
		my $lineHash = md5_hex($line);
		if (defined($prevLines{$lineHash})) {
			# If it exists, return to the beginning of the loop
			$prevLines{$lineHash}++;
			next;
		} else {
			# Otherwise add the hash to processed.log
			#AppendFile("./log/processed.log", $lineHash);
			$prevLines{$lineHash} = 1;
		}

		# These are the values we will pull out of access.log
		my $site;
		my $hostname;
		my $logName;
		my $fullName;
		my $date;
		my $gmt;
		my $req;
		my $file;
		my $proto;
		my $status;
		my $length;
		my $ref;
		my $userAgent;

		# Parse mode select
		if ($vhostParse) {
			# Split the log line
			($site, $hostname, $logName, $fullName, $date, $gmt,
				$req, $file, $proto, $status, $length, $ref) = split(' ', $line);
		} else {
			# Split the log line
			($hostname, $logName, $fullName, $date, $gmt,
				$req, $file, $proto, $status, $length, $ref) = split(' ', $line);
		}

		my $recordTimestamp = 0;   # do we need to record timestamp?
		my $recordFingerprint = 0; # do we need to record fingerprint?
		my $recordDebugInfo = 0;   # do we need to record debug info?

		if (!defined($hostname) || !defined($logName) || !defined($fullName) || !defined($date) || !defined($gmt) || !defined($req) || !defined($file) || !defined($proto) || !defined($status) || !defined($length) || !defined($ref)) {
			# something is missing, better ignore it to be safe.
			LogError('Broken line in access.log: ' . $line);
			next;
		}

		# useragent is last. everything that is not the values we have pulled out so far
		# is the useragent.
		my $notUseragentLength = length($hostname . $logName . $fullName . $date . $gmt . $req . $file . $proto . $status . $length . $ref) + 11;
		$userAgent = substr($line, $notUseragentLength);
		chomp($userAgent);
		$userAgent = trim($userAgent);

		WriteLog('ProcessAccessLog: $date = ' . $date);
		AppendFile('log/useragent.log', $userAgent);

		my $errorTrap = 0;

		if (substr($date, 0, 1) ne '[') {
			LogError('ProcessAccessLog: warning: Date Format Wrong: ' . $line);
			next;
		}

		if ($logName) {
			#todo fix this
			AddHost($logName, 1);
		}

		# Split $date into $time and $date
		my $time = substr($date, 13);
		$date = substr($date, 1, 11);

		WriteLog('ProcessAccessLog: $time = ' . $time);
		WriteLog('ProcessAccessLog: $date = ' . $date);

		# convert date to yyyy-mm-dd format
		my ($dateDay, $dateMonth, $dateYear) = split('/', $date);
		my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12);

		if (!$dateDay || !$dateMonth || !$dateYear) {
			LogError('Missing Date: ' . $line);
			next;
		}

		$dateMonth = lc($dateMonth);
		$dateMonth = $mon2num{$dateMonth};

		if (!$time) {
			LogError('Missing Time: ' . $line);
			next;
		}

		#my $dateIso = "$dateYear-$dateMonth-$dateDay";
		my ($timeHour, $timeMinute, $timeSecond) = split(':', $time);

		$req = substr($req, 1); # remove the quote preceding the request field
		chop($gmt);
		chop($proto);

		# END PARSING OF ACCESS LINE
		############################

		if ($req eq 'HEAD') {
			# ignore HEAD requests
			next;
		}

		if (GetConfig('admin/allow_deop') == 1) {
			if ($file =~ m/chkOverthrow/) {
				my $overthrowInterval = GetConfig('admin/overthrow_interval');
				if (!$overthrowInterval) {
					$overthrowInterval = 1;
				}

				if (time() - GetConfig('admin/latest_admin_action') > $overthrowInterval) {
					WriteLog('ProcessAccessLog: Overthrow conditions met');

					PutConfig('admin/latest_admin_action', 0);

					if (file_exists('admin.key')) {
						unlink('admin.key');
						WriteLog('ProcessAccessLog: Overthrow successful');
						next;
					} else {
						WriteLog('ProcessAccessLog: Overthrow already in effect: admin.key missing');
					}
				} else {
					WriteLog('ProcessAccessLog: Overthrow conditions not met, overthrow unsuccessful');
				}
			}
		} # admin/allow_deop

		## TEXT SUBMISSION PROCESSING BEGINS HERE ##
		############################################

		# Now we see if the user is posting a message
		# We do this by looking for $submitPrefix,
		# which is something like /text/post.html?comment=...

		my $submitPrefix;
		my $submitTarget;

		# Look for submitted text wherever post.html exists
		foreach (@submitReceivers) {
			if (substr($file, 0, length($_)) eq $_) {
				$submitPrefix = $_;
				$submitTarget = substr($_, 1);
				$submitTarget = substr($submitTarget, 0, rindex($submitTarget, "post.html"));
				last;
			}
		}

		my $addTo404Log = 0;
		my $fileWithoutParams = $file;
		if (GetConfig('admin/accept_404_url_text')) {
			WriteLog("ProcessAccessLog: admin/accept_404_url_text...");
			#If the request was met with a 404
			if (index($fileWithoutParams, '?') > 0 && index($fileWithoutParams, '?') != -1) { # for clarity
				# there is a question mark in the request
				# and it is not the first character
				$fileWithoutParams = substr($fileWithoutParams, 0, index($fileWithoutParams, '?'));
			}
		}

		if ($status eq '404' || (GetConfig('admin/lighttpd/enable') && !-e ('html' . $fileWithoutParams))) {
			# this workaround is for lighttpd,
			# which returns 200 instead of 404 when handler is specified

			if (!GetConfig('admin/accept_404_url_text_reduce_spam') || index(substr($file, 1), '/') == -1) {
				# This check is to reduce spam from clients trying to access deleted pages

				if (!defined($submitPrefix)) {
					# If there is no $submitPrefix found already
					WriteLog("No submitPrefix found, but a 404 was...");
					# Just add the whole URL text as an item, as long as admin_accept_url_text is on
					$submitPrefix = '/';

					WriteLog('$submitPrefix = /');

					$addTo404Log = 1;
				}
			}
		}

		# If a submission prefix was found
		if ($submitPrefix) {
			# Look for it in the beginning of the requested URL
			if (substr($file, 0, length($submitPrefix)) eq $submitPrefix) {
				WriteLog("Found a message...\n");

				# Found a new item, increase the counter
				$newItemCount++;

				# The message comes after the prefix, so just trim it
				my $message = (substr($file, length($submitPrefix)));
				my %headerFooter = (); # stores header-footer entries before appending them to "-- " signature

				# If there is a message...
				if ($message) {
					# message= currently needs to come first
					# it doesn't have to be this way, but it currently is
					# because it is simpler to code
					my @messageItems = split('&', $message);

					if (scalar(@messageItems) > 1) {
						$message = shift @messageItems;
					}

					# Unpack from URL encoding
					$message =~ s/\+/ /g;
					$message = uri_decode($message);
					$message = decode_entities($message);
					#$message = trim($message);

					foreach my $urlParam (@messageItems) {
						my ($paramName, $paramValue) = split('=', $urlParam);

						if (!defined($paramValue)) {
							WriteLog('ProcessAccessLog: warning: urlParam: $paramValue missing');
							next;
						}

						WriteLog('ProcessAccessLog: urlParam: $paramName = ' . $paramValue);

						if ($paramName eq 'replyto') {
							if (IsItem($urlParam)) {
								my $replyToId = $paramValue;

								if (!($message =~ /\>\>$replyToId/)) {
									$message .= "\n\n>>$replyToId";
								}
							} else {
								my $replyToId = $paramValue;

								if (!($message =~ /\>\>$replyToId/)) {
									$message .= "\n\n>>$replyToId";
								}
							}
						}

						elsif ($paramName eq 'rectime') {
							if ($paramValue eq 'on') {
								$recordTimestamp = 1;
							}
						}

						elsif ($paramName eq 'recfing') {
							if ($paramValue eq 'on') {
								$recordFingerprint = 1;
							}
						}

						elsif ($paramName eq 'debug') {
							if ($paramValue eq 'on') {
								$recordDebugInfo = 1;
								WriteLog('ProcessAccessLog: $recordDebugInfo = 1');
							}
						}

						else {
							if ($paramName && $paramValue) {
								# $message .= "\n" . $paramName . '=' . $paramValue . "\n";
								# $message .= "\n" . $paramName . '=' . $paramValue . "\n";
								$headerFooter{$paramName} = $paramValue
							}
						}
					} # @messageItems ( message "items" are url params #todo rename)


					#					if ($replyUrlToken) {
					#						$message = s/$replyUrlToken//;
					##						if (index($message, $newReplyToken) >= 0) {
					#							$message = $newReplyToken . "\n\n" . $message;
					##						}
					#					}

					# Look for a reference to a parent message in the footer
					# This would come from the hidden variable on the reply form
					# We will use this as a fallback, in case the user has removed
					# the >> line


					# Generate filename from date and time
					my $filename;
					# $filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);
					$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);

					# Write to log file/debug console
					WriteLog("I'm going to put $filename\n");

					# hardcoded path
					my $TXTDIR = GetDir('txt');
					my $pathedFilename = $TXTDIR . '/' . $filename;

					if (GetConfig('admin/logging/record_http_host')) {
						# append "signature" to file if record_http_host is enabled
						if ($logName) {
							$message .= "\n-- \nHost: " . $logName;
						}
					}

					# Try to write to the file, exit if we can't
					if (PutFile($pathedFilename, $message)) {
						if (GetConfig('admin/organize_files')) {
							# If organizing is enabled, rename the file to its hash-based filename
							my $hashFilename = GetFileHashPath($pathedFilename);
							
							if ($hashFilename) {
								if ($pathedFilename ne $hashFilename) {
									if ($pathedFilename =~ m/^(.+)$/) {
										$pathedFilename = $1;
									}
									if ($hashFilename =~ m/^(.+)$/) {
										$hashFilename = $1;
									}

									WriteLog('ProcessAccessLog: $pathedFilename = ' . $pathedFilename . '; $hashFilename = ' . $hashFilename);

									if (-e $hashFilename) {
										# if $hashFilename already exists and it's larger,
										# leave it alone, and remove file we just created instead
										#
										if (-s $hashFilename > -s $pathedFilename) {
											unlink($pathedFilename);
											$pathedFilename = $hashFilename;
										} else {
											rename($pathedFilename, $hashFilename);
											$pathedFilename = $hashFilename;
										}
									} else {
										rename($pathedFilename, $hashFilename);
										$pathedFilename = $hashFilename;
									}
								}
							} else {
								WriteLog('ProcessAccessLog: warning: tried to organize file, but $hashFilename was false');
							}
						}

						#Get the hash for this file
						my $fileHash = GetFileHash($pathedFilename);

						if ($addTo404Log) {
							# If it's a 404 and we are configured to log it, append to 404.log
							AppendFile('./log/404.log', $fileHash);
						}

						# Remember when this file was added
						my $addedTime = GetTime();



						if (GetConfig('admin/logging/write_chain_log')) {
							AddToChainLog($fileHash);
						}

						# if (GetConfig('admin/logging/write_added_log')) {
						# 	# #Add a line to the added.log that records the timestamp internally
						#
						# 	my $addedLog = $fileHash . '|' . $addedTime;
						# 	AppendFile('./log/added.log', $addedLog);
						#
						# 	if (GetConfig('admin/access_log/call_index')) {
						# 		WriteLog('ProcessAccessLog: access_log_call_index is true, therefore DBAddItemAttribute(' . $fileHash . ',add_timestamp,' . $addedTime . ')');
						# 		DBAddItemAttribute($fileHash, 'add_timestamp', $addedTime);
						# 	}
						# }

						# Tell debug console about file save completion
						WriteLog("Seems like PutFile() worked! $addedTime");

						# record debug info
						if ($recordDebugInfo) {
							my $debugInfo = '>>' . $fileHash;
							$debugInfo .= "\n\n";
							$debugInfo .= "#meta #debug";
							$debugInfo .= "\n";
							$debugInfo .= $userAgent;

							my $debugFilename = 'debug_' . $fileHash . '.txt';
							my $TXTDIR = GetDir('txt');
							$debugFilename = $TXTDIR . '/' . $debugFilename;

							WriteLog('ProcessAccessLog: PutFile($debugFilename = ' . $debugFilename . ', $debugInfo = ' . $debugInfo . ');');
							PutFile($debugFilename, $debugInfo);
						}

						# Begin logging section
						if (
							# GetServerKey() # there should be a server key, otherwise do not log
							# 	&&
							# (
							GetConfig('admin/logging/record_timestamps')
								||
							GetConfig('admin/logging/record_clients')
								||
							GetConfig('admin/logging/record_sha512')
								||
							GetConfig('admin/logging/record_access_log_hash')
							# )
						) {
							# if any of the logging options are turned on, proceed
							# I guess we're saving this 
							my $addedFilename = $TXTDIR . '/log/added_' . $fileHash . '.log.txt';
							my $addedMessage = '';

							# default/admin/logging/record_access_log_hash
							if (GetConfig('admin/logging/record_access_log_hash')) {
								my $accessLogHash = sha1_hex($line);
								$addedMessage .= "AccessLogHash: $accessLogHash\n";
							}

							if (GetConfig('admin/logging/record_timestamps') && $recordTimestamp) {
								$addedMessage .= "AddedTime: $addedTime\n";
							}

							if (GetConfig('admin/logging/record_clients') && $recordFingerprint) {
								WriteLog('ProcessAccessLog: admin/logging/record_clients && $recordFingerprint');
								my $clientFingerprint = uc(substr(md5_hex($hostname . $userAgent), 0, 16));
								$addedMessage .= "Cookie: $clientFingerprint\n";
							}

							if (GetConfig('admin/logging/record_sha512')) {
								my $fileSha512 = sha512_hex($message);
								$addedMessage .= "SHA512: $fileSha512\n";
							}

							if ($addedMessage) {
								$addedMessage = '>>' . $fileHash . "\n\n" . $addedMessage;

								PutFile($addedFilename, $addedMessage);

								WriteLog('ProcessAccessLog: $addedMessage = ' . $addedMessage);

								if (GetServerKey()) {
									ServerSign($addedFilename);
								}
							}

							DBAddItemAttribute($fileHash, 'access_log_timestamp', $addedTime);
						}

						if (GetConfig('admin/access_log/call_index')) {
							WriteLog('access.pl: access_log_call_index is true, therefore IndexFile(' . $pathedFilename . ')');
							IndexFile($pathedFilename);
						}
					}
					else {
						WriteLog("WARNING: Could not open text file to write to: ' . $filename");
					}
				}
			}
		}

		{
			# if rss.txt is requested, look for me= and you= parameters
			# add these parameters to the list of known hosts
			my $rssPrefix = "/rss.txt?";
			if (substr($file, 0, length($rssPrefix)) eq $rssPrefix) {
				WriteLog("Found RSS line!");

				my $paramString = (substr($file, length($rssPrefix)));

				my @params = split('&', $paramString);

				foreach my $param (@params) {
					my ($paramKey, $paramValue) = split('=', $param);
					$paramKey = uri_decode($paramKey);
					$paramValue = uri_decode($paramValue);

					if ($paramKey eq 'you') {
						AddHost($paramValue, 1);
					}
					if ($paramKey eq 'me') {
						AddHost($paramValue, 0);
					}
				}
			}
		} # rss.txt
	}

	# Close the log file handle
	WriteLog('ProcessAccessLog: close(LOGFILE)');
	close(LOGFILE);

	{	# Clean up the access log tracker (processed.log)
		WriteLog('ProcessAccessLog: Remove unused hashes from log/processed.log');
		my $newPrevLines = "";
		foreach my $prevLineKey (keys %prevLines) {
			if ($prevLines{$prevLineKey}) {
				$newPrevLines .= $prevLineKey;
				$newPrevLines .= "\n";
			}
		}
		PutFile("log/processed.log", $newPrevLines);
	}

	return $newItemCount;
} # ProcessAccessLog()

sub ProcessAllAccessLogsInConfig {
	# get list of access log path(s)
	WriteLog('ProcessAllAccessLogsInConfig()');
	my $accessLogPathsConfig = GetConfig('admin/access_log/path_glob_list');
	my @accessLogPaths;
	my $newItemCount = 0; #keep score

	{ # get all the paths out of the globs
		my @accessLogPathGlobs;
		if ($accessLogPathsConfig) {
			@accessLogPathGlobs = split("\n", $accessLogPathsConfig);
		}
		if (@accessLogPathGlobs) {
			foreach my $accessLogPathGlob (@accessLogPathGlobs) {
				push @accessLogPaths, glob($accessLogPathGlob);
			}
		}
	}

	foreach my $accessLogPath (@accessLogPaths) {
		# Check to see if access log exists
		if (-e $accessLogPath) {
			#Process the access log (access.pl)
			$newItemCount += ProcessAccessLog($accessLogPath, 0);
			WriteLog('Processed ' . $accessLogPath . '; $newItemCount = ' . $newItemCount);
		}
		else {
			WriteLog("ProcessAllAccessLogsInConfig: warning: Could not find $accessLogPath");
		}
	}

	return $newItemCount;
} # ProcessAllAccessLogsInConfig()

if ($arg1) {
	chomp $arg1;
	if (-e $arg1) {
		print("Recognized existing file $arg1\n");
		ProcessAccessLog($arg1);
	} elsif ($arg1 eq '--all') {
		ProcessAllAccessLogsInConfig();
	} else {
		print("Argument not understood.");
	}
}

1;
