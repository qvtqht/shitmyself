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
use Cwd qw(cwd);


sub GetTime2() { # returns epoch time
# this is identical to GetTime() in utils.pl
# #todo replace at some point
	#	return (time() + 2207520000);
	return (time());
}

# We'll use pwd for for the install root dir
#my $SCRIPTDIR = `pwd`;
my $SCRIPTDIR = cwd();
chomp $SCRIPTDIR;

# WriteLog ('Begin requires');

require './utils.pl';

my $lockTime = GetFile('cron.lock');
my $currentTime = GetTime2();

my $locked = 0;

if ($lockTime) {
	if ($currentTime - 1800 < $lockTime) {
		WriteLog('Quitting due to lock file');
		WriteMessage('Quitting due to lock file');
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
	
	# WriteLog('End requires');
	
	WriteLog('update.pl begin');
	
	my %counter;
	$counter{'access_log'} = 0;
	$counter{'indexed_file'} = 0;

	PutFile('cron.lock', $currentTime);
	$lockTime = $currentTime;
	
	# store the last time we did this from config/admin/update/last_run
	my $lastFlow = GetConfig('admin/update/last_run');
	
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
	my $timeLimit = GetConfig('admin/update/limit_time');
	my $startTime = GetTime2();
	#todo validation

	if ($timeLimit) {
		$timeLimit = 60;
	}
	
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


	# See if update/file_limit setting exists
	# This limits the number of files to process per launch of update.pl
	my $filesLimit = GetConfig('admin/update/limit_file');
	if (!$filesLimit) {
		WriteLog("WARNING: config/admin/update/limit_file missing!");
		$filesLimit = 100;
	}

	my $findCommand;
	my @files;

	#prioritize files with a public key in them
	$findCommand = 'grep -rl "BEGIN PGP PUBLIC KEY BLOCK" html/txt';
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
		WriteLog('update.pl: $file = ' . $file);
			
		#todo add rss.txt addition
	
		# If the file exists, and is not a directory, process it
		if (-e $file && !-d $file) {
			my $addedTime = GetTime2();

			WriteLog('update.pl: $addedTime = ' . $addedTime);
	
			# get file's hash from git
			my $fileHash = GetFileHash($file);

			WriteLog('update.pl: $fileHash = ' . $fileHash);
				
			# if deletion of this file has been requested, skip
			if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
				unlink($file);
				WriteLog("update.pl: $fileHash exists in deleted.log, file removed and skipped");
				next;
			}

			if (GetConfig('admin/organize_files')) {
			# organize files aka rename to hash-based path
				my $fileHashPath = GetFileHashPath($file);

				WriteLog('update.pl: $fileHashPath = ' . $fileHashPath);
				
				if ($fileHashPath && $file ne $fileHashPath) {
					WriteLog('update.pl: renaming ' . $file . ' to ' . $fileHashPath);
					rename($file, $fileHashPath);
					
					if (-e $fileHashPath) {
						$file = $fileHashPath;
					}
				}
			}

			if (GetCache('indexed/' . $fileHash)) {
				next;
			}

#			WriteLog('update.pl: DBAddAddedTimeRecord(' . $fileHash . ', ' . $addedTime . ')');
			
			# add a time_added record
#			DBAddAddedTimeRecord($fileHash, $addedTime);

			WriteLog('update.pl: IndexTextFile(' . $file . ')');

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

	WriteLog('update.pl: $filesLeft = ' . $filesLeft);

	PutConfig('admin/update/files_left', $filesLeft);

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
	
	# save current time in config/admin/update/last
	my $newLastFlow = GetTime2();
	WriteLog($newLastFlow);
	PutConfig('admin/update/last', $newLastFlow);
	
	unlink('cron.lock');
	
	WriteLog("======update.pl DONE! ======");
	WriteLog("Items/files processed: $filesProcessed");
	WriteLog("Pages processed: $pagesProcessed");

	if ($filesProcessed > 0) {
		print("Items/files processed: $filesProcessed\n");
		print("Pages processed: $pagesProcessed\n");
	}
}

1;
