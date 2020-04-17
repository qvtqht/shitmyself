#!/usr/bin/perl

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

if (-d $ARCHIVEDIR) {
	while (-e "$ARCHIVEDIR/$date") {
		$date++;
	}
	my $ARCHIVE_DATE_DIR = "$ARCHIVEDIR/$date";
	mkdir("$ARCHIVE_DATE_DIR");
}

my $CACHEDIR = $SCRIPTDIR . '/cache';
my $CONFIGDIR = $SCRIPTDIR . '/config';
my $LOGDIR = $SCRIPTDIR . '/log';
my $HTMLDIR = $SCRIPTDIR . '/html';

my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/image';

{
	rename("$TXTDIR", "$ARCHIVE_DATE_DIR/txt");
	rename("$IMAGEDIR", "$ARCHIVE_DATE_DIR/image");

	# this needs to happen before txt and image above
	rename("$HTMLDIR", "$ARCHIVE_DATE_DIR/html");

	rename("$LOGDIR", "$ARCHIVE_DATE_DIR/log");

	copy("$CONFIGDIR", "$ARCHIVE_DATE_DIR/config");  #todo make faster

	system("mkdir $HTMLDIR");
	system("mkdir $TXTDIR");

	system("echo \"Forum content was archived at $date\" > $TXTDIR/archived_$date\.txt");
}