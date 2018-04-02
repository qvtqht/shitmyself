#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use lib qw(lib);
use HTML::Entities;
use Digest::MD5 qw(md5_hex);
use POSIX;
#use Acme::RandomEmoji qw(random_emoji);

require './utils.pl';
require './sqlite.pl';

#This has been commented out because it interferes with symlinked html dir
#my $HTMLDIR = "html.tmp";
my $HTMLDIR = "html";

my $PAGE_LIMIT = GetConfig('page_limit');
#my $PAGE_THRESHOLD = 5;

sub GetPageFooter {
	my $txtFooter = GetTemplate('htmlend.template');

	my $timestamp = strftime('%F %T', localtime(time()));

	$txtFooter =~ s/\$footer/$timestamp/;

	return $txtFooter;
}

sub GetPageHeader {
	my $title = shift;
	my $titleHtml = shift;

	if (defined($title) && defined($titleHtml)) {
		chomp $title;
		chomp $titleHtml;
	} else {
		$title="";
		$titleHtml="";
	}

	state $logoText;
	if (!defined($logoText)) {
		$logoText = GetConfig('logo_text');
		if (!$logoText) {
			#$logoText = random_emoji();
			#$logoText = encode_entities($logoText, '^\n\x20-\x25\x27-\x7e');
			$logoText = "*"
		}
		$logoText = HtmlEscape($logoText);
	}

	my $txtIndex = "";

	my @primaryColorChoices = qw(008080 c08000 808080 8098b0);
	my $primaryColor = "#" . $primaryColorChoices[int(rand(@primaryColorChoices))];

	my @secondaryColorChoices = qw(f0fff0 ffffff);
	my $secondaryColor = "#" . $secondaryColorChoices[int(rand(@secondaryColorChoices))];

	#my $primaryColor = '#'.$primaryColorChoices[0];
	#my $secondaryColor = '#f0fff0';
	my $neutralColor = '#202020';
	my $disabledColor = '#c0c0c0';
	my $disabledTextColor = '#808080';
	my $orangeColor = '#f08000';
	my $highlightColor = '#ffffc0';
	my $styleSheet = GetTemplate("style.template");

	# Get the HTML page template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title
	$htmlStart =~ s/\$logoText/$logoText/g;
	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$title/$title/;
	$htmlStart =~ s/\$titleHtml/$titleHtml/;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;
	$htmlStart =~ s/\$secondaryColor/$secondaryColor/g;
	$htmlStart =~ s/\$disabledColor/$disabledColor/g;
	$htmlStart =~ s/\$disabledTextColor/$disabledTextColor/g;
	$htmlStart =~ s/\$orangeColor/$orangeColor/g;
	$htmlStart =~ s/\$neutralColor/$neutralColor/g;
	$htmlStart =~ s/\$highlightColor/$highlightColor/g;

	my $menuTemplate = "";
	$menuTemplate .= GetMenuItem("/", "Home Page");
	$menuTemplate .= GetMenuItem("/write.html", "Write");
	$menuTemplate .= GetMenuItem("/manual.html", "Manual");
	$menuTemplate .= GetMenuItem("/clone.html", "Clone");

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
	my $ballotTime = shift;

	chomp $fileHash;
	chomp $ballotTime;

	#todo move this to GetConfig()
	if (!-e "config/secret") {
		my $randomHash = GetRandomHash();

		PutConfig("secret", $randomHash);
	}
	my $mySecret = GetConfig("secret");

	state $voteButtonsTemplate;

	if (!defined($voteButtonsTemplate)) {
		my $tagsList = GetConfig('tags');
		my $flagsList = GetConfig('flags');

		chomp $tagsList;
		chomp $flagsList;

		my @voteValues = split("\n", $tagsList . "\n" . $flagsList);

		foreach my $tag (@voteValues) {
			my $buttonTemplate = GetTemplate("votebutton.template");

			my $class = "pos";

			my @flags = split("\n", GetFile('config/flags'));

			if (grep($_ eq $tag, @flags)) {
				$class = "neg";
			}

			$buttonTemplate =~ s/\$voteValue/$tag/g;
			$buttonTemplate =~ s/\$voteValueCaption/$tag/g;
			$buttonTemplate =~ s/\$class/$class/g;

			$voteButtonsTemplate .= $buttonTemplate;
		}
	}

	if ($fileHash && $ballotTime) {
		my $checksum = md5_hex($fileHash . $ballotTime . $mySecret);

		my $voteButtons = $voteButtonsTemplate;
		$voteButtons =~ s/\$fileHash/$fileHash/g;
		$voteButtons =~ s/\$ballotTime/$ballotTime/g;
		$voteButtons =~ s/\$checksum/$checksum/g;

		return $voteButtons;
	}
}

