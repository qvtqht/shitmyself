#!/usr/bin/perl

use Digest::MD5 qw(md5_hex);

my $fingerprint = '93EF81367916F6FB';

my $stringHash = md5_hex($fingerprint);

my $number = 17860593;

################################################ ATTENTION
############################################ change this number
########################################### when changing string
#while (substr(md5_hex($stringHash . $number), 0, 7) ne 'b00b135') {
while (1) {
	while (index(md5_hex($stringHash . $number), '8008135') < 0) {
		$number++;
		if (0 && $number % 131072 == 0) {
			print md5_hex($stringHash . $number);
			print ':';
			print $number;
			print "\n";
		}
	}

	print $number;
	print "\n";
	print $stringHash;
	print "\n";
	print $fingerprint;
	print "\n";
	print md5_hex($stringHash . $number);
	print "\n";

	####################

	print "\n\n";

	$number++;
}
