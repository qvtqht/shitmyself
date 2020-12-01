#!/usr/bin/perl

# the purpose of this script is to
#   find new items
#   run IndexTextFile() on them
#   re-generate affected pages
#		via the task table

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;
use Cwd qw(cwd);
use File::Spec; #todo

my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/image';

my $arg1 = shift;

if ($arg1) {
	print($arg1 . "\n");
} else {
	print ("arg1 missing, assuming shallow update is requested\n");
}

require './utils.pl';

sub GetTime2 () { # returns epoch time
	# this should be identical to GetTime() in utils.pl
	#	return (time() + 2207520000);
	return (time());
}

my $lockTime = GetFile('cron.lock');
my $currentTime = GetTime2();

if ($lockTime) {
	$lockTime = trim($lockTime);
	my $lockedSince = $currentTime - $lockTime;
	if ($lockedSince && $lockedSince < 120) {
		print 'Quitting due to lock file';
		WriteLog('update.pl: quitting because locked');
		exit;
	}
}

PutFile('cron.lock', GetTime2());

require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

################################

UnlinkCache('count_txt');
UnlinkCache('count_image');

# WriteLog('Begin requires');

sub ProcessImageFile { # $file ; add new image to index
	WriteLog('ProcessImageFile() begins');

	my $file = shift;

	my $relativePath = File::Spec->abs2rel ($file,  $SCRIPTDIR);
	if ($file ne $relativePath) {
		$file = $relativePath;
	}

	my $addedTime = GetTime2();

	WriteLog('ProcessImageFile: $file = ' . $file . '; $addedTime = ' . $addedTime);

	# get file's hash from git
	my $fileHash = GetFileHash($file);

	if (!$fileHash) {
		return 0;
	}

	WriteLog('ProcessImageFile: $fileHash = ' . $fileHash);

	if (IsFileDeleted($file, $fileHash)) {
		# if deletion of this file has been requested, skip
		WriteLog("ProcessImageFile: IsFileDeleted() returned true, skipping");
		WriteLog('ProcessImageFile: return 0');

		return 0;
	}

	# if (GetConfig('admin/organize_files')) {
	# 	# organize files aka rename to hash-based path
	# 	my $fileHashPath = GetFileHashPath($file);
	#
	# 	WriteLog('ProcessImageFile: organize: $file = ' . $file . '; $fileHashPath = ' . $fileHashPath);
	#
	# 	if ($fileHashPath) {
	# 		WriteLog('ProcessImageFile: $fileHashPath = ' . $fileHashPath);
	#
	# 		if (-e $fileHashPath) {
	# 			WriteLog('ProcessImageFile: Warning: file already exists = ' . $fileHashPath);
	# 		}
	#
	# 		if ($fileHashPath && $file ne $fileHashPath) {
	# 			WriteLog('ProcessImageFile: renaming ' . $file . ' to ' . $fileHashPath);
	# 			rename($file, $fileHashPath);
	#
	# 			if (-e $fileHashPath) {
	# 				WriteLog('ProcessImageFile: rename succeeded, changing value of $file');
	#
	# 				$file = $fileHashPath;
	#
	# 				WriteLog('ProcessImageFile: $file is now ' . $file);
	# 			} else {
	# 				WriteLog("ProcessImageFile: WARNING: rename failed, from $file to $fileHashPath");
	# 			}
	# 		} else {
	# 			WriteLog('ProcessImageFile: did not need to rename ' . $file);
	# 		}
	# 	} else {
	# 		WriteLog('ProcessImageFile: $fileHashPath is missing');
	# 	}
	# } else {
	# 	WriteLog("ProcessImageFile: organize_files is off, continuing");
	# }

	if (!GetCache('indexed/' . $fileHash)) {
		WriteLog('ProcessImageFile: ProcessImageFile(' . $file . ') not in cache/indexed, calling IndexImageFile');

		IndexImageFile($file);
		IndexImageFile('flush');

		PutCache('indexed/' . $fileHash, '1');
	} else {
		# return 0 so that this file is not counted
		WriteLog('ProcessImageFile: return 0');
		return 0;
	}

	WriteLog('ProcessImageFile: return ' . $fileHash);
	return $fileHash;
}

