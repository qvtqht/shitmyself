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

if (GetConfig('git_cron_pull') == 1) {
	system('git stash');
	system('git pull');
}

my $lastVersion = GetConfig('current_version');
my $currVersion = GetMyVersion();

if ($lastVersion ne $currVersion) {
	my $changeLogFilename = 'changelog_' . time() . '.txt';
	my $changeLogMessage = 'Installed software version has changed from ' . $lastVersion . ' to ' . $currVersion;
	PutFile("html/txt/$changeLogFilename", $changeLogMessage);

	PutConfig('current_version', $currVersion);
}

# Read access.log using the path in the config

my $accessLogPath = GetConfig('access_log_path');
WriteLog("\$accessLogPath = $accessLogPath");

my $startTime = time();
my $interval = GetConfig('cron_continue');
my $touch = 0;

while (!$touch || time() < $startTime + $interval) {
	$touch = 1;

	if (!GetFile('cron.lock') || GetFile('cron.lock') ne $lockTime) {
		WriteLog('Lock file has changed, quitting.');
		last;
	}

	my $newItemCount = ProcessAccessLog($accessLogPath, 0);

	if ($newItemCount > 0) {
		system('perl rebuild.pl');
		#WriteLog('Skipping rebuild');
	}
	
	sleep(1);
}

WriteLog( "Finished!");

unlink('cron.lock');
