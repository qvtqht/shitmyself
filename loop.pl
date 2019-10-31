#!/usr/bin/perl

# runs gitflow.pl in a loop
# pauses for 2 seconds in between

use strict;
use warnings;

system('rm cron.lock');

while (!system('perl ./gitflow.pl')) {
	print '
  _                          _  
 | | ___   ___  _ __   _ __ | | 
 | |/ _ \ / _ \| \'_ \ | \'_ \| | 
 | | (_) | (_) | |_) || |_) | | 
 |_|\___/ \___/| .__(_) .__/|_| 
               |_|    |_|       
';

}

1;
