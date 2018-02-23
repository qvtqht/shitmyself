#!/usr/bin/perl

# This file parses the access logs
# It posts messages to ./txt/

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use HTML::Entities;
use URI::Encode qw(uri_decode);

## CONFIG AND SANITY CHECKS ##

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find ./utils.pl in $SCRIPTDIR");
}
require './utils.pl';

# We'll use ./txt as the text repo
my $TXTDIR = "$SCRIPTDIR/txt/";

# Logfile for default site domain
# In Apache, use CustomLog, e.g.:
#         CustomLog /foo/bar/log/access.log combined

my $LOGFILE = "$SCRIPTDIR/log/lighttpd.log";
print "\$LOGFILE=$LOGFILE\n";


##################

# Prefixes we will look for in access log to find comments
# and their corresponding drop folders
# Wherever there is a gracias.html and board.nfo exists


my @submitReceivers = `find ./html/ | grep gracias.html`; #todo this is a hack

foreach (@submitReceivers) {
	s/^\.\/html//;
	s/$/\?comment=/;
	chomp;
}

##################


# ProcessAccessLog (
#	access log file path
#   parse mode:
#		0 = default site log
#		1 = vhost log
# )
sub ProcessAccessLog {
	my $logfile = shift;       # Path to log file
	my $vhostParse = shift;    # Whether we use the vhost log format

	print "Processing $logfile...\n";

	# The log file should always be there
	open(LOGFILE, $logfile) or die("Could not open log file.");

	# The following section parses the access log
	# Thank you, StackOverflow
	foreach my $line (<LOGFILE>) {
		#print ".";

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

		my ($dateDay, $dateMonth, $dateYear) = split('/', $date);
		my %mon2num = qw(jan 01 feb 02 mar 03 apr 04 may 05 jun 06 jul 07 aug 08 sep 09 oct 10 nov 11 dec 12);
		$dateMonth = lc($dateMonth);
		$dateMonth = $mon2num{$dateMonth};

		#my $dateIso = "$dateYear-$dateMonth-$dateDay";
		my ($timeHour, $timeMinute, $timeSecond) = split(':', $time);

		# todo add comment here
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
				print "Found a message...\n";

				# The message comes after the prefix, so just trim it
				my $message = (substr($file, length($submitPrefix)));

				# Unpack from URL encoding, probably exploitable :(
				$message =~ s/\+/ /g;
				$message = uri_decode($message);
				$message = decode_entities($message);
				$message = trim($message);

				# If we're parsing a vhost log, add the site name to the message
				if ($vhostParse && $site) {
					$message .= "\n" . $site;
				}

				# Generate filename from date and time
				my $filename;
				my $filenameDir;

				# If the submission contains an @-sign, hide it into the admin dir
				# Also, if it contains the string ".onion", to curb spam @todo better solution
				if (index($message, "@") != -1) {
					$filenameDir = "$SCRIPTDIR/admin/";
					$filename = "$dateYear$dateMonth$dateDay$timeHour$timeMinute$timeSecond";

					print "I'm going to put $filename into $filenameDir because it contains an @";
				} elsif (index($message, ".onion") != -1) {
					$filenameDir = "$SCRIPTDIR/spam/";
					$filename = "$dateYear$dateMonth$dateDay$timeHour$timeMinute$timeSecond";

					print "I'm going to put $filename into $filenameDir because it contains a .onion";
				} else {
					# Prefix for new text posts
					$filenameDir = $TXTDIR;

					$filename = "$dateYear/$dateMonth/$dateDay";

					if (!-d "$TXTDIR$filename") {
						system("mkdir -p $TXTDIR$filename");
					}
					$filename .= "/$dateYear$dateMonth$dateDay$timeHour$timeMinute$timeSecond";

					print "I'm going to put $filename into $filenameDir\n";
				}

				# Make sure we don't clobber an existing file
				# If filename exists, add (1), (2), and so on
				my $filename_root = $filename;
				my $i = 0;
				while (-e $filenameDir . $filename . ".txt") {
					$i++;
					$filename = $filename_root . "(" . $i . ")";
				}
				$filename .= '.txt';

				# Try to write to the file, exit if we can't
				PutFile($filenameDir . $filename, $message) or die('Could not open text file to write to '.$filenameDir . $filename);

				# Add the file to git
				#system("git add \"$filenameDir$filename\"");
			}
		}

		# If the URL begins with "/action/" run it through the processor
		my $actionPrefix = "/action/";
		if (substr($file, 0, length($actionPrefix)) eq $actionPrefix) {

			# Put the arguments into an array
			my @actionArgs = split("/", $file);

			if ($actionArgs[2] eq 'vote') {
				my $voteFile = $actionArgs[3];
				my $voteHash = $actionArgs[4];
				my $voteValue = $actionArgs[5];

				my $voteEntry = "$voteFile|$voteHash|$voteValue";

				AppendFile("log/votes", $voteEntry);
			}
		}


	}

	# Close the log file handle
	close(LOGFILE);

	# Truncate the log file
	truncate $logfile, 0;
}

ProcessAccessLog("log/lighttpd.log", 0);

1;
