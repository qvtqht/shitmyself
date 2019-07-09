#!/usr/bin/perl

# the purpose of this script is to
#   find new items in html/txt
#   run IndexFile() on them
#   re-generate affected pages
#		via the page_touch table

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print time() . " Begin requires\n";

require './utils.pl';
require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

print time() . " End requires\n";

WriteLog('gitflow.pl begin');

my %counter;
$counter{'access_log'} = 0;
$counter{'indexed_file'} = 0;

my $lockTime = GetFile('cron.lock');
my $currentTime = time();

if ($lockTime) {
	if ($currentTime - 1800 < $lockTime) {
		WriteLog('Quitting due to lock file');
		die();
	} else {
		WriteLog('Lock file exists, but old. Continuing.');
	}
}
PutFile('cron.lock', $currentTime);
$lockTime = $currentTime;

# store the last time we did this from config/admin/gitflow_last
my $lastFlow = GetConfig('admin/gitflow_last');

if ($lastFlow) {
	WriteLog('$lastFlow = ' . $lastFlow);
} else {
	WriteLog('$lastFlow undefined');
	$lastFlow = 0;
}

# get the path of access log, usually log/access.log
my $accessLogPath = GetConfig('admin/access_log_path');
WriteLog("\$accessLogPath = $accessLogPath");

# this will store the new item count we get from access.log
my $newItemCount;

# time limit
my $timeLimit = GetConfig('admin/gitflow_time_limit');
my $startTime = time();
#todo validation

# Check to see if access log exists
if (-e $accessLogPath) {
	#Process the access log (access.pl)
	$newItemCount += ProcessAccessLog($accessLogPath, 0);

	WriteLog("Processed $accessLogPath; \$newItemCount = $newItemCount");

	$counter{'access_log'} += $newItemCount;
} else {
	WriteLog("WARNING: Could not find $accessLogPath");
}

# check if html/txt/ has its own git repository
# init a new repo in html/txt/ if html/txt/.git/ is missing

if (!-e 'html') {
	system('mkdir html');
}

if (!-d 'html') {
	WriteLog('Problem!!! html is not a directory!');
}

if (!-e 'html/txt') {
	system('mkdir html/txt');
}

if (!-d 'html/txt') {
	WriteLog('Problem!!! html/txt is not a directory!');
}

if (!-e 'html/txt/.git') {
	my $pwd = `pwd`;

	WriteLog("cd html/txt; git init; cd $pwd");

	my $gitOutput = `cd html/txt; git init; git add *; git commit -m first commit; cd $pwd`;

	WriteLog($gitOutput);
}

# Use git to find files that have changed in txt/ directory
my $gitChanges = `cd html/txt; git add . ; git status --porcelain | grep "^A" | cut -c 4-; cd ../..`;

WriteLog('$gitChanges = ' . $gitChanges);

# Get an array of changed files that git returned
my @gitChangesArray = split("\n", $gitChanges);

# Log number of changes
WriteLog('scalar(@gitChangesArray) = ' . scalar(@gitChangesArray));

# See if gitflow_file_limit setting exists
# This limits the number of files to process per launch of gitflow.pl
my $filesLimit = GetConfig('admin/gitflow_file_limit');
if (!$filesLimit) {
	WriteLog("WARNING: config/admin/gitflow_file_limit missing!");
	$filesLimit = 100;
}

# Keep track of how many files we've processed
my $filesProcessed = 0;

# Go through all the changed files
foreach my $file (@gitChangesArray) {
	# Add to counter
	$filesProcessed++;
	if ($filesProcessed > $filesLimit) {
		WriteLog("Will not finish processing files, as limit of $filesLimit has been reached.");
		last;
	}

	if ((time() - $startTime) > $timeLimit) {
		WriteLog("Time limit reached, exiting loop");
		last;
	}

	# Trim the file path
	$file = trim($file);

	# Add the txt/ path prefix
	my $fileFullPath = 'html/txt/' . $file;

	# Log it
	WriteLog('$file = ' . $file . " ($fileFullPath)");

	#todo add rss.txt addition

	# If the file exists, and is not a directory, process it
	if (-e $fileFullPath && !-d $fileFullPath) {
		my $addedTime = time();

		# get file's hash from git
		my $fileHash = GetFileHash($fileFullPath);

		# if deletion of this file has been requested, skip
		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			unlink($fileFullPath);
			WriteLog("gitflow.pl: $fileHash exists in deleted.log, skipping");
			next;
		}

		my $fileHashPath;
		# may need to check if file has been renamed
		if (GetConfig('admin/organize_files')) {
			$fileHashPath = GetFileHashPath($fileFullPath);
		}

		# index file, flush immediately (why? #todo)
		IndexTextFile($fileFullPath);
		IndexTextFile('flush');

		# check if file has been renamed
		if (GetConfig('admin/organize_files') && $fileHashPath) {
			if (!-e $fileFullPath) {
				if (-e $fileHashPath) {
					$fileFullPath = $fileHashPath;
				}
			}
		}

		# add a time_added record
		DBAddAddedTimeRecord($fileHash, $addedTime);

		# remember pwd (current working directory);
		my $pwd = `pwd`;

		# run commands to
		#	  add changed file to git repo
		#    commit the change with message 'hi' #todo
		#    cd back to pwd
		WriteLog("cd html/txt; git add \"$file\"; git commit -m hi \"$file\"; cd $pwd");
		my $gitCommit = `cd html/txt; git add "$file"; git commit -m hi "$file"; cd $pwd`;

		# write git's output to log
		WriteLog($gitCommit);

#		# below is for debugging purposes
#
#		my %queryParams;
#		$queryParams{'where_clause'} = "WHERE file_hash = '$fileHash'";
#
#		my @files = DBGetItemList(\%queryParams);
#
#		WriteLog ("Count of new items for $fileHash : " . scalar(@files));
	} else {
		# this should not happen
		WriteLog("Error! $fileFullPath doesn't exist!");
	}
}