sub GetItemTemplate {
	my %file = %{shift @_};

	if (-e $file{'file_path'}) {

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

		$message = HtmlEscape($message);
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

		$alias = HtmlEscape($alias);

		my $itemTemplate = GetTemplate("itemvote.template");

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

		my $ballotTime = time();
		my $replyCount = $file{'child_count'};

		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

		if ($replyCount) {
			$itemTemplate =~ s/\$replyCount/$replyCount replies/g;
		} else {
			$itemTemplate =~ s/\$replyCount//g;
		}

		my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
		$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

		return $itemTemplate;
	}
}

sub GetItemPage {
	#returns html for individual item page

	my %file = %{shift @_};

	my $txtIndex = "";

	my $filePath = $file{'file_path'};

	my $title = "";
	my $titleHtml = "";

	if (defined($file{'author_key'}) && $file{'author_key'}) {
		# todo the .txt extension should not be hard-coded
		my $alias = GetAlias($file{'author_key'});
		$alias = HtmlEscape($alias);

		$title = TrimPath($filePath) . ".txt by $alias";
		$titleHtml = TrimPath($filePath) . ".txt";
	} else {
		$title = TrimPath($filePath) . ".txt";
		$titleHtml = $title;
	}

	# Get the HTML page template
	my $htmlStart = GetPageHeader($title, $titleHtml);

	$txtIndex .= $htmlStart;

	$txtIndex .= GetTemplate('maincontent.template');

	my $itemTemplate = GetItemTemplate(\%file);

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	if ($file{'child_count'}) {
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		$txtIndex .= "<hr>";

		foreach my $replyItem (@itemReplies) {
			my $replyTemplate = GetItemTemplate($replyItem);

			$txtIndex .= $replyTemplate;
		}
	}

	# todo fix the == hack
	if (GetConfig('replies') == 1 && ($file{'author_key'} || GetConfig('replies_anon') == 1)) {
		my $replyForm;
		my $replyTag = GetTemplate('replytag.template');
		my $prefillText;

		if (GetFile($file{'file_path'}) =~ m/\n-- \nwiki$/) {
			$replyForm = GetTemplate('wikireply.template');
			$prefillText = "[wiki prefill]";
		} else {
			$replyForm = GetTemplate('reply.template');
			$prefillText = "\n\n-- \nparent=" . $file{'file_hash'};
		}

		$replyTag =~ s/\$parentPost/$file{'file_hash'}/g;
		$replyForm =~ s/\$extraFields/$replyTag/g;
		$replyForm =~ s/\$prefillText/$prefillText/g;

		$txtIndex .= $replyForm;
	}

	my $itemPlainText = FormatForWeb(GetFile($file{'file_path'}));

	my $itemInfoTemplate = GetTemplate('iteminfo.template');

	$itemInfoTemplate =~ s/\$itemTextPlain/$itemPlainText/;
	$itemInfoTemplate =~ s/\$fileHash/$file{'file_hash'}/;

	$txtIndex .= $itemInfoTemplate;

	my $recentVotesTable = DBGetVotesTable($file{'file_hash'});
	my $signedVotesTable = '';

	if (defined($recentVotesTable) && $recentVotesTable) {
		my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});
		my $votesSummary = "";
		foreach my $voteValue (keys %voteTotals) {
			$votesSummary .= "$voteValue (" . $voteTotals{$voteValue} . ")\n";
		}
		my $voteRetention = GetConfig('vote_limit');
		$voteRetention = ($voteRetention / 86400) . " days";

		my $recentVotesTemplate = GetTemplate('item/recent_votes.template');
		$recentVotesTemplate =~ s/\$votesSummary/$votesSummary/;
		$recentVotesTemplate =~ s/\$recentVotesTable/$recentVotesTable/;
		$recentVotesTemplate =~ s/\$voteRetention/$voteRetention/;
		$txtIndex .= $recentVotesTemplate;
	}

	if (defined($signedVotesTable) && $signedVotesTable) {
		#todo
		## $itemInfoTemplate =~ s/\$signedVotesTable/$signedVotesTable/;
	}

	# voting target fame
	$txtIndex .= GetTemplate('voteframe.template');

	# end page
	$txtIndex .= GetPageFooter();

	return $txtIndex;
}

