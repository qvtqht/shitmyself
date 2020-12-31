#!/usr/bin/perl
use strict;

sub GetHtpasswdLine {
	my $username = shift;
	my $password = shift;

	#todo sanity checks

	if ($username && $password) {
		my $passwordEncrypted = crypt($password,$username);
		my $line = $username . ":" . $passwordEncrypted;

		return $line;
	} else {
		return '';
	}
} # GetHtpasswdLine()

chomp(my $username=$ARGV[0]);
chomp(my $password=$ARGV[1]);

if ($username && $password) {
	my $line = GetHtpasswdLine($username, $password);
	print $line . "\n";
}


1;