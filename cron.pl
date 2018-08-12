use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './access.pl';

my $lockTime = GetFile('cron.lock');
my $currentTime = time();

if ($lockTime) {
	if ($currentTime - 1800 < $lockTime) {
		WriteLog('Quitting due to lock file');
		die();
	} else {
		WriteLog('Lock file exists, but too old. Continueing.');
	}
}
PutFile('cron.lock', $currentTime);

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

unlink('cron.lock');