sub GetPageParams {
	my $pageType = shift;

	my %pageParams;
	my %queryParams;

	if (defined($pageType)) {
		if ($pageType eq 'author') {
			my $authorKey = shift;
			my $whereClause = "author_key='$authorKey'";

			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			$pageParams{'title'} = "Posts by or for $authorAliasHtml";
			$pageParams{'title_html'} = "$authorAvatarHtml";

			$queryParams{'where_clause'} = $whereClause;
		}
	} else {
		$pageParams{'title'} = GetConfig('home_title') . GetConfig('logo_text');
		$pageParams{'title_html'} = GetConfig('home_title');
	}

	$pageParams{'query_params'} = %queryParams;

	return %pageParams;
}

sub GetIndexPage {
	my $filesArrayReference = shift;
	my @files = @$filesArrayReference;
	my $currentPageNumber = shift;

	my $txtIndex = "";

	my $pageTitle = GetConfig('home_title');

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);

	$txtIndex .= $htmlStart;

	$txtIndex .= GetPageLinks($currentPageNumber);

	$txtIndex .= GetTemplate('maincontent.template');

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		if (-e $file) {
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

			$message = HtmlEscape($message);
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

			$alias = HtmlEscape($alias);

			my $itemTemplate = GetTemplate("itemvote.template");

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
			my $ballotTime = time();
			my $replyCount = $row->{'child_count'};

			$itemTemplate =~ s/\$itemClass/$itemClass/g;
			$itemTemplate =~ s/\$authorLink/$authorLink/g;
			$itemTemplate =~ s/\$itemName/$itemName/g;
			$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
			$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
			$itemTemplate =~ s/\$itemText/$itemText/g;
			$itemTemplate =~ s/\$fileHash/$fileHash/g;
			if ($replyCount) {
				$itemTemplate =~ s/\$replyCount/$replyCount replies/g;
			} else {
				$itemTemplate =~ s/\$replyCount//g;
			}

			my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
			$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

			$txtIndex .= $itemTemplate;
		}
	}

	$txtIndex .= GetTemplate('voteframe.template');

	$txtIndex .= GetPageLinks($currentPageNumber);

	# Add javascript warning to the bottom of the page
	#$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	return $txtIndex;

}

sub GetReadPage {
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

			$title = "Posts by or for $authorAliasHtml";
			$titleHtml = "$authorAvatarHtml";

			my %queryParams;
			$queryParams{'where_clause'} = $whereClause;
			@files = DBGetItemList(\%queryParams);
		}
	} else {
		return; #this code is deprecated
#		$title = GetConfig('home_title') . ' - ' . GetConfig('logo_text');
#		$titleHtml = GetConfig('home_title');
#
#		my %queryParams;
#
#		@files = DBGetItemList(\%queryParams);
	}

	my $txtIndex = "";

	# this will hold the title of the page
	if (!$title) {
		$title = GetConfig('home_title');
	}
	chomp $title;

	my $htmlStart = GetPageHeader($title, $titleHtml);

	$txtIndex .= $htmlStart;

	$txtIndex .= GetTemplate('maincontent.template');

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		if (-e $file) {
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

			$message = HtmlEscape($message);
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

			$alias = HtmlEscape($alias);

			my $itemTemplate = GetTemplate("itemvote.template");

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
			my $ballotTime = time();
			my $replyCount = $row->{'child_count'};

			$itemTemplate =~ s/\$itemClass/$itemClass/g;
			$itemTemplate =~ s/\$authorLink/$authorLink/g;
			$itemTemplate =~ s/\$itemName/$itemName/g;
			$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
			$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
			$itemTemplate =~ s/\$itemText/$itemText/g;
			$itemTemplate =~ s/\$fileHash/$fileHash/g;

			if ($replyCount) {
				$itemTemplate =~ s/\$replyCount/$replyCount replies/g;
			} else {
				$itemTemplate =~ s/\$replyCount//g;
			}

			my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
			$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

			$txtIndex .= $itemTemplate;
		}
	}

	$txtIndex .= GetTemplate('voteframe.template');

	# Add javascript warning to the bottom of the page
	#$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	return $txtIndex;
}

