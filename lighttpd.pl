#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

if (!-e './log') {
	mkdir('./log');
}

if (system('lighttpd -D -f config/lighttpd.conf')) {
	system('/usr/sbin/lighttpd -D -f config/lighttpd.conf');
}
