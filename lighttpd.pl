#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

if (!-e './log') {
	mkdir('./log');
}

system('lighttpd -D -f lighttpd.conf');
