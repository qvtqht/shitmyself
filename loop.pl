#!/usr/bin/perl

# runs update.pl in a loop
# pauses for 2 seconds in between

use strict;
use warnings;

system('rm cron.lock');

while (!system('perl ./update.pl')) { # if error in update, quit
# 	print '
#   _                          _
#  | | ___   ___  _ __   _ __ | |
#  | |/ _ \ / _ \| \'_ \ | \'_ \| |
#  | | (_) | (_) | |_) || |_) | |
#  |_|\___/ \___/| .__(_) .__/|_|
#                |_|    |_|
# ';

}

1;
