use strict;
use warnings FATAL => 'all';
use threads;
use utf8;


require './utils.pl';
require './index.pl';
require './access.pl';

#if (GetConfig('upgrade_now') ne 'no') {
#	PutConfig('last_upgrade', 'no');
#	exec('./upgrade.sh &');
#	die();
#}
#
SqliteUnlinkDb();
SqliteConnect();
SqliteMakeTables();

if (!-e 'html/txt') {
	mkdir('html/txt');
}

if (!glob('html/txt')) {
	PutFile('html/txt/hello.txt', 'Hello, World!');
}

my $accessLogPath = GetConfig('admin/access_log_path');
ProcessAccessLog($accessLogPath);

# This holds all the files we will list in the primary index
my @filesToInclude;
push (@filesToInclude, `find html/txt | grep \.txt\$ | sort -r`);

#push (@filesToInclude, `find html/txt/ | grep \.md\$ | sort -r`); #todo add support for .md (markdown) files

MakeAddedIndex();

MakeIndex(\@filesToInclude);

MakeVoteIndex();

MakeAddedIndex();

WriteConfigFromDatabase();

system('perl generate.pl');

WriteLog( "Finished!");
