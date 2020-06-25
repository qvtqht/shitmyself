#!/usr/bin/perl

# This file parses the access logs
# It posts messages to $TXTDIR

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


my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/txt';


#use POSIX::strptime qw( strptime );

## CONFIG AND SANITY CHECKS ##

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find ./utils.pl in $SCRIPTDIR");
}
require './utils.pl';
require './index.pl';

# Logfile for default site domain
# In Apache, use CustomLog, e.g.:
#         CustomLog /foo/bar/log/access.log combined


##################

# Prefixes we will look for in access log to find comments
# and their corresponding drop folders
# Wherever there is a post.html and board.nfo exists


#my @submitReceivers = `find $HTMLDIR | grep post.html`; #todo this is a hack
my @submitReceivers;

push @submitReceivers, '/post.php';
push @submitReceivers, '/post.html';
push @submitReceivers, '/stats.html';

foreach (@submitReceivers) {
	s/$/\?comment=/;
	chomp;
}

##################

sub AddHost { # adds host to config/system/my_hosts
# $host
# $ownAlias = whether it belongs to this instance

	my $host = shift;
	chomp ($host);

	# don't need to do it more than once per script run
	state %hostsAdded;
	if ($hostsAdded{$host}) {
		return;
	}
	$hostsAdded{$host} = 1;

	my $ownAlias = shift;
	chomp ($ownAlias);

	WriteLog("AddHost($host, $ownAlias)");

	if ($ownAlias) {
		AddItemToConfigList('system/my_hosts', $host);
	}

	AddItemToConfigList('system/pull_hosts', $host);

	return;
}