sub GetSubmitPage {
	my $txtIndex = "";


	my $title = "Add Text";
	my $titleHtml = "Add Text";

	my $itemCount = DBGetItemCount();
	my $itemLimit = 9000;

	$txtIndex = GetPageHeader($title, $titleHtml);


	$txtIndex .= GetTemplate('maincontent.template');

	if (defined($itemCount)) {
		if ($itemCount < $itemLimit) {
			my $submitForm = GetTemplate('write.template');
			$submitForm =~ s/\$extraFields//g;

			$txtIndex .= $submitForm;

			$txtIndex .= "Curent Post Count: $itemCount; Current Post Limit: $itemLimit";
		} else {
			$txtIndex .= "Item limit ($itemLimit) has been reached (or exceeded). Please delete some things before posting new ones (or increase the item limit in config)";
		}

		$txtIndex .= GetPageFooter();

		$txtIndex =~ s/<\/head>/<script src="zalgo.js"><\/script>\<script src="openpgp.js"><\/script><\/head>/;
	} else {
		my $submitForm = GetTemplate('write.template');
		$submitForm =~ s/\$extraFields//g;

		$txtIndex .= $submitForm;
		$txtIndex = "Something went wrong. Could not get item count.";
	}

	return $txtIndex;
}

sub GetPageLink {
	my $pageNumber = shift;

	state $pageLinkTemplate;
	if (!defined($pageLinkTemplate)) {
		$pageLinkTemplate = GetTemplate('pagelink.template');
	}

	my $pageLink = $pageLinkTemplate;
	$pageLink =~ s/\$pageName/$pageNumber/;

	if ($pageNumber > 0) {
		$pageLink =~ s/\$pageNumber/$pageNumber/;
	} else {
		$pageLink =~ s/\$pageNumber//;
	}

	return $pageLink;
}

sub GetPageLinks {
	state $pageLinks;

	my $currentPageNumber = shift;

	if (defined($pageLinks)) {
		my $currentPageTemplate = GetPageLink($currentPageNumber);

		my $pageLinksFinal = $pageLinks;
		$pageLinksFinal =~ s/$currentPageTemplate/<b>$currentPageNumber<\/b> /g;

		return $pageLinksFinal;
	}

	my $itemCount = DBGetItemCount("parent_hash = ''");

	$pageLinks = "";

	my $lastPageNum = ceil($itemCount / $PAGE_LIMIT);

#	my $beginExpando;
#	my $endExpando;
#
#	if ($lastPageNum > 15) {
#		if ($currentPageNumber < 5) {
#			$beginExpando = 0;
#		} elsif ($currentPageNumber < $lastPageNum - 5) {
#			$beginExpando = $currentPageNumber - 2;
#		} else {
#			$beginExpando = $lastPageNum - 5;
#		}
#
#		if ($currentPageNumber < $lastPageNum - 5) {
#			$endExpando = $lastPageNum - 2;
#		} else {
#			$endExpando = $currentPageNumber;
#		}
#	}

	if ($itemCount > $PAGE_LIMIT) {
		for (my $i = 0; $i < $lastPageNum; $i++) {
			my $pageLinkTemplate;
#			if ($i == $currentPageNumber) {
#				$pageLinkTemplate = "<b>" . $i . "</b>";
#			} else {
				$pageLinkTemplate = GetPageLink($i);
#			}

			$pageLinks .= $pageLinkTemplate;
		}
	}

	my $frame = GetTemplate('pagination.template');

	$frame =~ s/\$paginationLinks/$pageLinks/;

	$pageLinks = $frame;

	return GetPageLinks($currentPageNumber);
}