WriteIndexedConfig();

# get a list of pages that have been touched since the last git_flow
# this is from the page_touch table
my $touchedPages = DBGetTouchedPages($lastFlow);

# de-reference array of touched pages
my @touchedPagesArray = @$touchedPages;

# write number of touched pages to log
WriteLog('scalar(@touchedPagesArray) = ' . scalar(@touchedPagesArray));

my $pagesLimit = GetConfig('admin/gitflow_page_limit');
if (!$pagesLimit) {
	WriteLog("WARNING: config/admin/gitflow_page_limit missing!");
	$pagesLimit = 100;
}
my $pagesProcessed = 0;

# this part will refresh any pages that have been "touched"
# in this case, 'touch' means when an item that affects the page
# is updated or added
foreach my $page (@touchedPagesArray) {
#	$pagesProcessed++;
#	if ($pagesProcessed > $pagesLimit) {
#		WriteLog("Will not finish processing pages, as limit of $pagesLimit has been reached");
#		last;
#	}
#	if ((time() - $startTime) > $timeLimit) {
#		WriteLog("Time limit reached, exiting loop");
#		last;
#	}

	# dereference @pageArray
	my @pageArray = @$page;

	# get the 3 items in it
	my $pageType = shift @pageArray;
	my $pageParam = shift @pageArray;
	my $touchTime = shift @pageArray;

	# output to log
	WriteLog("\$pageType = $pageType");
	WriteLog("\$pageParam = $pageParam");
	WriteLog("\$touchTime = $touchTime");

	# tag page, get the tag name from $pageParam
	if ($pageType eq 'tag') {
		my $tagName = $pageParam;

		WriteLog("gitflow.pl \$pageType = $pageType; \$pageParam = \$tagName = $pageParam");

		my $tagPage = GetReadPage('tag', $tagName);
		PutHtmlFile('html/top/' . $tagName . '.html', $tagPage);
	}
	#
	# author page, get author's id from $pageParam
	elsif ($pageType eq 'author') {
		my $authorKey = $pageParam;

		my $authorPage = GetReadPage('author', $authorKey);

		if (!-e 'html/author/' . $authorKey) {
			mkdir ('html/author/' . $authorKey);
		}

		PutHtmlFile('html/author/' . $authorKey . '/index.html', $authorPage);
	}
   #
	# if $pageType eq item, generate that item's page
	elsif ($pageType eq 'item') {
		# get the item's hash from the param field
		my $fileHash = $pageParam;

		# get item list using DBGetItemList()
		# #todo clean this up a little, perhaps crete DBGetItem()
		my @files = DBGetItemList({'where_clause' => "WHERE file_hash = '$fileHash'"});

		if (scalar(@files)) {
			my $file = $files[0];

			# get item page's path #todo refactor this into a function
			#my $targetPath = 'html/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
			my $targetPath = 'html/' .GetHtmlFilename($fileHash);

			# create a subdir for the first 2 characters of its hash if it doesn't exist already
			if (!-e 'html/' . substr($fileHash, 0, 2)) {
				mkdir('html/' . substr($fileHash, 0, 2));
			}

			# get the page for this item and write it
			my $filePage = GetItemPage($file);
			PutHtmlFile($targetPath, $filePage);
		} else {
			WriteLog("gitflow.pl: Asked to index file $fileHash, but it is not in the database! Quitting.");
		}
	}
   #
	# tags page
	elsif ($pageType eq 'tags') {
		my $votesPage = GetVotesPage();
		PutHtmlFile("html/tags.html", $votesPage);
	}
	#
	# scores page
	elsif ($pageType eq 'scores') {
		my $scoresPage = GetScoreboardPage();
		PutHtmlFile('html/scores.html', $scoresPage);
	}
	#
	# topitems page
	elsif ($pageType eq 'top') {
		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile('html/top.html', $topItemsPage);
	}
	#
	# stats page
	elsif ($pageType eq 'stats') {
		my $statsPage = GetStatsPage();
		PutHtmlFile('html/stats.html', $statsPage);
	}
	#
	# index pages (abyss)
	elsif ($pageType eq 'index') {
		WriteIndexPages();
	}
}

# if anything has changed, redo the abyss index pages
#if ($newItemCount) {
	#WriteIndexPages();
#}

## rebuild abyss pages no more than once an hour (default/admin/abyss_rebuild_interval)
#my $lastAbyssRebuild = GetConfig('last_abyss');
#my $abyssRebuildInterval = GetConfig('admin/abyss_rebuild_interval');
#my $curTime = time();
#
#WriteLog("Abyss was last rebuilt at $lastAbyssRebuild, and now it is $curTime");
#if (!($lastAbyssRebuild =~ /^[0-9]+/)) {
#	$lastAbyssRebuild = 0;
#}
#if ((!$lastAbyssRebuild) || (($lastAbyssRebuild + $abyssRebuildInterval) < $curTime)) {
#	WriteLog("Rebuilding Abyss, because " . ($lastAbyssRebuild + 86400) . " < " . $curTime);
#	WriteIndexPages();
#	PutConfig('last_abyss', $curTime);
#}

# save current time in config/admin/gitflow_last
my $newLastFlow = time();
WriteLog($newLastFlow);
PutConfig('admin/gitflow_last', $newLastFlow);

unlink('cron.lock');

1;
