#!/usr/bin/perl

use strict;
use utf8;
use warnings;

my $time = time();

my $upgradeLogFilename = "html/txt/upgrade_$time.txt";

my $titleUpgradeLogCommand = "echo 'upgrade initiated at $time' >> $upgradeLogFilename";
print (`$titleUpgradeLogCommand`);

my $pullCommand = "time git pull --all >> $upgradeLogFilename";
print(`$pullCommand`);

my $cleanCommand = "time ./clean.sh >> $upgradeLogFilename";
print(`$cleanCommand`);

my $buildCommand = "time ./build.pl >> $upgradeLogFilename";
print(`$buildCommand`);

$time = time();
my $finishedUpgradeLogCommand = "echo 'upgrade finished at $time' >> $upgradeLogFilename";
print (`$finishedUpgradeLogCommand`);

