use strict;
use warnings FATAL => 'all';
use threads;

require './utils.pl';
require './index.pl';
require './access.pl';

#system('git pull');

SqliteUnlinkDb();
SqliteConnect();
SqliteMakeTables();

if (!-e './html/txt') {
	mkdir('./html/txt');
}

if (!glob('./html/txt')) {
	PutFile('./html/txt/hello.txt', 'Hello, World!');
}

my $accessLogPath = GetConfig('access_log_path');
ProcessAccessLog($accessLogPath);

# This holds all the files we will list in the primary index
my @filesToInclude;
push (@filesToInclude, `find ./html/txt/ | grep \.txt\$ | sort -r`);

#push (@filesToInclude, `find ./html/txt/ | grep \.md\$ | sort -r`); #todo add support for .md (markdown) files

MakeAddedIndex();

MakeIndex(\@filesToInclude);

MakeVoteIndex();

MakeAddedIndex();

system('perl generate.pl');

WriteLog( "Finished!");
