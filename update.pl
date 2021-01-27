#!/usr/bin/perl

# update.pl
# the purpose of this script is to
#   find new items
#   run IndexTextFile() on them
#   re-generate affected pages
#		via the task table

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

require './utils.pl';

system('./index.pl --all');

system('./generate.pl');

system('./pages.pl --index');

UpdateUpdateTime();

1;