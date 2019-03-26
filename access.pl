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
# Wherever there is a gracias.html and board.nfo exists


my @submitReceivers = `find html/ | grep gracias.html`; #todo this is a hack

foreach (@submitReceivers) {
	s/^\.\/html//;
	s/$/\?comment=/;
	chomp;
}

##################

sub AddHost {
# $host
# $ownAlias = whether it belongs to this instance

	my $host = shift;
	chomp ($host);

	my $ownAlias = shift;
	chomp ($ownAlias);

	WriteLog("AddHost($host, $ownAlias)");

	if ($ownAlias) {
		AddItemToConfigList('my_hosts', $host);
	}

	AddItemToConfigList('pull_hosts', $host);

	return;

}

sub GenerateFilenameFromTime {
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


# ProcessAccessLog (
#	access log file path
#   parse mode:
#		0 = default site log
#		1 = vhost log
# )
sub ProcessAccessLog {
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
	my $mySecret = GetConfig("secret");

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


		## TEXT SUBMISSION PROCESSING BEGINS HERE ##
		############################################

		# Now we see if the user is posting a message
		# We do this by looking for $submitPrefix,
		# which is something like /text/gracias.html?comment=...

		my $submitPrefix;
		my $submitTarget;

		# Look for submitted text wherever gracias.html exists
		foreach (@submitReceivers) {
			if (substr($file, 0, length($_)) eq $_) {
				$submitPrefix = $_;
				$submitTarget = substr($_, 1);
				$submitTarget = substr($submitTarget, 0, rindex($submitTarget, "gracias.html"));
				last;
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

					# Unpack from URL encoding, probably exploitable :(
					$message =~ s/\+/ /g;
					$message = uri_decode($message);
					$message = decode_entities($message);
					#$message = trim($message);
					$message =~ s/\&(.+)=on/\n-- \n$1/g;
					$message =~ s/=on\&/\n/g;
					#is this dangerous?

					# Look for a reference to a parent message in the footer
					# This would come from the hidden variable on the reply form
					# We will use this as a fallback, in case the user has removed
					# the >> line


					# If we're parsing a vhost log, add the site name to the message
					if ($vhostParse && $site) {
						$message .= "\n" . $site;
					}
					#todo remove this unnecessary part

					# Generate filename from date and time
					my $filename;
					$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);


					WriteLog ("I'm going to put $filename\n");

					# Try to write to the file, exit if we can't
					if (PutFile('html/txt/' . $filename, $message)) {
						#Get the hash for this file
						my $fileHash = GetFileHash('html/txt/' . $filename);

						#Add a line to the added.log that records the timestamp
						my $addedTime = time();
						my $logLine = $fileHash . '|' . $addedTime;
						AppendFile('./log/added.log', $logLine);

						#DBAddAddedTimeRecord($fileHash, $addedTime);
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

		my $voteAction = '/action/vote2.html?';
		if (substr($file, 0, length($voteAction)) eq $voteAction) {
			#				http://localhost:3000/action/vote2.html?
			#				addtag%2Feade7e3a1e7d009ee3f190d8bc8c9f2f269fcec3%2F1542345146%2Fagree%2F435fcd62a628d7b918e243fe97912d7b=on
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

				my @voteLines = ( $voteAtom =~ m/^addvote\/([0-9a-f]{40})\/([0-9]+)\/([a-z]+)\/([0-9a-f]{32})/mg );
				#                                 token   /item           /time     /tag      /csrf
				if (@voteLines) {
					my $fileHash   = shift @voteLines;
					my $ballotTime = shift @voteLines;
					my $voteValue  = shift @voteLines;
					my $csrf = shift @voteLines;

					#todo my $voteBallot .= "$fileHash/$ballotTime/$voteValue

					my $checksumCorrect = md5_hex($fileHash . $ballotTime . $mySecret);

					my $currentTime = time();
					if (
							($csrf eq $checksumCorrect) #checksum needs to match
								&&
							(($currentTime - $ballotTime) < 7200) # vote should be recent #todo remove magic number
						) {
						#my $voteEntry = "$fileHash|$ballotTime|$voteValue";
						#AppendFile("log/votes.log", $voteEntry);
						#votes.log is deprecated in favor of adding stuff to the tree

						my $newLine = "addvote/$fileHash/$ballotTime/$voteValue/$csrf";
						if ($newFile) {
							$newFile .= "\n";
						}
						$newFile .= $newLine;

						$newItemCount++;
					}
				}
			}

			if ($newFile) {
				$newFile .= "\n\n(Anonymously submitted without a signature.)";

				my $filename;
				$filename = GenerateFilenameFromTime($dateYear, $dateMonth, $dateDay, $timeHour, $timeMinute, $timeSecond);

				PutFile('html/txt/' . $filename, $newFile);

				if (GetConfig('server_key')) {
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

				my $currentTime = time();
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