sub MakeStaticPages {

	# Submit page
	my $submitPage = GetSubmitPage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);


	# Target page for the submit page
	my $graciasPage = GetPageHeader("Thank You", "Thank You");
	$graciasPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	$graciasPage .= GetTemplate('maincontent.template');

	my $graciasTemplate = GetTemplate('gracias.template');

	my $currUpdateTime = time();
	my $prevUpdateTime = GetConfig('last_update_time');
	if (!defined($prevUpdateTime) || !$prevUpdateTime) {
		$prevUpdateTime = time();
	}

	my $updateInterval = $currUpdateTime - $prevUpdateTime;

	PutConfig("last_update_time", $currUpdateTime);

	$prevUpdateTime = EpochToHuman($prevUpdateTime);
	$currUpdateTime = EpochToHuman($currUpdateTime);

	$graciasTemplate =~ s/\$prevUpdateTime/$prevUpdateTime/;
	$graciasTemplate =~ s/\$currUpdateTime/$currUpdateTime/;
	$graciasTemplate =~ s/\$updateInterval/$updateInterval/;

	$graciasPage .= $graciasTemplate;

	$graciasPage .= GetPageFooter();

	PutHtmlFile("$HTMLDIR/gracias.html", $graciasPage);


	# Ok page
	my $okPage = GetTemplate('actionvote.template');
	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);


	# Manual page
	my $tfmPage = GetPageHeader("Manual", "Manual");

	$tfmPage .= GetTemplate('maincontent.template');

	my $tfmPageTemplate = GetTemplate('manual.template');

	$tfmPage .= $tfmPageTemplate;

	$tfmPage .= GetPageFooter();

	PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('openpgp.worker.js.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');

	PutHtmlFile("$HTMLDIR/.htaccess", $HtaccessTemplate);
}


#todo this means occasional 404 errors, needs better solution
if ($HTMLDIR) {
	#system("rm -rfv $HTMLDIR/*");
	#system("rm -rf $HTMLDIR/*");
}

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Authors...");

my @authors = DBGetAuthorList();

foreach my $key (@authors) {
	WriteLog ("$key");

	WriteLog("$HTMLDIR/author/$key");

	if (!-e "$HTMLDIR/author") {
		mkdir("$HTMLDIR/author");
	}

	if (!-e "$HTMLDIR/author/$key") {
		mkdir("$HTMLDIR/author/$key");
	}

	my $authorIndex = GetReadPage('author', $key);

	PutHtmlFile("$HTMLDIR/author/$key/index.html", $authorIndex);
}

{
	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	foreach my $file(@files) {
		my $fileName = TrimPath($file->{'file_path'});

		my $fileIndex = GetItemPage($file);

		PutHtmlFile("$HTMLDIR/$fileName.html", $fileIndex);
	}
}

MakeStaticPages();

sub MakeClonePage {
	#This makes the zip file as well as the clone.html page that lists its size

	WriteLog("Making zip file...");

	system("git archive --format zip --output html/hike.tmp.zip master");
	#system("git archive -v --format zip --output html/hike.tmp.zip master");

	system("zip -qr $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");
	#system("zip -qrv $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");

	rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");


	my $clonePage = GetPageHeader("Clone This Site", "Clone This Site");

	$clonePage .= GetTemplate('maincontent.template');

	my $clonePageTemplate = GetTemplate('clone.template');

	my $sizeHikeZip = -s "$HTMLDIR/hike.zip";

	$sizeHikeZip = GetFileSizeHtml($sizeHikeZip);

	$clonePageTemplate =~ s/\$sizeHikeZip/$sizeHikeZip/g;

	$clonePage .= $clonePageTemplate;

	$clonePage .= GetPageFooter();

	PutHtmlFile("$HTMLDIR/clone.html", $clonePage);
}

MakeClonePage();

{
	my $itemCount = DBGetItemCount("parent_hash = ''");

	#if ($itemCount > 0) {
		my $i;
		my $lastPage = ceil($itemCount / $PAGE_LIMIT);

		for ($i = 0; $i < $lastPage; $i++) {
			my %queryParams;
			my $offset = $i * $PAGE_LIMIT;

			$queryParams{'where_clause'} = "parent_hash = ''";
			$queryParams{'limit_clause'} = "LIMIT $PAGE_LIMIT OFFSET $offset";

			my @ft = DBGetItemList(\%queryParams);
			my $testIndex = GetIndexPage(\@ft, $i);

			if ($i > 0) {
				PutHtmlFile("./html/index$i.html", $testIndex);
			} else {
				PutHtmlFile("./html/index.html", $testIndex);
			}
		}
	#}
}

#This has been commented out because it interferes with symlinked html dir
#rename("html", "html.old");
#rename("$HTMLDIR", "html/");
#system("rm -rf html.old");