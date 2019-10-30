use strict;
use warnings FATAL => 'all';
use threads;
use utf8;

sub BuildMessage {
	print shift;
	print "\n";
}

BuildMessage "Require ./utils.pl...";

require './utils.pl';

BuildMessage "Calculating build times...";

my $prevBuildStart = trim(GetFile('config/admin/build_begin'));
my $prevBuildFinish = trim(GetFile('config/admin/build_end'));

BuildMessage "\$prevBuildStart = " . $prevBuildStart;
BuildMessage "\$prevBuildFinish = " . $prevBuildFinish;

my $prevBuildDuration;
if ($prevBuildFinish && $prevBuildStart && $prevBuildFinish > $prevBuildStart) {
	$prevBuildDuration = ($prevBuildFinish - $prevBuildStart);
	PutFile('config/admin/prev_build_duration', $prevBuildDuration);
}

PutFile('config/admin/build_begin', GetTime());
PutFile('config/admin/build_end', '');

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

BuildMessage "SqliteUnlinkDB()...";

SqliteUnlinkDb();

BuildMessage "SqliteConnect()...";

SqliteConnect();

BuildMessage "SqliteMakeTables()...";

SqliteMakeTables();

BuildMessage "Ensure there's html/txt and something inside...";

if (!-e 'html/txt') {
	mkdir('html/txt');
}

if (!glob('html/txt')) {
	PutFile('html/txt/hello.txt', 'Hello, World!');
}

#my $accessLogPath = GetConfig('admin/access_log_path');
#ProcessAccessLog($accessLogPath);

BuildMessage "Looking for files...";

# This holds all the files we will list in the primary index
my @filesToInclude;
push (@filesToInclude, `find html/txt | grep \.txt\$ | sort -r`);

#push (@filesToInclude, `find html/image | grep \.jpg\$ | sort -r`); #aug29

#push (@filesToInclude, `find html/txt/ | grep \.md\$ | sort -r`); #todo add support for .md (markdown) files

BuildMessage "MakeAddedIndex()...";

MakeAddedIndex();

#BuildMessage "MakeIndex(\@filesToInclude)";

#MakeIndex(\@filesToInclude);

BuildMessage "MakeVoteIndex()...";

MakeVoteIndex();

BuildMessage "MakeAddedIndex()...";

MakeAddedIndex();

BuildMessage "WriteConfigFromDatabase()...";

WriteConfigFromDatabase();

BuildMessage "DBAddPageTouch('summary', 0)...";

DBAddPageTouch('summary', 0);

BuildMessage("UpdateUpdateTime()...");

UpdateUpdateTime();

require './pages.pl';

BuildMessage "require('./generate.pl')...";

require('./generate.pl');

if (GetConfig('admin/lighttpd/enable')) {
	BuildMessage("admin/lighttpd/enable was true");
	
	BuildMessage('$lighttpdConf = GetLighttpdConfig()');
	my $lighttpdConf = GetLighttpdConfig();
	
	BuildMessage('===== beg $lighttpdConf =====');
	BuildMessage($lighttpdConf);
	BuildMessage('===== end $lighttpdConf =====');
	
	BuildMessage('PutFile(\'config/lighttpd.conf\', $lighttpdConf);');
	PutFile('config/lighttpd.conf', $lighttpdConf);
} else {
	BuildMessage("admin/lighttpd/enable was false");
}

if (GetConfig('admin/lighttpd/enable')) {
	system('killall lighttpd; time ./lighttpd.pl &');
}

GitPipe('add html/txt');

my $filesLeft = GitPipe('status --porcelain', '| grep "^A" | cut -c 4- | grep "html/txt" | grep "txt$" | wc -l');

PutConfig('admin/gitflow/files_left', $filesLeft);

PutFile('config/admin/build_end', GetTime());

UpdateUpdateTime();
# Stats page
my $statsPage = GetStatsPage();
PutHtmlFile("html/stats.html", $statsPage);

if (GetConfig('admin/build/gitflow_after')) {
	BuildMessage("system('perl gitflow.pl')...");
	
	system('perl gitflow.pl');
}
	
BuildMessage("Done!");

WriteLog( "Finished!");

if (GetConfig('admin/build/loop_after')) {
	WriteLog('Starting loop.pl...');

	system('perl ./loop.pl');
}


1;