# if (!$arg1) {
# 	print "must supply filename or --all\n";
# }
if (!defined($arg1) || $arg1 eq '--all') {
	require './sqlite.pl';
	require './index.pl';
	require './access.pl';
	require './pages.pl';

	my $noLimits = 0;
	if (defined($arg1) && $arg1 eq '--all') {
		$noLimits = 1;
	}

	WriteLog('update.pl begin');
	#
	# my %counter;
	# $counter{'access_log'} = 0;
	# $counter{'indexed_file'} = 0;

	PutFile('cron.lock', $currentTime);
	$lockTime = $currentTime;

	# store the last time we did this from config/admin/update/last_run
	my $lastFlow = GetConfig('admin/update/last_run');

	if ($lastFlow) {
		WriteLog('update.pl: $lastFlow = ' . $lastFlow);
	}
	else {
		WriteLog('update.pl: $lastFlow undefined');
		$lastFlow = 0;
	}

	# this will store the new item count we get from access.log
	my $newItemCount = 0;

	# time limit -- how long this script is allowed to run for
	my $timeLimit = GetConfig('admin/update/limit_time');
	#todo validation

	# time the script started (now)
	my $startTime = time();

	if (!$timeLimit) {
		# default to 10 seconds
		WriteLog('update.pl: config/admin/update/limit_time not found, defaulting to 10 seconds');
		$timeLimit = 10;
	}

	if ((time()-(GetConfig('admin/access_log_last_seen')||0)) > 5) { #todo make this more configurable
		#do not process access.log more than once per 5 seconds
		PutConfig('admin/access_log/last_seen', time());
		WriteMessage('update.pl: Calling ProcessAllAccessLogsInConfig...');
		$newItemCount .= ProcessAllAccessLogsInConfig();
	} # access.log/access.pl

	{ # sanity checks: $HTMLDIR and $TXTDIR should exist
		if (!-e $HTMLDIR) {
			system("mkdir $HTMLDIR");
		}

		if (!-d $HTMLDIR) {
			WriteLog("Problem? $HTMLDIR is not a directory!");
		}

		if (!-e $TXTDIR) {
			system("mkdir $TXTDIR");
		}

		if (!-d $TXTDIR) {
			WriteLog("Problem? $TXTDIR is not a directory!");
		}
	}

	my $filesProcessedTotal = 0;
	my $filesProcessed = 1;
	my $pagesProcessed = 0;

	$pagesProcessed = BuildTouchedPages($timeLimit, $startTime);

	# See if update/file_limit setting exists
	# This limits the number of files to process per launch of update.pl
	my $filesLimit = GetConfig('admin/update/limit_file');
	if (!$filesLimit) {
		WriteLog('WARNING: admin/update/limit_file missing, using 100');
		$filesLimit = 100;
	}

	# this loop alternates processing batches of new files and new pages until there's nothing left to do
	while ($filesProcessed > 0 || $pagesProcessed > 1) {
		WriteLog('while loop: $filesProcessed: ' . $filesProcessed . '; $pagesProcessed: ' . $pagesProcessed);

		if (!$noLimits && (time() - $startTime) > $timeLimit) {
			WriteMessage("Time limit reached, exiting loop");
			last;
		}

		$filesProcessed = 0;
		$pagesProcessed = 0;

		{
			############
			# TEXT FILE PROCESSING PART BEGINS HERE

			my $findCommand;
			my @files;

			# prioritize files with a public key
			$findCommand = 'grep -rl "BEGIN PGP PUBLIC KEY BLOCK" ' . $TXTDIR;
			push @files, split("\n", `$findCommand`);

			# prioritize files with a #config token
			$findCommand = 'grep -rl "#config" ' . $TXTDIR;
			push @files, split("\n", `$findCommand`);

			# add all other text files
			$findCommand = "find $TXTDIR | grep -i \.txt\$";
			push @files, split("\n", `$findCommand`);

			# Go through all the files
			foreach my $file (@files) {
				if ($filesProcessed >= $filesLimit) {
					WriteLog("update.pl: Will not finish processing files, as limit of $filesLimit has been reached.");
					last;
				}

				if (!$noLimits && (time() - $startTime) > $timeLimit) {
					WriteMessage("update.pl: Time limit reached, exiting loop");
					last;
				}

				# Trim the file path
				chomp $file;
				$file = trim($file);

				#todo add rss.txt addition

				# If the file exists, and is not a directory, process it
				if (-e $file && !-d $file) {
					WriteMessage('update.pl: ProcessTextFile: ' . $filesProcessed . '/' . $filesLimit . '; $file = ' . $file);
					$filesProcessed += (ProcessTextFile($file) ? 1 : 0);
				} else {
					WriteMessage('update.pl: warning: file sanity check: $file = ' . $file);
				}
			} # @files

			ProcessTextFile('flush');
			WriteIndexedConfig();

			# TEXT FILE PROCESSING PART ENDS HERE
			############
		}
		#####

		if (-e $IMAGEDIR) {
			###########
			# IMAGE FILE PROCESSING PART BEGINS HERE

			my $findCommand;
			my @files;

			# todo figure out why we're not here already #bug
			WriteLog('update.pl: ImageProcessing: pwd = ' . `pwd`);

			WriteLog("update.pl: ImageProcessing: cd $SCRIPTDIR");
			WriteLog(`cd "$SCRIPTDIR"`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.png\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.gif\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.jpg\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.bmp\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.svg\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.jfif\\\$";
			push @files, split("\n", `$findCommand`);

			$findCommand = "find \"$IMAGEDIR\" | grep -i \\\.webp\\\$";
			push @files, split("\n", `$findCommand`);
			#todo config/admin/upload/allow_files


			# Go through all the changed files
			foreach my $file (@files) {
				if ($filesProcessed >= $filesLimit) {
					WriteLog("Will not finish processing files, as limit of $filesLimit has been reached.");
					last;
				}

				if (!$noLimits && (time() - $startTime) > $timeLimit) {
					WriteMessage("Time limit reached, exiting loop");
					last;
				}

				WriteMessage('ProcessImageFile: ' . $filesProcessed . '/' . $filesLimit . '; $file = ' . $file);

				# Trim the file path
				chomp $file;
				$file = trim($file);

				# Log it
				WriteLog('update.pl: image: $file = ' . $file);

				#todo add rss.txt addition

				# If the file exists, and is not a directory, process it
				if (-e $file && !-d $file) {
					$filesProcessed += (ProcessImageFile($file) ? 1 : 0);
				} else {
					# this should not happen
					WriteLog('update.pl: warning: sanity check failed on $file = ' . $file);
				}
			}

			IndexImageFile('flush');

			# IMAGE FILE PROCESSING PART ENDS HERE
			###########
		} # if (-e $IMAGEDIR)

		#####

		RemoveEmptyDirectories($TXTDIR);
		RemoveEmptyDirectories($IMAGEDIR);
		#RemoveEmptyDirectories('./txt/');

		# if new items were added, re-make all the summary pages (top authors, new threads, etc)
		if ($filesProcessed > 0) {
			WriteLog('update.pl: $filesProcessed > 0, calling UpdateUpdateTime() and MakeSummaryPages()...');

			UpdateUpdateTime();
			MakeSummaryPages();
			WriteIndexPages();
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

		WriteLog('update.pl: Building touched pages... $pagesProcessed = ' . $pagesProcessed);

		if ($noLimits) {
			$pagesProcessed += BuildTouchedPages();
		} else {
			$pagesProcessed += BuildTouchedPages($timeLimit, $startTime);
		}
		WriteLog('update.pl: Finished building touched pages... $pagesProcessed = ' . $pagesProcessed);

		$filesProcessedTotal += $filesProcessed;

	} # while ($filesProcessed > 0 || $pagesProcessed > 1)

	WriteLog('update.pl: Returned from: $pagesProcessed = BuildTouchedPages(); $pagesProcessed = ' . (defined($pagesProcessed) ? $pagesProcessed : 'undefined'));

	WriteLog('update.pl: Saving last update time...');

	# save current time in config/admin/update/last
	my $newLastFlow = GetTime2();
	WriteLog($newLastFlow);
	PutConfig('admin/update/last', $newLastFlow);

	PutFile('cron.lock', '0');

	WriteLog("======update.pl DONE! ======");
	WriteLog("Items/files processed: $filesProcessed");
	WriteLog("Pages processed: $pagesProcessed");
} # elsif ($arg1 eq '--all')
elsif ($arg1) {
	WriteLog('Found argument ' . $arg1);

	if (-e $arg1 && length($arg1) > 5) {
		# file exists, let's update what's related to it

		WriteLog('File ' . $arg1 . ' exists');

		if (IsTextFile($arg1)) { #$arg1 =~ m/\.txt$/
			my $fileProcessed = ProcessTextFile($arg1);
			if ($fileProcessed) {
				IndexTextFile('flush');
				WriteIndexedConfig();
				MakePage('item', $fileProcessed, 1);
			}
		}

		if (IsImageFile($arg1)) {
			my $fileProcessed = ProcessImageFile($arg1);
			if ($fileProcessed) {
				IndexImageFile('flush');
				MakeSummaryPages();
				MakePage('item', $fileProcessed, 1);
			}
		}

		PutFile('cron.lock', '0');
	} # if (-e $arg1 && length($arg1) > 5)
	else {
		print('File ' . $arg1 . ' DOES NOT EXIST' . "\n");
		WriteLog('File ' . $arg1 . ' DOES NOT EXIST');
	}
} # elsif ($arg1)

if (-e 'cron.lock') {
	PutFile('cron.lock', '0');
}

WriteMessage("update.pl: Done!\n\n");

1;