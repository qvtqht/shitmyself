#!/usr/bin/perl -T

use strict;
use utf8;
use warnings;

my $versionBefore = GetMyVersion();

my $time = time();
my $upgradeLogFilename = "html/txt/upgrade_$time.txt";

my $titleUpgradeLogCommand = "echo 'upgrade initiated at $time' >> $upgradeLogFilename";
print (`$titleUpgradeLogCommand`);

my $pullCommand = "time git pull --all >> $upgradeLogFilename";
print(`$pullCommand`);

my $versionAfter = GetMyVersion(1);

if ($versionBefore ne $versionAfter) {
    my $cleanCommand = "time ./clean.sh >> $upgradeLogFilename";
    print(`$cleanCommand`);

    my $buildCommand = "time ./build.pl >> $upgradeLogFilename";
    print(`$buildCommand`);
} else {
    my $noUpgradeNeededCommand = "echo 'version no change' >> $upgradeLogFilename";
    print(`$noUpgradeNeededCommand`);
}

$time = time();
my $finishedUpgradeLogCommand = "echo 'upgrade finished at $time' >> $upgradeLogFilename";
print (`$finishedUpgradeLogCommand`);

my $indexUpgradeLogCommand = 'time ./index.pl html/txt/upgrade_$time.txt';
print(`$indexUpgradeLogCommand`);

my $pagesSummaryCommand = 'time ./pages.pl --summary';
print(`$pagesSummaryCommand`);

