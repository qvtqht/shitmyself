use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './access.pl';

if (GetConfig('git_stash') == 1) {
	system('git stash');
}

system('git pull');

my $accessLogPath = GetConfig('access_log_path');

my $newItemCount = ProcessAccessLog($accessLogPath, 0);

if ($newItemCount > 0) {
	system('perl rebuild.pl');
}

WriteLog( "Finished!");