sub GenerateFilenameFromTime { # generates a .txt filename based on timestamp
	WriteLog('GenerateFilenameFromTime()');

	# Generate filename from date and time
	my $filename;
	my $filenameDir;

	my $dateYear = shift;
	my $dateMonth = shift;
	my $dateDay = shift;
	my $timeHour = shift;
	my $timeMinute = shift;
	my $timeSecond = shift;

	# Get the directory name
	$filenameDir = $TXTDIR;

	# The filename will be placed in sub-dirs based on date
	$filename = "$dateYear/$dateMonth/$dateDay";

	# Make any necessary directories
	if (!-d "$TXTDIR$filename") {
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
	my $errorText = shift;

	my $debugInfo = '#error #meta ' . $errorText;
	
	my $time = GetTime();

	my $debugFilename = 'error_' . $time . '.txt';
	
	$debugFilename = $TXTDIR . $debugFilename;

	WriteLog('PutFile($debugFilename = ' . $debugFilename . ', $debugInfo = ' . $debugInfo . ');');

	PutFile($debugFilename, $debugInfo);
}

sub ProcessAccessLog { # reads an access log and writes .txt files as needed
# ProcessAccessLog (
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
		WriteLog("Loading processed.log...\n");

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

	WriteLog("Processing $logfile...\n");

	# The log file should always be there
	if (!open(LOGFILE, $logfile)) {
		WriteLog('Could not open log file.');
		return;
	}

	# anti-CSRF secret salt
	my $mySecret = GetConfig("admin/secret");

	# The following section parses the access log
	# Thank you, StackOverflow
	foreach my $line (<LOGFILE>) {
		WriteLog($line);

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
		my $recordFingerprint = 0; # do we need to record timestamp?
		my $recordDebugInfo = 0;   # do we need to record debug info?

		if (!defined($hostname) || !defined($logName) || !defined($fullName) || !defined($date) || !defined($gmt) || !defined($req) || !defined($file) || !defined($proto) || !defined($status) || !defined($length) || !defined($ref)) {
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
			LogError('Date Format Wrong: ' . $line);
			next;
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

		# remove the quotes around the request field
		$req = substr($req, 1);
		chop($gmt);
		chop($proto);

		# END PARSING OF ACCESS LINE
		############################

		# default/admin/logging/record_access_log_hash
		if (GetConfig('admin/logging/record_access_log_hash')) {
			#todo
		}

		# ALLOW_DEOP, default deop string
		if (GetConfig('admin/allow_deop') == 1) {
			my $deopString = GetConfig('admin/deop_string');

			if ($deopString) {
				my $filteredFile = $file;
				$filteredFile =~ s/[^elit]//g;
				chomp $filteredFile;

				if ($filteredFile eq $deopString) {
					WriteLog("Deop request found, removing admin.key");
					unlink('admin.key');
					next;
				}
			}
		}


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
		WriteLog("Check admin/accept_404_url_text...");
		if (GetConfig('admin/accept_404_url_text')) {
			#If the request was met with a 404
			if ($status eq '404' || (GetConfig('admin/lighttpd/enable') && !-e ('html' . $file))) {
				# this workaround is for lighttpd,
				# which returns 200 instead of 404 when handler
				# is specified because it's stupid

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

				# If there is a message...
				if ($message) {
					#todo the message= currently needs to come first, it doesn't have to be this way
					my @messageItems = split('&', $message);

					if (scalar(@messageItems) > 1) {
						$message = shift @messageItems;
					}

					# Unpack from URL encoding, probably exploitable :(
					$message =~ s/\+/ /g;
					$message = uri_decode($message);
					$message = decode_entities($message);
					#$message = trim($message);

					##
					#					my $replyUrlToken = ( $message=~ m/replyto=(0-9a-f){40}/ );
					#					my $newReplyToken = '';
					##
					#					if ($replyUrlToken) {
					#						my $newReplyToken = $replyUrlToken;
					#						$newReplyToken =~ s/replyto=/>>/;
					#						$message =~ s/$replyUrlToken/$newReplyToken/g;
					#					}


					#todo bugs below, since only stuff below -- should be reformatted

					#					$message =~ s/\&(.+)=on/\n-- \n$1/g;
					#					$message =~ s/=on\&/\n&/g;
					#					$message =~ s/\&/\n&/g;
					#is this dangerous?

					foreach my $urlParam (@messageItems) {
						my ($paramName, $paramValue) = split('=', $urlParam);

						if ($paramName eq 'replyto') {
							if (IsItem($urlParam)) {
								my $replyToId = $paramValue;

								if (!($message =~ /\>\>$replyToId/)) {
									$message .= "\n\n>>$replyToId";
								}
							}
						}

						if ($paramName && $paramName eq 'a') {
							if ($paramValue && $paramValue eq 'anon') {

							}
						}

						if ($paramName eq 'rectime') {
							if ($paramValue eq 'on') {
								$recordTimestamp = 1;
							}
						}

						if ($paramName eq 'recfing') {
							if ($paramValue eq 'on') {
								$recordFingerprint = 1;
							}
						}

						if ($paramName eq 'debug') {
							if ($paramValue eq 'on') {
								$recordDebugInfo = 1;
								WriteLog('$recordDebugInfo = 1');
							}
						}
					}


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


					#					# If we're parsing a vhost log, add the site name to the message
					#					if ($vhostParse && $site) {
					#						$message .= "\n" . $site;
					#					}
					#					#todo remove this unnecessary part

					# Generate filename from date and time
					my $filename;
					#					$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);
					$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);

					# Write to log file/debug console
					WriteLog("I'm going to put $filename\n");

					# hardcoded path
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
									rename($pathedFilename, $hashFilename);
									$pathedFilename = $hashFilename;
								}
							} else {
								WriteLog('WARNING: tried to organize file, but $hashFilename was false');
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

						if (GetConfig('admin/logging/write_added_log')) {
							# #Add a line to the added.log that records the timestamp internally

							my $addedLog = $fileHash . '|' . $addedTime;
							AppendFile('./log/added.log', $addedLog);

							if (GetConfig('admin/access_log_call_index')) {
								WriteLog('access.pl: access_log_call_index is true, therefore DBAddAddedTimeRecord(' . $fileHash . ',' . $addedTime . ')');
								DBAddAddedTimeRecord($fileHash, $addedTime);
							}
						}

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
							$debugFilename = $TXTDIR . '/' . $debugFilename;

							WriteLog('PutFile($debugFilename = ' . $debugFilename . ', $debugInfo = ' . $debugInfo . ');');

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
							# )
						) {
							# if any of the logging options are turned on, proceed
							# I guess we're saving this 
							my $addedFilename = $TXTDIR . '/log/added_' . $fileHash . '.log.txt';
							my $addedMessage = '';

							if (GetConfig('admin/logging/record_timestamps') && $recordTimestamp) {
								$addedMessage .= "addedtime/$fileHash/$addedTime\n";
							}

							if (GetConfig('admin/logging/record_clients') && $recordFingerprint) {
								my $clientFingerprint = md5_hex($hostname . $userAgent);
								$addedMessage .= "addedby/$fileHash/$clientFingerprint\n";
							}

							if (GetConfig('admin/logging/record_sha512')) {
								my $fileSha512 = sha512_hex($message); #todo fix wide character error here

								$addedMessage .= "sha512/$fileHash/$fileSha512\n";
							}

							if ($addedMessage) {
								PutFile($addedFilename, $addedMessage);

								WriteLog('$addedMessage = ' . $addedMessage);

								if (GetServerKey()) {
									ServerSign($addedFilename);
								}
							}

							DBAddAddedTimeRecord($fileHash, $addedTime);
						}

						if (GetConfig('admin/access_log_call_index')) {
							WriteLog('access.pl: access_log_call_index is true, therefore IndexTextFile(' . $pathedFilename . ')');
							IndexTextFile($pathedFilename);
						}
					}
					else {
						WriteLog("WARNING: Could not open text file to write to: ' . $filename");
					}
				}
			}
		}

		#todo review this block
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

		my $eventAction = '/action/event.html?';
		if (substr($file, 0, length($eventAction)) eq $eventAction) {
			#			http://localhost:2784/post.html
			#		x		?event_name=event_name
			#		x		&brc_ave=9:55
			#		x		&brc_street=Q
			#		x		&event_location=location
			#		x		&month=11
			#		x		&day=11
			#		x		&year=2025
			#		x		&hour=11
			#		x		&minute=15
			#		x		&am_pm=1
			#		x		&event_details=11%3A11%3A11

			WriteLog("/action/event.html");

			my $eventQuery = substr($file, index($file, '?') + 1);

			my @eventAtoms = split('&', $eventQuery);

			my %ep = (); # %eventParams

			foreach my $param (@eventAtoms) {
				my ($key, $value) = split('=', $param);

				$value =~ s/\+/ /g;
				$value = uri_decode($value);
				$value = decode_entities($value);

				$ep{$key} = $value;
			}

			my $newFile = '';

			if (exists($ep{'event_name'})) {
				#todo validate/sanitize
				$newFile .= $ep{'event_name'};
				$newFile .= "\n\n";
			}

			if (exists($ep{'brc_ave'}) && exists($ep{'brc_street'})) {
				#todo validate/sanitize
				if ($ep{'brc_ave'} || $ep{'brc_street'}) {
					$newFile .= 'brc/' . $ep{'brc_ave'} . '/' . $ep{'brc_street'} . "\n\n";
				}
			}

			if (exists($ep{'event_location'})) {
				if (trim($ep{'event_location'}) ne '') {
					$newFile .= 'Location: ' . uri_decode($ep{'event_location'});
					$newFile .= "\n\n";
				}
			}

			my %addedDates = (); # used to keep track of timestamps added to prevent duplicates

			if (exists($ep{'month'}) && exists($ep{'day'}) && exists($ep{'year'})) {
				my $eventDateString;

				if ($ep{'month'} < 10) {
					$ep{'month'} = '0' . $ep{'month'};
				}

				if ($ep{'day'} < 10) {
					$ep{'day'} = '0' . $ep{'day'};
				}

				if (exists($ep{'hour'}) && exists($ep{'minute'})) {
					if (exists($ep{'am_pm'}) && $ep{'am_pm'}) {
						$ep{'hour'} += 12;
					}

					if ($ep{'hour'} < 10) {
						$ep{'hour'} = '0' . $ep{'hour'};
					}

					if ($ep{'minute'} < 10) {
						$ep{'minute'} = '0' . $ep{'minute'};
					}

					$eventDateString = $ep{'year'} . '-' . $ep{'month'} . '-' . $ep{'day'} . ' ' . $ep{'hour'} . ':' . $ep{'minute'};
				}
				else {
					$eventDateString = $ep{'year'} . '-' . $ep{'month'} . '-' . $ep{'day'};
				}

				my $eventDate = ParseDate($eventDateString);
				#				my $eventDate = $eventDateString;

				if (!$addedDates{$eventDate}) {
					if ($eventDate ne 'NaN') {
						$addedDates{$eventDate} = 1;

						$newFile .= 'event/' . $eventDate . '/1';
						$newFile .= "\n\n";

						#todo actually calculate the date and duration
					}
				}
			}

			if (exists($ep{'date_epoch'})) {
				my $eventDateEpoch = $ep{'date_epoch'};

				if ($eventDateEpoch) {

					if (!$addedDates{$eventDateEpoch}) {
						$addedDates{$eventDateEpoch} = 1;

						#todo more sanity
						$newFile .= 'event/' . $eventDateEpoch . '/2';
						$newFile .= "\n\n";
					}
				}
			}

			if (exists($ep{'date_yyyy'})) {
				my $eventDateStringFromYyyy = $ep{'date_yyyy'};

				if ($eventDateStringFromYyyy) {
					my $eventDateStringEpoch = ParseDate($eventDateStringFromYyyy);
					if ($eventDateStringEpoch) {
						WriteLog('$eventDateStringEpoch = ' . $eventDateStringEpoch);

						if ($eventDateStringEpoch) {
							if (!$addedDates{$eventDateStringEpoch}) {
								$addedDates{$eventDateStringEpoch} = 1;

								$newFile .= 'event/' . $eventDateStringEpoch . '/3';
								$newFile .= "\n\n";
							}
						}
					}
					else {
						$newFile .= "Date: $eventDateStringFromYyyy";
						$newFile .= "\n\n";
					}
				}
			}

			if (exists($ep{'event_details'})) {
				my $eventDescription = $ep{'event_details'};

				$newFile .= $eventDescription;
				$newFile .= "\n\n";
			}

			#todo finish the other params

			if ($newFile) {
				#$newFile .= "\n\n(Anonymously submitted without a signature.)";

				$newFile = trim($newFile);
				$newFile =~ s/\n\n\n/\n\n/g;
				#todo this shouldn't be necessary, clean up the \n\n above

				my $filename;
				$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);

				PutFile($TXTDIR . '/' . $filename, $newFile);
				#
				#				if (GetConfig('admin/server_key_id')) {
				#					ServerSign($TXTDIR . '/' . $filename);
				#				}
			}
		}
	}

	# Close the log file handle
	close(LOGFILE);
	
	#Clean up the access log tracker
	my $newPrevLines = "";
	
	foreach (keys %prevLines) { #todo make this actually work
		if ($prevLines{$_} > 0) {
			$newPrevLines .= $_;
			$newPrevLines .= "\n";
		}
	}
	PutFile("log/processed.log", $newPrevLines);

	return $newItemCount;
}

1;
