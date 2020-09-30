#!/usr/bin/perl

use strict;
use warnings;
use Cwd qw(cwd);
use File::Copy qw(copy);

my $date = `date +%s`;
chomp $date;

if (!$date =~ m/^[0-9]+/) {
	die "\$date should be a decimal number, but it's actually $date";
}

my $SCRIPTDIR = cwd();
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

	# this needs to happen after txt and image above
	#print("rename($HTMLDIR, $ARCHIVE_DATE_DIR/html)\n");
	#rename("$HTMLDIR", "$ARCHIVE_DATE_DIR/html");
	#
	# print("rename($LOGDIR, $ARCHIVE_DATE_DIR/log)\n");
	# rename("$LOGDIR", "$ARCHIVE_DATE_DIR/log");

	print("rename($HTMLDIR/chain.log, $ARCHIVE_DATE_DIR/html/chain.log)\n");
	rename("$HTMLDIR/chain.log", "$ARCHIVE_DATE_DIR/html/chain.log");

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