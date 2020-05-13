#!/usr/bin/perl

use strict;
#use warnings FATAL => 'all'; #only if debugging
use threads;
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

{ # clear and rebuild the sqlite db
	BuildMessage "SqliteUnlinkDB()...";
	SqliteUnlinkDb();

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

#my $accessLogPath = GetConfig('admin/access_log_path');
#ProcessAccessLog($accessLogPath);

BuildMessage "Looking for files...";

BuildMessage "MakeAddedIndex()...";
MakeAddedIndex();
MakeAddedIndex();

BuildMessage "WriteConfigFromDatabase()...";
WriteConfigFromDatabase();

BuildMessage "DBAddPageTouch('summary', 0)...";
DBAddPageTouch('summary', 0);

BuildMessage("UpdateUpdateTime()...");
UpdateUpdateTime();

BuildMessage "require('./pages.pl')...";
require './pages.pl';

BuildMessage "require('./generate.pl')...";
require('./generate.pl');

if (GetConfig('admin/lighttpd/enable')) {
	BuildMessage("admin/lighttpd/enable was true");
	
	BuildMessage('$lighttpdConf = GetLighttpdConfig()');
	my $lighttpdConf = GetLighttpdConfig();
	
	WriteLog('===== beg $lighttpdConf =====');
	WriteLog($lighttpdConf);
	WriteLog('===== end $lighttpdConf =====');
	
	BuildMessage('PutFile(\'config/lighttpd.conf\', $lighttpdConf);');
	PutFile('config/lighttpd.conf', $lighttpdConf);

	if (GetConfig('admin/http_auth/enable')) {
		my $basicAuthUserFile = GetTemplate('lighttpd/lighttpd_password.template');
		PutFile('config/lighttpd_password.conf', $basicAuthUserFile);
	}
} else {
	BuildMessage("admin/lighttpd/enable was false");
}

if (GetConfig('admin/lighttpd/enable')) {
	system('killall lighttpd; time ./lighttpd.pl &');
}

PutFile('config/admin/build_end', GetTime());

if (!GetConfig('admin/secret')) {
	PutConfig('admin/secret', md5_hex(time()));
}

UpdateUpdateTime();
# Stats page
my $statsPage = GetStatsPage();
PutHtmlFile("stats.html", $statsPage);

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


1;