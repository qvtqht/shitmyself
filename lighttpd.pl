#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

system('lighttpd -D -f lighttpd.conf');
