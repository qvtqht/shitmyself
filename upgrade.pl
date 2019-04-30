#!/usr/bin/perl

use strict;
use utf8;
use warnings;

my $time = time();

if (-e 'cron.lock') {
	die('cron.lock exists');
}

system(`echo $time > cron.lock`);

#my $stashCommand = "git stash >> stash_$time.txt";
#system($stashCommand);

my $pullCommand = "git pull >> pull_$time.txt";
system($pullCommand);

#my $unstashCommand = "git stash pop >> unstash_$time.txt";
#system($unstashCommand);
