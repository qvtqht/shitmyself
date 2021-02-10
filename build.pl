#!/usr/bin/perl -T

use strict;
use utf8;
use Cwd qw(cwd);

sub BuildMessage { # prints timestamped message to output
	print time();
	print ' ';
	print shift;
	print "\n";
} # BuildMessage()

BuildMessage "Require ./utils.pl...";
require './gpgpg.pl';
require './utils.pl';

#EnsureDirsThatShouldExist();

#CheckForInstalledVersionChange();

#CheckForRootAdminChange();

require './index.pl';


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


my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/txt';

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

if (GetConfig('admin/dev/launch_browser_after_build')) {
	WriteLog('build.pl: xdg-open http://localhost:2784/ &');
	WriteLog(`xdg-open http://localhost:2784/ &`);
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
