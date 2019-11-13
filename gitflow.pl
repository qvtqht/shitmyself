#!/usr/bin/perl

# the purpose of this script is to
#   find new items in html/txt
#   run IndexTextFile() on them
#   re-generate affected pages
#		via the page_touch table

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

sub GetTime2() { # returns epoch time
# this is identical to GetTime() in utils.pl
# #todo replace at some point
	#	return (time() + 2207520000);
	return (time());
}

sub BuildTouchedPages {
	my $pagesLimit = GetConfig('admin/gitflow/limit_page');
	if (!$pagesLimit) {
		WriteLog("WARNING: config/admin/gitflow/limit_page missing!");
		$pagesLimit = 1000;
	}
	state $pagesProcessed;
	if (!$pagesProcessed) {
		$pagesProcessed = 1;
	}

	# get a list of pages that have been touched since the last git_flow
	# this is from the page_touch table
	my $touchedPages = DBGetTouchedPages($pagesLimit);

	# de-reference array of touched pages
	my @touchedPagesArray = @$touchedPages;

	# write number of touched pages to log
	WriteLog('scalar(@touchedPagesArray) = ' . scalar(@touchedPagesArray));

	# this part will refresh any pages that have been "touched"
	# in this case, 'touch' means when an item that affects the page
	# is updated or added
	foreach my $page (@touchedPagesArray) {
		$pagesProcessed++;
		#	if ($pagesProcessed > $pagesLimit) {
		#		WriteLog("Will not finish processing pages, as limit of $pagesLimit has been reached");
		#		last;
		#	}
		#	if ((GetTime2() - $startTime) > $timeLimit) {
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

		MakePage($pageType, $pageParam);

		DBDeletePageTouch($pageType, $pageParam);
	}

	return $pagesProcessed;
}

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print GetTime2() . " Begin requires\n";

require './utils.pl';

my $lockTime = GetFile('cron.lock');
my $currentTime = GetTime2();

my $locked = 0;

if ($lockTime) {
	if ($currentTime - 1800 < $lockTime) {
		WriteLog('Quitting due to lock file');
		$locked = 1;
	} else {
		WriteLog('Lock file exists, but old. Continuing.');
	}
}

