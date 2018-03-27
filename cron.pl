use strict;
use warnings FATAL => 'all';

require './utils.pl';

system('git pull');

system('perl access.pl');

system('perl index.pl');

system('perl generate.pl');

WriteLog( "Finished!");