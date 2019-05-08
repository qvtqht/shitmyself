#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use threads;

require './utils.pl';
require './index.pl';
require './access.pl';

#system('git pull');

if (!-e 'html/txt') {
	mkdir('html/txt');
}

if (!glob('html/txt')) {
	PutFile('html/txt/hello.txt', 'Hello, World!');
}

my $accessLogPath = GetConfig('access_log_path');
ProcessAccessLog($accessLogPath);
