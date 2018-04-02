use strict;
use warnings FATAL => 'all';

require './utils.pl';

if (GetConfig('git_stash') == 1) {
	system('git stash');
}

system('git pull');

system('perl access.pl');

system('perl rebuild.pl');

WriteLog( "Finished!");