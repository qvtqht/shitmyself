#!/usr/bin/perl -T
#
# archive_dev.pl
# archive current site state into .tar.gz file
# remove site state to defaults (except config/)
# rebuild basic frontend
#
#

use strict;
use 5.010;
use warnings;
use utf8;

$ENV{PATH}="/bin:/usr/bin";

use Cwd qw(cwd);
use File::Copy qw(copy);

my $date = '';
if (`date +%s` =~ m/^([0-9]{10})/) { #good for a few years
	$date = $1;
} else {
	die "\$date should be a decimal number, but it's actually $date";
}

my $SCRIPTDIR = cwd();
chomp $SCRIPTDIR;
if ($SCRIPTDIR =~ m/^([^\s]+)$/) { #security #taint
	$SCRIPTDIR = $1;
} else {
	print "sanity check failed #\n";
	exit;
}

my $ARCHIVEDIR = $SCRIPTDIR . '/archive';

if (!-e $ARCHIVEDIR) {
	mkdir($ARCHIVEDIR);
}

my $ARCHIVE_DATE_DIR = '';

if (-d $ARCHIVEDIR) {
	while (-e "$ARCHIVEDIR/$date") {
		$date++;
	}
	$ARCHIVE_DATE_DIR = "$ARCHIVEDIR/$date";
	mkdir("$ARCHIVE_DATE_DIR");
}

my $CACHEDIR = $SCRIPTDIR . '/cache';
my $CONFIGDIR = $SCRIPTDIR . '/config';
my $LOGDIR = $SCRIPTDIR . '/log';
my $HTMLDIR = $SCRIPTDIR . '/html';

my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/image';

{
	print("rename($TXTDIR, $ARCHIVE_DATE_DIR/txt)\n");
	rename("$TXTDIR", "$ARCHIVE_DATE_DIR/txt");

	print("rename($IMAGEDIR, $ARCHIVE_DATE_DIR/image)\n");
	rename("$IMAGEDIR", "$ARCHIVE_DATE_DIR/image");

	if (0) {
		# this needs to happen after txt and image above
		#print("rename($HTMLDIR, $ARCHIVE_DATE_DIR/html)\n");
		#rename("$HTMLDIR", "$ARCHIVE_DATE_DIR/html");
		#
		# print("rename($LOGDIR, $ARCHIVE_DATE_DIR/log)\n");
		# rename("$LOGDIR", "$ARCHIVE_DATE_DIR/log");
	} else {
		print("mkdir($ARCHIVE_DATE_DIR/html)\n");
		mkdir("$ARCHIVE_DATE_DIR/html");
	}

	print("copy($HTMLDIR/chain.log, $ARCHIVE_DATE_DIR/html/chain.log)\n");
	copy("$HTMLDIR/chain.log", "$ARCHIVE_DATE_DIR/html/chain.log");
	unlink("$HTMLDIR/chain.log");

	if (-e "$LOGDIR/access.log" && !-l "$LOGDIR/access.log") {
		print("copy($LOGDIR/access.log, $ARCHIVE_DATE_DIR/html/access.log)\n");
		copy("$LOGDIR/access.log", "$ARCHIVE_DATE_DIR/html/access.log");
		unlink("$LOGDIR/access.log");
	}

	print("cp -r \"$CONFIGDIR\" \"$ARCHIVE_DATE_DIR/config\"\n");
	system("cp -r \"$CONFIGDIR\" \"$ARCHIVE_DATE_DIR/config\""); #fast enough

	print("mkdir($HTMLDIR)\n");
	mkdir("$HTMLDIR");

	print("mkdir($TXTDIR)\n");
	mkdir("$TXTDIR");


	my $pwd = `pwd`; chomp $pwd;
	my $archiveDirRelative = $ARCHIVE_DATE_DIR;
	if (index($archiveDirRelative . '/', $pwd) == 0 && length($archiveDirRelative) > length($pwd)) {
		$archiveDirRelative = substr($archiveDirRelative, length($pwd . '/'));
	}

	if ($archiveDirRelative =~ m/^([^\s]+)$/) { #security #taint
		$archiveDirRelative = $1;
	} else {
		print ('sanity check failed on $archiveDirRelative' . "\n");
		exit;
	}

	print("tar -acf $archiveDirRelative.tar.gz $archiveDirRelative\n");
	system("tar -acf $archiveDirRelative.tar.gz $archiveDirRelative");

	print("rm -rf $ARCHIVE_DATE_DIR\n");
	system("rm -rf $ARCHIVE_DATE_DIR");

	system('./clean.sh; ./build.pl');

	print("echo \"Forum content was archived at $date\" > $TXTDIR/archived_$date\.txt\n");
	system("echo \"Forum content was archived at $date\" > $TXTDIR/archived_$date\.txt");

	print("Done.\n");
}

1;
