#!/usr/bin/perl

die;

use strict;
use utf8;
use warnings;

my $time = time();
#
# if (-e 'cron.lock') {
# 	die('cron.lock exists');
# }
#
# system(`echo $time > cron.lock`);
#
#my $stashCommand = "git stash >> stash_$time.txt";
#system($stashCommand);

print (`cd /home/ily/hike`);

my $pullCommand = "git pull >> pull_$time.txt";
print($pullCommand);
print(`$pullCommand`);

my $buildCommand = "cd /home/ily/hike ; ./clean.pl ; ./build.pl";
print(`$buildCommand`);

#my $unstashCommand = "git stash pop >> unstash_$time.txt";
#system($unstashCommand);
