#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;

use HTML::Entities;

require './utils.pl';
require './sqlite.pl';

my @files;

sub GetVoterTemplate {
	my $fileHash = shift;
	my $voteHash = shift;

	chomp $fileHash;
	chomp $voteHash;

	if ($fileHash && $voteHash) {
		my $voteValuesList = GetFile('./config/tags');
		chomp $voteValuesList;
		my @voteValues = split("\n", $voteValuesList);

		my $voteButtons = '';

		foreach (@voteValues) {
			my $buttonTemplate = GetTemplate("votebutton.template");

			$buttonTemplate =~ s/\$fileHash/$fileHash/g;
			$buttonTemplate =~ s/\$voteHash/$voteHash/g;
			$buttonTemplate =~ s/\$voteValue/$_/g;
			$buttonTemplate =~ s/\$voteValueCaption/$_/g;

			$voteButtons .= $buttonTemplate;
		}

		return $voteButtons;
	}
}

sub GetIndex {
	my $txtIndex = "";

	my $title = shift;

	# this will hold the title of the page
	if (!$title) {
		$title = "Message Board";
	}
	chomp $title;

	my $titleHtml;

	if (defined $title) {
		$titleHtml = shift;

		if (!$titleHtml) {
			$titleHtml = $title;
		}
	}

	my $primaryColor = "#008080";
	my $secondaryColor = '#f0fff0';
	my $neutralColor = '#202020';
	my $styleSheet = GetTemplate("style.css");

	# Get the HTML page template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title
	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$title/$title/;
	$htmlStart =~ s/\$titleHtml/$titleHtml/;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;
	$htmlStart =~ s/\$secondaryColor/$secondaryColor/g;
	$htmlStart =~ s/\$neutralColor/$neutralColor/g;


	$txtIndex .= $htmlStart;

	# If $title is set, print it as a header
	if ($titleHtml) {
		$txtIndex .= "<h1>$titleHtml</h1>";
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
		if ($gpgKey) {
			$message = GetFile("./cache/message/$gitHash.message");
		} else {
			$message = GetFile($file);
		}

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
		my $authorLink;

		if ($gpgKey) {
			$authorUrl = "/author/$gpgKey/";
			$authorAvatar = GetAvatar($gpgKey);

			$authorLink = GetTemplate('authorlink.template');

			$authorLink =~ s/\$authorUrl/$authorUrl/g;
			$authorLink =~ s/\$authorAvatar/$authorAvatar/g;
		} else {
			$authorLink = "";
		}
		my $permalinkTxt = $file;
		$permalinkTxt =~ s/^\.//;

		my $permalinkHtml = $permalinkTxt . ".html";
		$permalinkHtml =~ s/^\/txt\//\//;

		my $itemText = $message;
		my $fileHash = GetFileHash($file);
		my $itemName = TrimPath($file);

		my $voteHash = GetRandomHash();

		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

		my $voterButtons = GetVoterTemplate($fileHash, $voteHash);
		$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

		# Print it
		$txtIndex .= $itemTemplate;
	}

	# Add a submission form to the end of the page
	$txtIndex .= GetTemplate("forma.template");

	# Close html
	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}

@files = DBGetItemList();

my $indexText = GetIndex();

PutFile('./html/index.html', $indexText);

my @authors = DBGetAuthorList();

foreach my $key (@authors) {
	mkdir("./html/author/$key");

	@files = DBGetItemList("author_key='$key'");
	#my $authorAliasHtml = encode_entities($authors{$key});
	my $authorAliasHtml = GetAlias($key);
	my $authorAvatarHtml = GetAvatar($key);

	my $title = "Posts by $authorAliasHtml";
	my $titleHtml = "$authorAvatarHtml";

	my $authorIndex = GetIndex($title, $titleHtml);

	PutFile("./html/author/$key/index.html", $authorIndex);
}


# Make sure the submission form has somewhere to go
my $graciasTemplate = GetTemplate('gracias.template');
PutFile("./html/gracias.html", $graciasTemplate);
