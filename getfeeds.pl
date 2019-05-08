#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use utf8;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
use 5.010;

require './utils.pl';

my @feeds = split("\n", GetConfig('feeds'));

if (scalar(@feeds)) {
	foreach(@feeds) {
		my $sha1 = Digest::SHA1->new;
		$sha1->add($_);

		my $localName = $sha1->hexdigest;

		if (!-e "html/txt/$localName") {
			system("git clone $_ html/txt/$localName");
		}

		if (-e "html/txt/$localName" && -d "html/txt/$localName") {
			system("cd html/txt/$localName ; git fetch ; git merge ; cd -");
		}
	}
}