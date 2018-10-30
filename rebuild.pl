use strict;
use warnings FATAL => 'all';
use threads;

require './utils.pl';
require './index.pl';
require './access.pl';

#system('git pull');

ProcessAccessLog("log/access.log");

SqliteUnlinkDb();
SqliteConnect();
SqliteMakeTables();

# This holds all the files we will list in the primary index
my @filesToInclude = `find ./html/txt/ | grep \.txt\$ | sort -r`;

MakeAddedIndex();

MakeIndex(\@filesToInclude);

MakeVoteIndex();

MakeAddedIndex();

system('perl generate.pl');

WriteLog( "Finished!");
