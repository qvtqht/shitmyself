#!/usr/bin/perl

# This file parses the access logs
# It posts messages to html/txt/

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
use Date::Parse;

#use POSIX::strptime qw( strptime );

## CONFIG AND SANITY CHECKS ##

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find ./utils.pl in $SCRIPTDIR");
}
require './utils.pl';
require './index.pl';

# We'll use ./txt as the text repo
my $TXTDIR = "$SCRIPTDIR/html/txt/";

# Logfile for default site domain
# In Apache, use CustomLog, e.g.:
#         CustomLog /foo/bar/log/access.log combined


##################

# Prefixes we will look for in access log to find comments
# and their corresponding drop folders
# Wherever there is a post.html and board.nfo exists


my @submitReceivers = `find html/ | grep post.html`; #todo this is a hack

#push @submitReceivers, 'html/write.html';

foreach (@submitReceivers) {
	s/^html\//\//;
	s/$/\?comment=/;
	chomp;
}

##################

sub AddHost { # adds a host to config/system/my_hosts
# $host
# $ownAlias = whether it belongs to this instance

	my $host = shift;
	chomp ($host);

	my $ownAlias = shift;
	chomp ($ownAlias);

	WriteLog("AddHost($host, $ownAlias)");

	if ($ownAlias) {
		AddItemToConfigList('system/my_hosts', $host);
	}

	AddItemToConfigList('pull_hosts', $host);

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

	#This hash will hold the previous lines we've already processed
	my %prevLines;

	#Count of the new items/actions
	my $newItemCount = 0;

	#If processed.log exists, we load it into %prevLines
	#This is how we will know if we've already looked at a line in the log file
	if (-e "./log/processed.log") {
		open (LOGFILELOG, "./log/processed.log");
		foreach my $procLine (<LOGFILELOG>) {
			chomp $procLine;
			$prevLines{$procLine} = 0;
		}
		close (LOGFILELOG);
	}

	WriteLog ("Processing $logfile...\n");

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
		#Check to see if we've already processed this line
		# by hashing it and looking for its hash in %prevLines
		my $lineHash = md5_hex($line);
		if (defined($prevLines{$lineHash})) {
			# If it exists, return to the beginning of the loop
			$prevLines{$lineHash} ++;
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
				 $req, $file, $proto, $status, $length, $ref) = split(' ',$line);
		} else {
			# Split the log line
			($hostname, $logName, $fullName, $date, $gmt,
				 $req, $file, $proto, $status, $length, $ref) = split(' ',$line);
		}

		my $recordTimestamp = 0; # do we need to record timestamp?
		my $recordFingerprint = 0;  # do we need to record timestamp?

		# useragent is last. everything that is not the values we have pulled out so far
		# is the useragent.
		my $notUseragentLength = length($hostname.$logName.$fullName.$date.$gmt.$req.$file.$proto.$status.$length.$ref) + 10;
		$userAgent = substr($line, $notUseragentLength);

		# Split $date into $time and $date
		my $time = substr($date, 13);
		$date = substr($date, 1, 11);

		# convert date to yyyy-mm-dd format
		my ($dateDay, $dateMonth, $dateYear) = split('/', $date);
		my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12);
		$dateMonth = lc($dateMonth);
		$dateMonth = $mon2num{$dateMonth};

		#my $dateIso = "$dateYear-$dateMonth-$dateDay";
		my ($timeHour, $timeMinute, $timeSecond) = split(':', $time);

		# remove the quotes around the request field
		$req  = substr($req, 1);
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
					unlink ('admin.key');
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
			if ($status eq '404') {
				# If there is no $submitPrefix found
				if (!defined($submitPrefix)) {
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
				WriteLog ("Found a message...\n");

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

						if ($paramName eq 'a') {
							if ($paramValue eq 'anon') {

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


					WriteLog ("I'm going to put $filename\n");

					my $pathedFilename = './html/txt/' . $filename;

					# Try to write to the file, exit if we can't
					if (PutFile($pathedFilename, $message)) {
						if (GetConfig('admin/organize_files')) {
							my $hashFilename = GetFileHashPath($pathedFilename);
							rename($pathedFilename, $hashFilename);
							$pathedFilename = $hashFilename;
						}

						#Get the hash for this file
						my $fileHash = GetFileHash($pathedFilename);

						if ($addTo404Log) {
							AppendFile('./log/404.log', $fileHash);
						}

						my $addedTime = GetTime();

						if (GetConfig('admin/logging/write_added_log')) {
							# #Add a line to the added.log that records the timestamp internally

							my $addedLog = $fileHash . '|' . $addedTime;
							AppendFile('./log/added.log', $addedLog);
						}

						WriteLog("Seems like PutFile() worked! $addedTime");

						if (
							GetConfig('admin/logging/record_timestamps')
								||
							GetConfig('admin/logging/record_clients')
								||
							GetConfig('admin/logging/record_sha512')
						) { #todo this should be factored into a function
							my $addedFilename = 'html/txt/log/added_' . $fileHash . '.log.txt';
							my $addedMessage = '';

							if (GetConfig('admin/logging/record_timestamps') && $recordTimestamp) {
								$addedMessage .= "addedtime/$fileHash/$addedTime\n";
							}

							if (GetConfig('admin/logging/record_clients') && $recordFingerprint) {
								my $clientFingerprint = md5_hex($hostname.$userAgent);
								$addedMessage .= "addedby/$fileHash/$clientFingerprint\n";
							}

							if (GetConfig('admin/logging/record_sha512')) {
								my $fileSha512 = sha512_hex($message);

								$addedMessage .= "sha512/$fileHash/$fileSha512\n";
							}

							if ($addedMessage) {
								PutFile($addedFilename, $addedMessage);

								WriteLog('$addedMessage = ' . $addedMessage);

								ServerSign($addedFilename);
							}

							DBAddAddedTimeRecord($fileHash, $addedTime);
						}
					} else {
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
			#			http://localhost:3000/post.html
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
				} else {
					$eventDateString = $ep{'year'} . '-' . $ep{'month'} . '-' . $ep{'day'};
				}

				my $eventDate = ParseDate($eventDateString);
#				my $eventDate = $eventDateString;

				if (!$addedDates{$eventDate}) {
					$addedDates{$eventDate} = 1;
	
					$newFile .= 'event/' . $eventDate . '/1';
					$newFile .= "\n\n";
	
					#todo actually calculate the date and duration
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
					} else {
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

				PutFile('html/txt/' . $filename, $newFile);
#
#				if (GetConfig('admin/server_key_id')) {
#					ServerSign('html/txt/' . $filename);
#				}
			}
		}

		my $voteAction = '/action/vote2.html?';
		if (substr($file, 0, length($voteAction)) eq $voteAction) {
			#				http://localhost:3000/action/vote2.html?
			#					addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Fagree%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Finformative%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Ffriendly%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Fmeta%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Fremove%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Ftextart%2F435fcd62a628d7b918e243fe97912d7b=on
			#					&addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Fabuse%2F435fcd62a628d7b918e243fe97912d7b=on
			#
			#					everything after ?
			#						split by &
			#						remove =on
			#						urldecode
			#						parse as a vote record
			#
			WriteLog("/action/vote2.html");

			# everything after ?
			my $votesQuery = substr($file, index($file, '?') + 1);

			# split by &
			my @voteAtoms = split('&', $votesQuery);
			my $newFile = '';

			foreach my $voteAtom (@voteAtoms) {
				WriteLog($voteAtom);

				# remove =on
				$voteAtom =~ s/=on$//;
				# url decode
				$voteAtom = uri_decode($voteAtom);

				WriteLog($voteAtom);

				my @voteLines = ( $voteAtom =~ m/^vote\/([0-9a-f]{40})\/([0-9]+)\/([a-z]+)\/([0-9a-f]{32})/mg );
				#                                 token   /item           /time     /tag      /csrf
				if (@voteLines) {
					my $fileHash   = shift @voteLines;
					my $ballotTime = shift @voteLines;
					my $voteValue  = shift @voteLines;
					my $csrf = shift @voteLines;

					#todo my $voteBallot .= "$fileHash/$ballotTime/$voteValue

					my $checksumCorrect = md5_hex($fileHash . $ballotTime . $mySecret);

					my $currentTime = GetTime();
					if (
							($csrf eq $checksumCorrect) #checksum needs to match
								&&
							(($currentTime - $ballotTime) < 7200) # vote should be recent #todo remove magic number
						) {
						#my $voteEntry = "$fileHash|$ballotTime|$voteValue";
						#AppendFile("log/votes.log", $voteEntry);
						#votes.log is deprecated in favor of adding stuff to the tree

						my $newLine = "vote/$fileHash/$ballotTime/$voteValue/$csrf";
						if ($newFile) {
							$newFile .= "\n";
						}
						$newFile .= $newLine;

						$newItemCount++;
					}

					if (GetConfig('admin/logging/record_voter_fingerprint')) {
						$recordFingerprint = 1;
					}
					if (GetConfig('admin/logging/record_voter_timestamp')) {
						$recordTimestamp = 1;
					}
				}
			}

			if ($newFile) {
				#$newFile .= "\n\n(Anonymously submitted without a signature.)";

				my $filename;
				$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);

				PutFile('html/txt/' . $filename, $newFile);

				if (GetConfig('admin/server_key_id')) {
					ServerSign('html/txt/' . $filename);
				}
			}
		}

		# If the URL begins with "/action/" run it through the processor
		my $actionPrefix = "/action/";
		if (0 && substr($file, 0, length($actionPrefix)) eq $actionPrefix) {
			# Put the arguments into an array
			my @actionArgs = split("/", $file);


			# If the action is "vote.html"
			if ($actionArgs[2] eq 'vote.html?') {
				# Get the arguments: file, time, value, checksum
				my $voteFile = $actionArgs[3];
				my $ballotTime = $actionArgs[4];
				my $voteValue = $actionArgs[5];
				my $checksum = $actionArgs[6];

				# Verify the checksum
				my $checksumCorrect = md5_hex($voteFile . $ballotTime . $mySecret);

				my $currentTime = GetTime();
				if ($checksum eq $checksumCorrect && $currentTime - $ballotTime < 7200) {
					my $voteEntry = "$voteFile|$ballotTime|$voteValue";

					AppendFile("log/votes.log", $voteEntry);

					$newItemCount++;
				}
			}
		}
	}

	# Close the log file handle
	close(LOGFILE);

	#Clean up the access log tracker
	my $newPrevLines = "";
	foreach (keys %prevLines) {
		if ($prevLines{$_} > 0) {
			$newPrevLines .= $_;
			$newPrevLines .= "\n";
		}
	}
	PutFile("log/processed.log", $newPrevLines);

	return $newItemCount;
}

1;
