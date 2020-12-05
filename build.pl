#!/usr/bin/perl -T

use strict;
#use warnings FATAL => 'all'; #only if debugging
#use threads;
use utf8;
use Cwd qw(cwd);

sub BuildMessage { # prints timestamped message to output
	print time();
	print ' ';
	print shift;
	print "\n";
}

#my $SCRIPTDIR = `pwd`; chomp $SCRIPTDIR;
my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/txt';

BuildMessage "Require ./utils.pl...";
require './utils.pl';

BuildMessage "Calculating build times...";
#
# my $prevBuildStart = trim(GetFile('config/admin/build_begin'));
# my $prevBuildFinish = trim(GetFile('config/admin/build_end'));
#
# BuildMessage "\$prevBuildStart = " . $prevBuildStart;
# BuildMessage "\$prevBuildFinish = " . $prevBuildFinish;
#
# my $prevBuildDuration;
#
# if ($prevBuildFinish && $prevBuildStart && $prevBuildFinish > $prevBuildStart) {
# 	$prevBuildDuration = ($prevBuildFinish - $prevBuildStart);
# 	PutFile('config/admin/prev_build_duration', $prevBuildDuration);
# }
#
# PutFile('config/admin/build_begin', GetTime());
# PutFile('config/admin/build_end', '');

BuildMessage "Require ./access.pl...";
require './access.pl';

BuildMessage "Require ./index.pl...";
require './index.pl';

# BuildMessage "Upgrade stuff...";
# if (GetConfig('upgrade_now') ne 'no') {
#	PutConfig('last_upgrade', 'no');
#	exec('./upgrade.sh &');
#	die();
#}
#

{ # build the sqlite db if not available
	# BuildMessage "SqliteUnlinkDB()...";
	# SqliteUnlinkDb();
	#
	BuildMessage "SqliteConnect()...";
	SqliteConnect();

	BuildMessage "SqliteMakeTables()...";
	SqliteMakeTables();

	BuildMessage "Remove cache/indexed/*";
	system('rm cache/*/indexed/*');
}

BuildMessage "Ensure there's $HTMLDIR and something inside...";
if (!-e $TXTDIR) {
	# create $TXTDIR directory if it doesn't exist
	mkdir($TXTDIR);
}

if (!-e $IMAGEDIR) {
	# create $IMAGEDIR directory if it doesn't exist
	mkdir($IMAGEDIR);
}

BuildMessage "Looking for files...";

BuildMessage "MakeChainIndex()...";
MakeChainIndex();

BuildMessage "DBAddPageTouch('summary')...";
DBAddPageTouch('summary');

BuildMessage("UpdateUpdateTime()...");
UpdateUpdateTime();

BuildMessage "require('./pages.pl')...";
require './pages.pl';

#PutHtmlFile("/index.html", '<a href="/write.html">write.html</a>');
MakeSummaryPages();
#PutHtmlFile("/index.html", GetFile('html/help.html'));

if (GetConfig('admin/build/generate_after')) {
	BuildMessage "require('./generate.pl')...";
	require('./generate.pl');
}

PutFile('config/admin/build_end', GetTime());

if (!GetConfig('admin/secret')) {
	PutConfig('admin/secret', md5_hex(time()));
}

UpdateUpdateTime();
# Stats page

PutStatsPages();

if (GetConfig('admin/build/update_after')) {
	BuildMessage("system('perl update.pl --all')...");
	
	system('perl update.pl --all');
}
	
BuildMessage("Done!");

WriteLog( "Finished!");

if (GetConfig('admin/build/loop_after')) {
	WriteLog('Starting loop.pl...');

	system('perl ./loop.pl');
}

if (GetConfig('admin/lighttpd/enable')) {
	system('screen -S lighttpd -d -m perl ./lighttpd.pl');
}

if (GetConfig('admin/ssi/enable') && GetConfig('admin/php/enable')) {
	BuildMessage('Warning: ssi/enable and php/enable are both true');
}

1;
