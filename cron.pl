use strict;
use warnings FATAL => 'all';

require './utils.pl';

if (GetConfig('git_stash')) {
	system('git stash');
}

system('git pull');

system('perl access.pl');

system('perl rebuild.pl');

#system('perl generate.pl');

WriteLog( "Finished!");