#!/usr/bin/perl -T

use strict;
use 5.010;
use utf8;

sub OrganizeFile { # $file ; renames file based on hash of its contents
	# returns new filename
	# filename is obtained using GetFileHashPath()
	my $file = shift;
	chomp $file;

	my $TXTDIR = './html/txt'; #todo

	if (!-e $file) {
		#file does not exist.
		WriteLog('OrganizeFile: warning: called on non-existing file: ' . $file);
		return '';
	}

	if (!GetConfig('admin/organize_files')) {
		WriteLog('OrganizeFile: warning: admin/organize_files was false, returning.');
		return $file;
	}

	if ($file eq "$TXTDIR/server.key.txt" || $file eq $TXTDIR || -d $file) {
		# $file should not be server.key, the txt directory, or a directory
		WriteLog('OrganizeFile: file is on ignore list, ignoring.');
		return $file;
	}

	if (GetConfig('admin/dev/block_organize')) {
		WriteLog('OrganizeFile: dev/block_organize is on, returning');
		return $file;
	}

	# organize files aka rename to hash-based path
	my $fileHashPath = GetFileHashPath($file);

	# turns out this is actually the opposite of what needs to happen
	# but this code snippet may come in handy
	# if (index($fileHashPath, $SCRIPTDIR) == 0) {
	# 	WriteLog('IndexTextFile: hash path begins with $SCRIPTDIR, removing it');
	# 	$fileHashPath = str_replace($SCRIPTDIR . '/', '', $fileHashPath);
	# } # index($fileHashPath, $SCRIPTDIR) == 0
	# else {
	# 	WriteLog('IndexTextFile: hash path does NOT begin with $SCRIPTDIR, leaving it alone');
	# }

	if ($fileHashPath) {
		use File::Spec;
		$fileHashPath = File::Spec->rel2abs( $fileHashPath ) ;

		if ($file eq $fileHashPath) {
			# Does it match? No action needed
			WriteLog('OrganizeFile: hash path matches, no action needed');
		}
		elsif ($file ne $fileHashPath) {
			# It doesn't match, fix it
			WriteLog('OrganizeFile: hash path does not match, organize');
			WriteLog('OrganizeFile: Before: ' . $file);
			WriteLog('OrganizeFile: After: ' . $fileHashPath);

			if (-e $fileHashPath) {
				# new file already exists, rename only if not larger
				WriteLog("OrganizeFile: warning: $fileHashPath already exists!");

				#todo this should be sanity-checked way before here
				if ($fileHashPath =~ m/^([0-9a-zA-Z\/\._\-]+)$/) {
					$fileHashPath = $1;
				} else {
					WriteLog('OrganizeFile: warning: $fileHashPath failed sanity check');
					return '';
				}

				if (-s $fileHashPath > -s $file) {
					unlink ($file);
				} else {
					rename ($file, $fileHashPath);
				}
			} # -e $fileHashPath
			else {
				# new file does not exist, safe to rename
				rename ($file, $fileHashPath);
			}

			# if new file exists
			if (-e $fileHashPath) {
				$file = $fileHashPath; #don't see why not... is it a problem for the calling function?
			} else {
				WriteLog("Very strange... \$fileHashPath doesn't exist? $fileHashPath");
			}
		} # $file ne $fileHashPath
		else {
			WriteLog('IndexTextFile: it already matches, next!');
			WriteLog('$file: ' . $file);
			WriteLog('$fileHashPath: ' . $fileHashPath);
		}
	} # $fileHashPath

	WriteLog("OrganizeFile: returning $file");
	return $file;
} # OrganizeFile()


sub GetFileMessage {
	my $fileHash = shift;
	if (!$fileHash) {
		return ''; #todo
	}

	if (!IsItem($fileHash) && -e $fileHash) {
		$fileHash = GetFileHash($fileHash);
	}

	WriteLog('GetFileMessage(' . $fileHash . ')');

	my $messagePath;

	if (GetConfig('admin/gpg/enable')) {
		$messagePath = GetFileMessageCachePath($fileHash) . '_gpg';
		WriteLog('GetFileMessage: $messagePath1: ' . $messagePath);
		if (-e $messagePath) {
			WriteLog('GetFileMessage: (message_gpg) return GetFile(' . $fileHash . ')');
			return GetFile($messagePath);
		}
	}

	$messagePath = GetFileMessageCachePath($fileHash);
	WriteLog('GetFileMessage: $messagePath2: ' . $messagePath);

	if (-e $messagePath) {
		WriteLog('GetFileMessage: (message) return GetFile(' . $fileHash . ')');
		return GetFile($messagePath);
	} else {
		WriteLog('GetFileMessage: return GetPathFromHash(' . $fileHash . ')');
		my $filePath = GetPathFromHash($fileHash);
		return GetFile($filePath);
	}
} # GetFileMessage()


#   R        W           R
# txt --> gpgpg --> cache/message_gpg
#                      | GetFileMessage()
#       R              v   W       R
# cache/message <-- index.pl <-- txt
#      | GetItemDetokenedMessage()
#      v W
#    pages.pl

sub PutFileMessage {
	my $fileHash = shift;
	if (!$fileHash) {
		return ''; #todo
	}
	if (!IsItem($fileHash) && -e $fileHash) {
		$fileHash = GetFileHash($fileHash);
	}

	my $message = shift;
	if (!$message) {
		return ''; #todo
	}

	return PutFile(GetFileMessageCachePath($fileHash), $message);
} # PutFileMessage()

1;
