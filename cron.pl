use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './access.pl';

# if (GetConfig('git_stash') == 1) {
# 	system('git stash');
# }

# Update from repo
#system('git pull');

# Read access.log using the path in the config

my $accessLogPath = GetConfig('access_log_path');

my $newItemCount = ProcessAccessLog($accessLogPath, 0);

if ($newItemCount > 0) {
	system('perl rebuild.pl');
}

WriteLog( "Finished!");
