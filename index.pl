#!/usr/bin/perl

use strict;
use utf8;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`;
chomp $SCRIPTDIR;

print "Using $SCRIPTDIR as install root...\n";

if (!-e './utils.pl') {
	die ("Sanity check failed, can't find ./utils.pl in $SCRIPTDIR");
}
require './utils.pl';

# We'll use ./html as the web root
my $HTMLDIR = "$SCRIPTDIR/html/";

my $TXTDIR = "$SCRIPTDIR/txt";

my @filesToInclude = `find ./txt/ -name \*.txt | sort -r`;

sub GetIndex {

	my $txtIndex = "";

	# this will hold the title of the page
	my $title = "Message Board";
	my $primaryColor = "#008080";
	my $styleSheet = GetTemplate("style.css");

	# Get the htmlstart template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title
	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$title/$title/;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;

	# Print it
	$txtIndex .= $htmlStart;

	# If $title is set, print it as a header
	if ($title) {
		$txtIndex .= "<h1>$title</h1>";
	}

	my $pwd = `pwd`;
	my $MYNAME = trim(substr($pwd, length($HTMLDIR))) . "/";

	#$txtIndex .= GetMenu($MYNAME);

	# Now the header, which should (todo) be different from the topmenu
	$txtIndex .= GetTemplate("header.nfo");

	# $LocalPrefix is used for storing the local html path
	my $LocalPrefix = "";

	foreach my $file (@filesToInclude) {
		chomp($file);

		my $txt = "";
		my $message = "";
		my $isSigned = 0;

		my $gpg_key;
		my $alias;

		my $gitHash;

		my $isAdmin = 0;

		if (substr($file, length($file) -4, 4) eq ".txt") {
			my %gpgResults = GpgParse($file);

			$txt = $gpgResults{'text'};
			$message = $gpgResults{'message'};
			$isSigned = $gpgResults{'isSigned'};
			$gpg_key = $gpgResults{'key'};
			$alias = $gpgResults{'alias'};
			$gitHash = $gpgResults{'gitHash'};

			if ($alias) {
				PutFile("$SCRIPTDIR/key/$gpg_key.txt", $txt);
			}

			$message = encode_entities($message, '<>&"');
			$message =~ s/\n/<br>\n/g;

			if ($isSigned && $gpg_key == GetAdminKey()) {
				$isAdmin = 1;
			}

			my $signedCss = "";
			if ($isSigned) {
				if ($isAdmin) {
					$signedCss = "signed admin";
				} else {
					$signedCss = "signed";
				}
			}

			# todo $alias = GetAlias($gpg_key);

			$alias = encode_entities($alias, '<>&"');
			#$alias =~ s/\n/<br>\n/g;
			#why does alias have newlines?? #todo

			my $itemTemplate = GetTemplate("item.template");

			{
				my $itemClass = "txt $signedCss";
				my $authorUrl = "/author/$gpg_key/";
				my $authorAvatar = GetAvatar($gpg_key);
				my $permalinkTxt = "$file";
				my $itemText = $message;
				my $fileHash = GetHash($file);
				my $itemName = TrimPath($file);

				# and substitute $title with the title
				$itemTemplate =~ s/\$itemClass/$itemClass/g;
				$itemTemplate =~ s/\$authorUrl/$authorUrl/g;
				$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
				$itemTemplate =~ s/\$itemName/$itemName/g;
				$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
				$itemTemplate =~ s/\$itemText/$itemText/g;
				$itemTemplate =~ s/\$fileHash/$fileHash/g;
			}

			# Print it
			$txtIndex .= $itemTemplate;
		}
	}

	# Add a submission form to the end of the page
	$txtIndex .= GetTemplate("forma.template");

	# Make sure the submission form has somewhere to go
	#PutFile("gracias.html", GetTemplate('gracias.template'));
	#todo

	# Close html
	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}

my $indexText = GetIndex(@filesToInclude);

PutFile('./html/index.html', $indexText);
