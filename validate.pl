#!/usr/bin/perl -T

# validator stub

# so far, validates continuity of chain.log

use strict;
use warnings;
use utf8;

require './utils.pl';
require './index.pl';

if (GetConfig('admin/read_chain_log')) {
	WriteMessage('admin/read_chain_log is true, performing chain validation...');
	my $chainResult = MakeChainIndex(0);
	if ($chainResult) {
		WriteMessage('Chain validation success!');
	} else {
		WriteMessage('Chain validation FAILURE!');
	}
}