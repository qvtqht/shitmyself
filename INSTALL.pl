#!/usr/bin/perl

die 'this script is not finished yet';

use strict;

sub GetYes { # $defaultYes ; get a Y from the user
# $defaultYes true:  allows pressing enter
# $defaultYes false: user must type Y or y
    my $message = shift;
    chomp $message;

    print $message;

    my $defaultYes = shift;
    chomp $defaultYes;

    if ($defaultYes) {
        print ' [Y] ';
    } else {
        print " Enter 'Y' to proceed: ";
    }

    my $input = <STDIN>;
    chomp $input;

    if ($input eq 'Y' || $input eq 'y' || ($defaultYes && $input eq '')) {
        return 1;
    }

    return 0;
}

#####

print "\n\nHello!\n";

my $canRead = GetYes('Can you read this text?');

if ($canRead) {
    print "Great! Let's proceed...\n";
} else {
    print "Must enter Y to proceed. Exiting.\n";
    exit;
}

#####

# figure out which distro and ask to install packages

my $yumPath = `which yum 2>/dev/null`;
my $aptPath = `which apt 2>/dev/null`;

if ($yumPath) {
    my $installYum = GetYes("yum is available. Install pre-requisite packages? ", 1);
}
if ($aptPath) {
    my $installApt = GetYes("apt is available. Install pre-requisite packages? ", 1);
}

#####

# ask if need to symlink web root
# rename original?

#####

# ask if want to enable local lighttpd?

my $enableLighttpd = GetYes('Enable lighttpd?');

if ($enableLighttpd) {
    print "Hello\n";
}

#####

# launch browser?

# ask about php too

# ask about gpg1/2


