#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use HTML::Entities;

require './utils.pl';
require './sqlite.pl';

sub GetPageHeader {
	my $title = shift;
	my $titleHtml = shift;

	my $txtIndex = "";

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

	my $menuTemplate = "";
	$menuTemplate .= GetMenuItem("/", "home");
	$menuTemplate .= GetMenuItem("/submit.html", "submit");

	$htmlStart =~ s/\$menuItems/$menuTemplate/g;

	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetMenuItem {
	my $address = shift;
	my $caption = shift;

	my $menuItem = GetTemplate('menuitem.template');

	$menuItem =~ s/\$address/$address/g;
	$menuItem =~ s/\$caption/$caption/g;

	return $menuItem;
}

sub GetVoterTemplate {
	my $fileHash = shift;
	my $voteHash = shift;

	chomp $fileHash;
	chomp $voteHash;

	state $voteButtons;

	if (!defined($voteButtons)) {
		my $voteValuesList = GetFile('./config/tags');
		chomp $voteValuesList;
		my @voteValues = split("\n", $voteValuesList);

		foreach (@voteValues) {
			my $buttonTemplate = GetTemplate("votebutton.template");

			$buttonTemplate =~ s/\$voteValue/$_/g;
			$buttonTemplate =~ s/\$voteValueCaption/$_/g;

			$voteButtons .= $buttonTemplate;
		}
	}

	if ($fileHash && $voteHash) {
		$voteButtons =~ s/\$fileHash/$fileHash/g;
		$voteButtons =~ s/\$voteHash/$voteHash/g;

		return $voteButtons;
	}
}

sub GetItemTemplate {
	my %file = %{shift @_};

	my $gitHash = $file{'file_hash'};

	my $gpgKey = $file{'author_key'};

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
		$message = GetFile($file{'file_path'});
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
	my $permalinkTxt = $file{'file_path'};
	$permalinkTxt =~ s/^\.//;

	my $permalinkHtml = "/" . TrimPath($permalinkTxt) . ".html";

	my $itemText = $message;
	my $fileHash = GetFileHash($file{'file_path'});
	my $itemName = TrimPath($file{'file_path'});

	my $voteHash = GetRandomHash();

	$itemTemplate =~ s/\$itemClass/$itemClass/g;
	$itemTemplate =~ s/\$authorLink/$authorLink/g;
	$itemTemplate =~ s/\$itemName/$itemName/g;
	$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
	$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
	$itemTemplate =~ s/\$itemText/$itemText/g;
	$itemTemplate =~ s/\$fileHash/$fileHash/g;

	my $voterButtons = GetVoterTemplate($fileHash, $voteHash);
	$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

	return $itemTemplate;
}

sub GetItemPage {
	my %file = %{shift @_};

	my $txtIndex = "";

	my $filePath = $file{'file_path'};

	my $title = "";
	my $titleHtml = "";

	if (defined($file{'author_key'}) && $file{'author_key'}) {
		# todo the .txt extension should not be hard-coded
		$title = TrimPath($filePath) . ".txt by " . GetAlias($file{'author_key'});
		$titleHtml = TrimPath($filePath) . ".txt by " . GetAvatar($file{'author_key'});
	} else {
		$title = TrimPath($filePath) . ".txt";
		$titleHtml = $title;
	}



	# Get the HTML page template
	my $htmlStart = GetPageHeader($title, $titleHtml);

	$txtIndex .= $htmlStart;

	my $itemTemplate = GetItemTemplate(\%file);

	# Print it
	$txtIndex .= $itemTemplate;

	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}

sub GetIndexPage {
	my $title;
	my $titleHtml;

	my $pageType = shift;

	my @files;

	if (defined($pageType)) {
		if ($pageType eq 'author') {
			my $authorKey = shift;
			my $whereClause = "author_key='$authorKey'";

			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			$title = "Posts by $authorAliasHtml";
			$titleHtml = "$authorAvatarHtml";

			@files = DBGetItemList($whereClause);
		}
	} else {
		$title = 'Message Board';
		$titleHtml = 'Message Board';

		@files = DBGetItemList();
	}

	my $txtIndex = "";

	# this will hold the title of the page
	if (!$title) {
		$title = "Message Board";
	}
	chomp $title;

	my $htmlStart = GetPageHeader($title, $titleHtml);

	$txtIndex .= $htmlStart;

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

		my $permalinkHtml = "/" . TrimPath($permalinkTxt) . ".html";

		my $itemText = $message;
		my $fileHash = GetFileHash($file);
		my $itemName = TrimPath($file);

		my $voteHash = GetRandomHash();

		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

		my $voterButtons = GetVoterTemplate($fileHash, $voteHash);
		$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

		# Print it
		$txtIndex .= $itemTemplate;
	}

	# Close html
	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}

sub GetSubmitPage {
	my $txtIndex = "";


	my $title = "Submit New Entry";
	my $titleHtml = "Submit New Entry";

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('forma.template');

	$txtIndex .= GetTemplate("htmlend.template");

	return $txtIndex;
}



my $indexText = GetIndexPage();

PutFile('./html/index.html', $indexText);

my @authors = DBGetAuthorList();

foreach my $key (@authors) {
	mkdir("./html/author/$key");

	my $authorIndex = GetIndexPage('author', $key);

	PutFile("./html/author/$key/index.html", $authorIndex);
}

my @files = DBGetItemList();

foreach my $file(@files) {
	my $fileName = TrimPath($file->{'file_path'});

	my $fileIndex = GetItemPage($file);

	PutFile("./html/$fileName.html", $fileIndex);
}

my $submitPage = GetSubmitPage();
PutFile("./html/submit.html", $submitPage);

# Make sure the submission form has somewhere to go
my $graciasTemplate = GetTemplate('gracias.template');
PutFile("./html/gracias.html", $graciasTemplate);
