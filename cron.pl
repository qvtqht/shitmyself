use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './access.pl';

if (GetConfig('git_stash') == 1) {
	system('git stash');
}

system('git pull');

my $newItemCount = ProcessAccessLog("log/access.log", 0);

if ($newItemCount > 0) {
	system('perl rebuild.pl');
}

WriteLog( "Finished!");