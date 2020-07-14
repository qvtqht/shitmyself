#!/usr/bin/perl

use strict;
use utf8;
use warnings;

my $time = time();

my $pullCommand = "time git pull --all >> html/txt/pull_$time.txt";
print(`$pullCommand`);

my $cleanCommand = "time ./clean.sh >> html/txt/clean_$time.txt";
print(`$cleanCommand`);

my $buildCommand = "time ./build.pl >> html/txt/build_$time.txt";
print(`$buildCommand`);

