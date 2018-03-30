use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './index.pl';

system('git pull');

system('perl access.pl');

SqliteUnlinkDb();
SqliteMakeTables();

# This holds all the files we will list in the primary index
my @filesToInclude = `find ./txt/ | grep \.txt\$ | sort -r`;

MakeIndex(\@filesToInclude);

MakeVoteIndex();

MakeAddedIndex();

system('perl generate.pl');

WriteLog( "Finished!");
