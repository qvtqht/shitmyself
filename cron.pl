use strict;
use warnings FATAL => 'all';

require './utils.pl';
require './access.pl';

my $lockTime = GetFile('cron.lock');
my $currentTime = GetTime();

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

if (GetConfig('admin/git_cron_pull') == 1) {
	system('git stash');
	system('git pull');
}
# Read access.log using the path in the config

my $accessLogPath = GetConfig('admin/access_log_path');
WriteLog("\$accessLogPath = $accessLogPath");

my $startTime = GetTime();
my $interval = GetConfig('admin/cron_continue');
my $touch = 0;

while (!$touch || GetTime() < $startTime + $interval) {
	$touch = 1;

	if (!GetFile('cron.lock') || GetFile('cron.lock') ne $lockTime) {
		WriteLog('Lock file has changed, quitting.');
		last;
	}

	my $newItemCount = ProcessAccessLog($accessLogPath, 0);

	if ($newItemCount > 0) {
		system('perl build.pl');
		#WriteLog('Skipping build');
	}
}

WriteLog( "Finished!");

unlink('cron.lock');
