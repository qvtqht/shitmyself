use strict;
use warnings FATAL => 'all';
use threads;
use utf8;

my $buildStep = 0;
print "\n* Step " . ++$buildStep; #1

require './utils.pl';

print "\n* Step " . ++$buildStep;

my $prevBuildStart = trim(GetFile('config/admin/build_begin'));
my $prevBuildFinish = trim(GetFile('config/admin/build_end'));

print "\n* Step " . ++$buildStep;

my $prevBuildDuration;
if ($prevBuildFinish > $prevBuildStart) {
	$prevBuildDuration = ($prevBuildFinish - $prevBuildStart);
	PutFile('config/admin/prev_build_duration', $prevBuildDuration);
}

print "\n* Step " . ++$buildStep;

PutFile('config/admin/build_begin', GetTime());
PutFile('config/admin/build_end', '');

print "\n* Step " . ++$buildStep; #5

require './index.pl';

print "\n* Step " . ++$buildStep;

require './access.pl';

print "\n* Step " . ++$buildStep;

#if (GetConfig('upgrade_now') ne 'no') {
#	PutConfig('last_upgrade', 'no');
#	exec('./upgrade.sh &');
#	die();
#}
#

print "\n* Step " . ++$buildStep;

SqliteUnlinkDb();

print "\n* Step " . ++$buildStep;

SqliteConnect();

print "\n* Step " . ++$buildStep; #10

SqliteMakeTables();

if (!-e 'html/txt') {
	mkdir('html/txt');
}

print "\n* Step " . ++$buildStep;

if (!glob('html/txt')) {
	PutFile('html/txt/hello.txt', 'Hello, World!');
}

print "\n* Step " . ++$buildStep;

#my $accessLogPath = GetConfig('admin/access_log_path');
#ProcessAccessLog($accessLogPath);

# This holds all the files we will list in the primary index
my @filesToInclude;
push (@filesToInclude, `find html/txt | grep \.txt\$ | sort -r`);

print "\n* Step " . ++$buildStep;

#push (@filesToInclude, `find html/image | grep \.jpg\$ | sort -r`); #aug29

#push (@filesToInclude, `find html/txt/ | grep \.md\$ | sort -r`); #todo add support for .md (markdown) files

MakeAddedIndex();

print "\n* Step " . ++$buildStep;

MakeIndex(\@filesToInclude);

print "\n* Step " . ++$buildStep;

MakeVoteIndex();

print "\n* Step " . ++$buildStep; #15

MakeAddedIndex();

print "\n* Step " . ++$buildStep;

WriteConfigFromDatabase();

print "\n* Step " . ++$buildStep;

system('perl generate.pl');

print "\n* Step " . ++$buildStep;

DBResetPageTouch();

print "\n* Step " . ++$buildStep;

system('perl gitflow.pl');

print "\n* Step " . ++$buildStep; #20

WriteLog( "Finished!");

print "\n* Step " . ++$buildStep;

PutFile('config/admin/build_end', GetTime());