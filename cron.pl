use strict;
use warnings FATAL => 'all';

system('git pull');

system('perl access.pl');

system('perl index.pl');

system('perl generate.pl');

print "Finished!";