if (!$locked) {
	require './sqlite.pl';
	require './index.pl';
	require './access.pl';
	require './pages.pl';
	
	print GetTime() . " End requires\n";
	
	WriteLog('gitflow.pl begin');
	
	my %counter;
	$counter{'access_log'} = 0;
	$counter{'indexed_file'} = 0;

	PutFile('cron.lock', $currentTime);
	$lockTime = $currentTime;
	
	# store the last time we did this from config/admin/gitflow/last_run
	my $lastFlow = GetConfig('admin/gitflow/last_run');
	
	if ($lastFlow) {
		WriteLog('$lastFlow = ' . $lastFlow);
	} else {
		WriteLog('$lastFlow undefined');
		$lastFlow = 0;
	}

	my $pagesProcessed;
	$pagesProcessed = BuildTouchedPages();
	
#	# get the path of access log, usually log/access.log
#	my $accessLogPath = GetConfig('admin/access_log_path');
#	WriteLog("\$accessLogPath = $accessLogPath");
#
	# this will store the new item count we get from access.log
	my $newItemCount;
	
	# time limit
	my $timeLimit = GetConfig('admin/gitflow/limit_time');
	my $startTime = GetTime2();
	#todo validation
	
	my $accessLogPathsConfig = GetConfig('admin/access_log_path_list');
	my @accessLogPaths;
	if ($accessLogPathsConfig) {
		@accessLogPaths = split("\n", $accessLogPathsConfig);
	} else {
		push @accessLogPaths, GetConfig('admin/access_log_path');
	}
	
	#todo re-test this
	foreach my $accessLogPath(@accessLogPaths) {
		# Check to see if access log exists
		if (-e $accessLogPath) {
			#Process the access log (access.pl)
			$newItemCount += ProcessAccessLog($accessLogPath, 0);
	
			WriteLog("Processed $accessLogPath; \$newItemCount = $newItemCount");
	
			$counter{'access_log'} += $newItemCount;
		} else {
			WriteLog("WARNING: Could not find $accessLogPath");
		}
	}

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


	# See if gitflow/file_limit setting exists
	# This limits the number of files to process per launch of gitflow.pl
	my $filesLimit = GetConfig('admin/gitflow/limit_file');
	if (!$filesLimit) {
		WriteLog("WARNING: config/admin/gitflow/limit_file missing!");
		$filesLimit = 100;
	}

	my $findCommand;
	my @files;


	$findCommand = 'grep -rl "PUBLIC KEY" html/txt';
	push @files, split("\n", `$findCommand`);

	$findCommand = 'find html/txt | grep -i txt$';
	push @files, split("\n", `$findCommand`);

	my $filesProcessed = 0;


	# Go through all the changed files
	foreach my $file (@files) {
		if ($filesProcessed >= $filesLimit) {
			WriteLog("Will not finish processing files, as limit of $filesLimit has been reached.");
			last;
		}
	
		if ((GetTime2() - $startTime) > $timeLimit) {
			WriteLog("Time limit reached, exiting loop");
			last;
		}
		
		# Trim the file path
		chomp $file;
		$file = trim($file);
		
		# Log it
		WriteLog('gitflow.pl: $file = ' . $file);
			
		#todo add rss.txt addition
	
		# If the file exists, and is not a directory, process it
		if (-e $file && !-d $file) {
			my $addedTime = GetTime2();

			WriteLog('gitflow.pl: $addedTime = ' . $addedTime); 
	
			# get file's hash from git
			my $fileHash = GetFileHash($file);

			WriteLog('gitflow.pl: $fileHash = ' . $fileHash); 
				
			# if deletion of this file has been requested, skip
			if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
				unlink($file);
				WriteLog("gitflow.pl: $fileHash exists in deleted.log, file removed and skipped");
				next;
			}

			if (GetConfig('admin/organize_files')) {
			# organize files aka rename to hash-based path
				my $fileHashPath = GetFileHashPath($file);

				WriteLog('gitflow.pl: $fileHashPath = ' . $fileHashPath);
				
				if ($fileHashPath && $file ne $fileHashPath) {
					WriteLog('gitflow.pl: renaming ' . $file . ' to ' . $fileHashPath);
					rename($file, $fileHashPath);
					
					if (-e $fileHashPath) {
						$file = $fileHashPath;
					}
				}
			}

			if (GetCache('indexed/' . $fileHash)) {
				next;
			}

#			WriteLog('gitflow.pl: DBAddAddedTimeRecord(' . $fileHash . ', ' . $addedTime . ')');
			
			# add a time_added record
#			DBAddAddedTimeRecord($fileHash, $addedTime);

			WriteLog('gitflow.pl: IndexTextFile(' . $file . ')');

			IndexTextFile($file);

			PutCache('indexed/' . $fileHash, 1);

			# Add to counter
			$filesProcessed++;

			# run commands to
			#	  add changed file to git repo
			#    commit the change with message 'hi' #todo
			#    cd back to pwd

	
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
			WriteLog("Error! $file doesn't exist!");
		}
	}

	IndexTextFile('flush');
	
	WriteIndexedConfig();
	
	RemoveEmptyDirectories('./html/'); #includes txt/
	#RemoveEmptyDirectories('./txt/');

	my $filesLeftCommand = 'find html/txt | grep "\.txt$" | wc -l';
	my $filesLeft = `$filesLeftCommand`; #todo

	WriteLog('gitflow.pl: $filesLeft = ' . $filesLeft);

	PutConfig('admin/gitflow/files_left', $filesLeft);

	# if new items were added, re-make all the summary pages (top authors, new threads, etc)
	if ($filesProcessed > 0) {
		UpdateUpdateTime();
		MakeSummaryPages();
	#	WriteIndexPages();
	}


	# if anything has changed, redo the abyss index pages
	#if ($newItemCount) {
		#WriteIndexPages();
	#}
	
	## rebuild abyss pages no more than once an hour (default/admin/abyss_rebuild_interval)
	#my $lastAbyssRebuild = GetConfig('last_abyss');
	#my $abyssRebuildInterval = GetConfig('admin/abyss_rebuild_interval');
	#my $curTime = GetTime2();
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

	$pagesProcessed = BuildTouchedPages();
	
	# save current time in config/admin/gitflow/last
	my $newLastFlow = GetTime2();
	WriteLog($newLastFlow);
	PutConfig('admin/gitflow/last', $newLastFlow);
	
	unlink('cron.lock');
	
	WriteLog("======gitflow.pl DONE! ======");
	WriteLog("Items/files processed: $filesProcessed");
	print("Items/files processed: $filesProcessed\n");
	WriteLog("Pages processed: $pagesProcessed");
	print("Pages processed: $pagesProcessed\n");
}

1;
