#!/usr/bin/perl -T

# validate.pl
# validates continuity of chain.log
# returns stub for next item, chain length, and timestamp of most recent item

use strict;
use warnings;
use utf8;

require './utils.pl';
require './index.pl';

if (GetConfig('admin/read_chain_log')) {
	WriteMessage('admin/read_chain_log is true, performing chain validation...');
	my %chainResult = MakeChainIndex(0);
	if (%chainResult) {
		WriteMessage('Chain validation success!');

		WriteMessage('Chain Sequence Length: ' . $chainResult{'chain_sequence'});
		WriteMessage('Next Item Stub: ' . $chainResult{'chain_previous'});
		WriteMessage('Timestamp: ' . $chainResult{'chain_timestamp'});
#
#		$return{'chain_sequence'} = $sequenceNumber;
#		$return{'chain_previous'} = $previousLine;
#		$return{'chain_timestamp'} = $addedTime;
	} else {
		WriteMessage('WARNING! Chain validation FAILURE!');
	}
}

1;