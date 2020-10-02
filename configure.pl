#!/usr/bin/perl

use strict;

die 'Script is not yet finished. Please comment this line to test it';

#############
# UTILITIES

sub GetYes { # $message, $defaultYes ; print $message, and get Y response from the user
	# $message is printed to output
	# $defaultYes true:  allows pressing enter
	# $defaultYes false: user must type Y or y

	my $message = shift;
	chomp $message;

	my $defaultYes = shift;
	chomp $defaultYes;

	print $message;
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

sub WriteConfigureMessage { # $message ; print a line to user
	my $message = shift;
	chomp $message;

	WriteLog('Message: ' . $message);

	my $timestamp = GetTime();

	print "\n$timestamp . ' ' . $message";

	# AppendFile('html/status.txt', $message);
}

##################
# USER CAN READ?

WriteConfigureMessage('=====');
WriteConfigureMessage('Hello!');

my $canRead = GetYes('Can you read this text?');

if ($canRead) {
	print "Great! Let's proceed...\n";
} else {
	print "Must enter Y to proceed. Exiting.\n";
	exit;
}

###############
# OS PACKAGES

# figure out which distro and ask to install packages

my $yumPath = `which yum 2>/dev/null`;
my $dnfPath = `which dnf 2>/dev/null`;
my $aptPath = `which apt 2>/dev/null`;

if ($yumPath) {
	my $installYum = GetYes("yum is available. Install pre-requisite packages? ", 1);

	if ($installYum) {
		my $yumCommand = 'sudo yum install perl-Digest-MD5 perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite perl-URI-Encode perl-Digest-SHA1 sqlite lighttpd gnupg gnupg2 perl-Devel-StackTrace perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite lighttpd-fastcgi ImageMagick';
		my $yumResult = `$yumCommand`;

		WriteConfigureMessage($yumResult);
	}
}
if ($dnfPath) {
	my $installYum = GetYes("dnf is available. Install pre-requisite packages? ", 1);

	if ($installYum) {
		my $dnfCommand = 'sudo dnf install perl-Digest-MD5 perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite perl-URI-Encode perl-Digest-SHA1 sqlite lighttpd gnupg gnupg2 perl-Devel-StackTrace perl-Digest-SHA perl-HTML-Parser perl-DBD-SQLite lighttpd-fastcgi ImageMagick';
		my $dnfResult = `$dnfCommand`;

		WriteConfigureMessage($dnfResult);
	}
}
if ($aptPath) {
	my $installApt = GetYes("apt is available. Install pre-requisite packages? ", 1);

	if ($installApt) {
		my $aptCommand = 'sudo apt-get install uri-encode-perl libany-uri-escape-perl libhtml-parser-perl libdbd-sqlite3-perl libdigest-sha-perl sqlite3 lighttpd gnupg gnupg2 ImageMagick';
		my $aptResult = `$aptCommand`;

		WriteConfigureMessage($aptResult);
	}
}

#####

# ask if need to symlink web root
# rename original?

#####

# ask if want to enable local lighttpd?

my $enableLighttpd = GetYes('Enable lighttpd?');

if ($enableLighttpd) {
	`echo 1 > config/admin/lighttpd/enable`;
	WriteConfigureMessage('Set config/admin/lighttpd/enable=1');
}

#####

# launch browser?

# ask about php too

# ask about gpg1/2


