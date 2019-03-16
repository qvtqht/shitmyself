#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

require './utils.pl';
require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

WriteLog('gitflow.pl begin');

# get the path of access log, usually log/access.log
my $accessLogPath = GetConfig('access_log_path');
WriteLog("\$accessLogPath = $accessLogPath");

# Check to see if access log exists
if (-e $accessLogPath) {
	#Process the access log (access.pl)
	my $newItemCount = ProcessAccessLog($accessLogPath, 0);

	WriteLog("Processed $accessLogPath; \$newItemCount = $newItemCount");
} else {
	WriteLog("WARNING: Could not find $accessLogPath");
}

# Use git to find files that have changed in txt/ directory
my $gitChanges = `cd ./html/txt; git add . ; git status --porcelain | grep "^A" | cut -c 4-; cd ../..`;

# Get an array of changed files that git returned
my @gitChangesArray = split("\n", $gitChanges);

# We don't need to run generate.pl unless something has changed,
# which we will check for below
# use $runGeneratePl to keep track of it.
my $runGeneratePl = 0;

foreach my $file (@gitChangesArray) {
	# Trim the file path
	$file = trim($file);

	# Add the txt/ path prefix
	my $fileFullPath = "./html/txt/" . $file;

	# Log it
	WriteLog('$file = ' . $file . " ($fileFullPath)");

	#todo add rss.txt addition

	# If the file exists, and is not a directory, process it
	if (-e $fileFullPath && !-d $fileFullPath) {
		my $addedTime = time();

		IndexFile($fileFullPath);
		IndexFile('flush');

		my $fileHash = GetFileHash($fileFullPath);

		DBAddAddedTimeRecord($fileHash, $addedTime);

		WriteLog("cd ./html/txt; git add \"$file\"; git commit -m hi \"$file\"; cd -");
		my $gitCommit = `cd ./html/txt; git add "$file"; git commit -m hi "$file"; cd -`;

		WriteLog($gitCommit);

		my %queryParams;
		$queryParams{'where_clause'} = "WHERE file_hash = '$fileHash'";

		my @files = DBGetItemList(\%queryParams);

		WriteLog ("Count of new items for $fileHash : " . scalar(@files));

		foreach my $file (@files) {
			my $itemPage = GetItemPage($file);

			PutHtmlFile("./html/$fileHash.html", $itemPage);
		}

#		my $htmlFilename = $fileHash . ".html";
#		my $filePage = GetItemPage($fileHash);

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("gitflow.pl: $fileHash exists in deleted.log, skipping");
			next;
		}

		#my $newFile = DBGetItemList()

		$runGeneratePl = 1;
	} else {
		WriteLog("Strange... $file doesn't exist? Oh well...");
	}
}

if ($runGeneratePl) {
	#system('perl generate.pl');
}
