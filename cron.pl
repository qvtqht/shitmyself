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
		WriteLog('Lock file exists, but old. Continuing.');
	}
}
PutFile('cron.lock', $currentTime);
$lockTime = $currentTime;

# if (GetConfig('git_stash') == 1) {
# 	system('git stash');
# }

# Update from repo
#system('git pull');

# Read access.log using the path in the config

my $accessLogPath = GetConfig('access_log_path');

my $startTime = time();
my $interval = GetConfig('cron_continue');

while (time() < $startTime + $interval) {
	sleep(1);

	if (!GetFile('cron.lock') || GetFile('cron.lock') ne $lockTime) {
		WriteLog('Lock file has changed, quitting.');
		last;
	}

	my $newItemCount = ProcessAccessLog($accessLogPath, 0);

	if ($newItemCount > 0) {
		system('perl rebuild.pl');
	}
}

WriteLog( "Finished!");

unlink('cron.lock');