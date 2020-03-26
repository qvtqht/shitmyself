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
use File::Spec; #todo

my $arg1 = shift;

if ($arg1) {
	print($arg1 . "\n");
} else {
	print ("arg1 missing\n\nplease specify --all or name of file\n");
}

require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

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
require './index.pl';

my $lockTime = GetFile('cron.lock');
my $currentTime = GetTime2();

my $locked = 0;

sub ProcessTextFile { #add new textfile to index
	my $file = shift;

	my $relativePath = File::Spec->abs2rel ($file,  $SCRIPTDIR);
	if ($file ne $relativePath) {
		$file = $relativePath;
	}

	my $addedTime = GetTime2();

	WriteLog('ProcessTextFile: $file = ' . $file . '; $addedTime = ' . $addedTime);

	# get file's hash from git
	my $fileHash = GetFileHash($file);

	WriteLog('ProcessTextFile: $fileHash = ' . $fileHash);

	# if deletion of this file has been requested, skip
	if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
		unlink($file);
		WriteLog("ProcessTextFile: $fileHash exists in deleted.log, file removed and skipped");

		WriteLog('ProcessTextFile: return 0');
		return 0;
	} else {
		WriteLog("ProcessTextFile: $fileHash was not in log/deleted.log, continuing");
	}

	if (GetConfig('admin/organize_files')) {
		# organize files aka rename to hash-based path
		my $fileHashPath = GetFileHashPath($file);

		WriteLog('ProcessTextFile: organize: $file = ' . $file . '; $fileHashPath = ' . $fileHashPath);

		if ($fileHashPath) {
			WriteLog('ProcessTextFile: $fileHashPath = ' . $fileHashPath);

			if (-e $fileHashPath) {
				WriteLog('ProcessTextFile: Warning: file already exists = ' . $fileHashPath);
			}

			if ($fileHashPath && $file ne $fileHashPath) {
				WriteLog('ProcessTextFile: renaming ' . $file . ' to ' . $fileHashPath);
				rename($file, $fileHashPath);

				if (-e $fileHashPath) {
					WriteLog('ProcessTextFile: rename succeeded, changing value of $file');

					$file = $fileHashPath;

					WriteLog('ProcessTextFile: $file is now ' . $file);
				}
			} else {
				WriteLog('ProcessTextFile: did not need to rename ' . $file);
			}
		} else {
			WriteLog('ProcessTextFile: $fileHashPath is missing');
		}
	} else {
		WriteLog("ProcessTextFile: organize_files is off, continuing");
	}

	if (!GetCache('indexed/' . $fileHash)) {
		WriteLog('ProcessTextFile: ProcessTextFile (' . $file . ') not in cache/indexed, calling IndexTextFile');

		IndexTextFile($file);

		PutCache('indexed/' . $fileHash, '1');
	} else {
		# return 0 so that this file is not counted
		WriteLog('ProcessTextFile: return 0');
		return 0;
	}

	WriteLog('ProcessTextFile: return 1');
	return 1;

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

}

if (!$arg1) {
	print "must supply filename or --all\n";
} elsif ($arg1 eq '--all') {
	require './sqlite.pl';
	require './index.pl';
	require './access.pl';
	require './pages.pl';

	if (!$locked) {
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
		}
		else {
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
		}
		else {
			push @accessLogPaths, GetConfig('admin/access_log_path');
		}

		#todo re-test this
		foreach my $accessLogPath (@accessLogPaths) {
			# Check to see if access log exists
			if (-e $accessLogPath) {
				#Process the access log (access.pl)
				$newItemCount += ProcessAccessLog($accessLogPath, 0);

				WriteLog("Processed $accessLogPath; \$newItemCount = $newItemCount");

				$counter{'access_log'} += $newItemCount;
			}
			else {
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

		if ($filesLimit > scalar(@files)) {
			$filesLimit = scalar(@files);
		}

		# Go through all the changed files
		foreach my $file (@files) {
			if ($filesProcessed >= $filesLimit) {
				WriteLog("Will not finish processing files, as limit of $filesLimit has been reached.");
				last;
			}

			WriteMessage('ProcessTextFile: ' . $filesProcessed . '/' . $filesLimit . '; $file = ' . $file);

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
				$filesProcessed += ProcessTextFile($file);
			}
			else {
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

		WriteLog('update.pl: Building touched pages...');

		$pagesProcessed = BuildTouchedPages();

		WriteLog('Saving last update time...');

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
} elsif ($arg1) {
	WriteLog('Found argument ' . $arg1);

	if (-e $arg1) {
		WriteLog('File ' . $arg1 . ' exists, calling ProcessTextFile()');

		my $filesProcessed = ProcessTextFile($arg1);

		if ($filesProcessed > 0) {
			IndexTextFile('flush');

			WriteIndexedConfig();

			MakeSummaryPages();

			my $pagesProcessed = BuildTouchedPages();
		}

		unlink('cron.lock');
	} else {
		print('File ' . $arg1 . ' DOES NOT EXIST' . "\n");
		WriteLog('File ' . $arg1 . ' DOES NOT EXIST');
	}
}

1;