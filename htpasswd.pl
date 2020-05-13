#!/usr/bin/perl
use strict;
chomp(my $username=$ARGV[0]);
chomp(my $password=$ARGV[1]);
print $username.":".crypt($password,$username)."\n";

