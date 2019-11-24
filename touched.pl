#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

require './utils.pl';
require './sqlite.pl';
require './index.pl';
require './access.pl';
require './pages.pl';

my $pagesProcessed;
$pagesProcessed = BuildTouchedPages();

WriteLog("Pages processed: $pagesProcessed");
print("Pages processed: $pagesProcessed\n");