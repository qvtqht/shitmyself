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

WriteLog("Hello, World!");

my $accessLogPath = GetConfig('access_log_path');
WriteLog("\$accessLogPath = $accessLogPath");

my $newItemCount = ProcessAccessLog($accessLogPath, 0);

WriteLog("\$newItemCount = $newItemCount");

#my $gitChanges = `cd ./html/txt; git status --porcelain; cd ../..`;
my $gitChanges = `cd ./html/txt; git add . ; git status --porcelain | grep "^A" | cut -c 4-; cd ../..`;
#todo less janky

my @gitChangesArray = split("\n", $gitChanges);

my $runGeneratePl = 0;

foreach my $file (@gitChangesArray) {
	WriteLog('$file = ' . $file);

	$file = trim($file);
#	$file =~ s/^.. //;
#	$file = trim($file);

	WriteLog('$file = ' . $file);

	my $fileFullPath = "./html/txt/" . $file;

	WriteLog('$file = ' . $file);

	#todo add rss.txt addition

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
