#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;

use HTML::Entities;

require './utils.pl';
require './sqlite.pl';

my @files;

sub GetIndex {
	my $txtIndex = "";

	# this will hold the title of the page
	my $title = "Message Board";

	my $primaryColor = "#008080";
	my $secondaryColor = '#f0fff0';
	my $neutralColor = '#202020';
	my $styleSheet = GetTemplate("style.css");

	# Get the htmlstart template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title
	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$title/$title/;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;
	$htmlStart =~ s/\$secondaryColor/$secondaryColor/g;
	$htmlStart =~ s/\$neutralColor/$neutralColor/g;

	# Print it
	$txtIndex .= $htmlStart;

	# If $title is set, print it as a header
	if ($title) {
		$txtIndex .= "<h1>$title</h1>";
	}

	foreach my $row (@files) {
		my $file = $row->{'file_path'};
		my $gitHash = $row->{'file_hash'};

		my $gpgKey = $row->{'author_key'};

		my $isSigned;
		if ($gpgKey) {
			$isSigned = 1;
		} else {
			$isSigned = 0;
		}

		my $alias;;

		my $isAdmin = 0;

		my $message;
		$message = GetFile("./cache/$gitHash.message");
		$message = encode_entities($message, '<>&"');
		$message =~ s/\n/<br>\n/g;

		if ($isSigned && $gpgKey eq GetAdminKey()) {
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

		# todo $alias = GetAlias($gpgKey);

		$alias = encode_entities($alias, '<>&"');

		my $itemTemplate = GetTemplate("item.template");

		my $itemClass = "txt $signedCss";
		my $authorUrl;
		my $authorAvatar;
		if ($gpgKey) {
			$authorUrl = "/author/$gpgKey/";
			$authorAvatar = GetAvatar($gpgKey);
		} else {
			$authorUrl = "/author/Anonymous/";
			$authorAvatar = "Anonymous";
		}
		my $permalinkTxt = "$file";
		my $itemText = $message;
		my $fileHash = GetFileHash($file);
		my $itemName = TrimPath($file);

		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorUrl/$authorUrl/g;
		$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

		# Print it
		$txtIndex .= $itemTemplate;
	}

	# Add a submission form to the end of the page
	$txtIndex .= GetTemplate("forma.template");

	# Make sure the submission form has somewhere to go
	my $graciasTemplate = GetTemplate('gracias.template');
	PutFile("./html/gracias.html", $graciasTemplate);

	# Close html
	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}

@files = DBGetItemList();

my $indexText = GetIndex(@files);

PutFile('./html/index.html', $indexText);
