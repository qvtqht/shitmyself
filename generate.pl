#!/usr/bin/perl


#todo add "account" and "sign up" and "register" links

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use lib qw(lib);
use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Data::Dumper;
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
	my $myVersion = GetMyVersion();
	#my $gpgVersion = GetGpgMajorVersion();

	my $myVersionPrettyLink = '<a href="/' . $myVersion . '.html">' . substr($myVersion, 0, 8) . '..' . '</a>';

	my $footer = $timestamp . " ; running " . $myVersionPrettyLink;

	$txtFooter =~ s/\$footer/$footer/;

	return $txtFooter;
}

my $primaryColor;
my $secondaryColor;
my $textColor;

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

	#my @primaryColorChoices = qw(008080 c08000 808080 8098b0 c5618e);
	my @primaryColorChoices = split("\n", GetConfig('primary_colors'));
	$primaryColor = "#" . $primaryColorChoices[int(rand(@primaryColorChoices))];

	#my @secondaryColorChoices = qw(f0fff0 ffffff);
	my @secondaryColorChoices = split("\n", GetConfig('secondary_colors'));
	$secondaryColor = "#" . $secondaryColorChoices[int(rand(@secondaryColorChoices))];

	my @textColorChoices = split("\n", GetConfig('text_colors'));
	$textColor = "#" . $textColorChoices[int(rand(@textColorChoices))];


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
	$htmlStart =~ s/\$textColor/$textColor/g;
	$htmlStart =~ s/\$disabledColor/$disabledColor/g;
	$htmlStart =~ s/\$disabledTextColor/$disabledTextColor/g;
	$htmlStart =~ s/\$orangeColor/$orangeColor/g;
	$htmlStart =~ s/\$neutralColor/$neutralColor/g;
	$htmlStart =~ s/\$highlightColor/$highlightColor/g;

	my $menuTemplate = "";

	$menuTemplate .= GetMenuItem("/", 'Home');
	$menuTemplate .= GetMenuItem("/write.html", GetString('menu/write'));
	$menuTemplate .= GetMenuItem("/tags.html", GetString('menu/tags'));
	$menuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));
	#$menuTemplate .= GetMenuItem("/identity.html", 'Account');
#	$menuTemplate .= GetMenuItem("/clone.html", GetString('menu/clone'));

	my $adminKey = GetAdminKey();
	if ($adminKey) {
		$menuTemplate .= GetMenuItem('/author/' . $adminKey . '/', 'Admin');
	}

	$htmlStart =~ s/\$menuItems/$menuTemplate/g;

	my $identityLink = GetMenuItem("/identity.html", GetString('menu/sign_in'));
	$htmlStart =~ s/\$loginLink/$identityLink/g;

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

		$flagsList = "\n" . $flagsList . "\n";

		foreach my $tag (@voteValues) {
			my $buttonTemplate = GetTemplate("votecheck.template");

			my $class = "pos";

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
	# Returns HTML template for outputting one item
	# %file(array for each file)
	# file_path = file path including filename
	# file_hash = git's hash of the file's contents
	# author_key = gpg key of author (if any)
	# add_timestamp = time file was added as unix_time #todo
	# child_count = number of replies
	# display_full_hash = display full hash for file

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
		my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
		WriteLog('$messageCacheName (2) = ' . $messageCacheName);


		if (-e $messageCacheName) {
			$message = GetFile($messageCacheName);
		} else {
			$message = GetFile($file{'file_path'});
		}

		$message = FormatForWeb($message);

		#$message =~ s/([a-f0-9]{40})/<a href="\/$1.html">$1<\/a>/g;
		$message =~ s/([a-f0-9]{8})([a-f0-9]{32})/<a href="\/$1$2.html">$1..<\/a>/g;

		#$message =~ s/([A-F0-9]{16})/xxx/g;

		if (
			$isSigned
				&&
			$gpgKey eq GetAdminKey()
		) {
			$isAdmin = 1;
		}

		$alias = HtmlEscape($alias);

		my $itemTemplate = '';
		if (length($message) > GetConfig('item_long_threshold')) {
			$itemTemplate = GetTemplate("itemlong.template");
		} else {
			$itemTemplate = GetTemplate("item.template");
		}

		if ($file{'vote_buttons'}) {
			$itemTemplate = $itemTemplate . GetTemplate("itemvote.template");
		}

		my $itemClass = "txt";
		if ($isSigned) {
			$itemClass .= ' signed';
		}
		if ($isAdmin) {
			$itemClass .= ' admin';
		}

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
		my $permalinkHtml = "/" . $gitHash . ".html";

		$permalinkTxt =~ s/^\.//;
		$permalinkTxt =~ s/html\///;

		my $itemText = $message;
		my $fileHash = GetFileHash($file{'file_path'});
		my $itemName;
		if ($file{'display_full_hash'}) {
			$itemName = $fileHash;
		} else {
			$itemName = substr($fileHash, 0, 8) . '..';
		}

		my $ballotTime = time();
		my $replyCount = $file{'child_count'};

		my $borderColor = '#' . substr($fileHash, 0, 6);

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

		if ($replyCount) {
			my $discussLink = '<a href="' . $permalinkHtml . '#reply">' . $replyCount . ' replies</a>';
			$itemTemplate =~ s/\$replyCount/$discussLink/g;
		} else {
			my $discussLink = '<a href="' . $permalinkHtml . '#reply">reply</a>';
			$itemTemplate =~ s/\$replyCount/$discussLink/g;
		}

		WriteLog("Call to GetVoterTemplate() :309");
		my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
		$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

		return $itemTemplate;
	}
}

sub GetItemPage {
	#returns html for individual item page

	my %file = %{shift @_};
	my $fileHash = $file{'file_hash'};

	WriteLog("GetItemPage(" . $file{'file_path'} . ")");

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

	$file{'vote_buttons'} = 1;
	$file{'display_full_hash'} = 1;

	my $itemTemplate = GetItemTemplate(\%file);

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	if ($file{'child_count'}) {
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		WriteLog('@itemReplies = ' . @itemReplies);

		$txtIndex .= "<hr>";

		foreach my $replyItem (@itemReplies) {
			WriteLog('$replyItem: ' . $replyItem);
			foreach my $replyVar ($replyItem) {
				WriteLog($replyVar);
			}

			my $replyTemplate = GetItemTemplate($replyItem);

			WriteLog('$replyTemplate');
			WriteLog($replyTemplate);

			if ($replyTemplate) {
				$txtIndex .= $replyTemplate;
			} else {
				WriteLog('Warning:  replyTemplate is missing for some reason!');
			}
		}
	}

	if (GetConfig('replies') == 1) {
		my $replyForm;
		my $replyTag = GetTemplate('replytag.template');
		my $replyFooter;
		my $replyTo;
		my $prefillText;
		my $fileContents;

		$fileContents = GetFile($file{'file_path'});

		$replyForm = GetTemplate('reply.template');
		$replyFooter = "&gt;&gt;" . $file{'file_hash'} . "\n\n";
		$replyTo = $file{'file_hash'};

		$prefillText = "";

		if (!$prefillText) {
			$prefillText = "";
		}

		$replyTag =~ s/\$parentPost/$file{'file_hash'}/g;
		$replyForm =~ s/\$extraFields/$replyTag/g;
		$replyForm =~ s/\$replyFooter/$replyFooter/g;
		$replyForm =~ s/\$replyTo/$replyTo/g;
		$replyForm =~ s/\$prefillText/$prefillText/g;

		$txtIndex .= $replyForm;
	}

#	# Get votes in the database for the current file
#	my @itemVotes = DBGetVotesForItem($file{'file_hash'});

#	my $recentVotesTable = DBGetVotesTable($file{'file_hash'});
#	my $signedVotesTable = '';

#	my $recentVotesData = Data::Dumper->Dump($recentVotesTable);
#
#	$txtIndex .= $recentVotesData;

#	$txtIndex .= $file{'file_hash'};

	my $votesSummary = '';
	my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});

	foreach my $voteTag (keys %voteTotals) {
		$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
	}
	$txtIndex .= $votesSummary;

#	if (defined($recentVotesTable) && $recentVotesTable) {
#		my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});
#		my $votesSummary = "";
#		foreach my $voteValue (keys %voteTotals) {
#			$votesSummary .= "$voteValue (" . $voteTotals{$voteValue} . ")\n";
#		}
#		my $voteRetention = GetConfig('vote_limit');
#		$voteRetention = ($voteRetention / 86400) . " days";
#
#		my $recentVotesTemplate = GetTemplate('item/recent_votes.template');
#		$recentVotesTemplate =~ s/\$votesSummary/$votesSummary/;
#		$recentVotesTemplate =~ s/\$recentVotesTable/$recentVotesTable/;
#		$recentVotesTemplate =~ s/\$voteRetention/$voteRetention/;
#		$txtIndex .= $recentVotesTemplate;
#	}

	# end page with footer
	$txtIndex .= GetPageFooter();

	#Inject necessary javascript
	my $scriptInject = GetTemplate('scriptinject.template');

	#avatar.js
	my $avatarjs = GetTemplate('avatar.js.template');

	#formencode.js
	my $formEncodeJs = GetTemplate('js/formencode.js.template');

	#add them together
	my $fullJs = $avatarjs . "\n" . $formEncodeJs;

	#replace the scripts in scriptinject.template
	$scriptInject =~ s/\$javascript/$fullJs/g;

	#add to the end of the page
	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	$txtIndex =~ s/<\/body>/<\/script>\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

	return $txtIndex;
}

sub GetAuthorHeader {
	return "HI";
}

sub GetPageParams {
	# Used for getting the title and query for a page given its type and parameters
	my $pageType = shift;

	my %pageParams;
	my %queryParams;

	if (defined($pageType)) {
		# If there is a page type specified
		if ($pageType eq 'author') {
			# Author, get the author key
			my $authorKey = shift;
			chomp($authorKey);

			# Get the pretty versions of the alias and the avatar
			# for the title
			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			# Set title params
			$pageParams{'title'} = "Posts by (or for) $authorAliasHtml";
			$pageParams{'title_html'} = "$authorAvatarHtml";

			# Set the WHERE clause for the query
			my $whereClause = "author_key='$authorKey'";
			$queryParams{'where_clause'} = $whereClause;
		}
		if ($pageType eq 'tag') {
			my $tagKey = shift;
			chomp($tagKey);

			$pageParams{'title'} = $tagKey;
			$pageParams{'title_html'} = $tagKey;

			my @items = DBGetItemsForTag($tagKey);
			my $itemsList = "'" . join ("','", @items) . "'";

			$queryParams{'where_clause'} = "WHERE file_hash IN (" . $itemsList . ")";
			$queryParams{'limit_clause'} = "LIMIT 1024";
		}
	} else {
		# Default = main home page title
		$pageParams{'title'} = GetConfig('home_title') . GetConfig('logo_text');
		$pageParams{'title_html'} = GetConfig('home_title');
		#$queryParams{'where_clause'} = "item_type = 'text' AND IFNULL(parent_count, 0) = 0";
	}

	# Add the query parameters to the page parameters
	$pageParams{'query_params'} = %queryParams;

	# Return the page parameters
	return %pageParams;
}

sub GetVersionPage {
	my $version = shift;

	if (!IsSha1($version)) {
		return;
	}

	my $txtPageHtml = '';

	my $pageTitle = "Information page for version $version";

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);
#
#	my $writeSmall = GetTemplate("write-small.template");
#
#	$htmlStart .= $writeSmall;

	$txtPageHtml .= $htmlStart;

	$txtPageHtml .= GetTemplate('maincontent.template');

	my $versionInfo = GetTemplate('versioninfo.template');
	my $shortVersion = substr($version, 0, 8);

	$versionInfo =~ s/\$version/$version/g;
	$versionInfo =~ s/\$shortVersion/$shortVersion/g;

	$txtPageHtml .= $versionInfo;

	$txtPageHtml .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtPageHtml =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtPageHtml;
}

sub GetIndexPage {
	# Returns index#.html files given an array of files
	# Called by a loop in generate.pl
	# Should probably be replaced with GetReadPage()

	my $filesArrayReference = shift;
	my @files = @$filesArrayReference;
	my $currentPageNumber = shift;

	my $txtIndex = "";

	my $pageTitle = GetConfig('home_title');

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);

	my $writeSmall = GetTemplate("write-small.template");

	#my $writeShortMessage = GetString('write_short_message');
	#$writeSmall =~ s/\$writeShortMessage/$writeShortMessage/g;

	$htmlStart .= $writeSmall;

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

			my $alias;

			my $isAdmin = 0;

			my $message;
			my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
			WriteLog('$messageCacheName (3) = ' . $messageCacheName);
			if (-e $messageCacheName) {
				$message = GetFile($messageCacheName);
			} else {
				$message = GetFile($file);
			}

			$message = FormatForWeb($message);

			$message =~ s/([a-f0-9]{8})([a-f0-9]{32})/<a href="\/$1$2.html">$1..<\/a>/g;

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

			WriteLog('GetTemplate("item.template") 1');

			my $itemTemplate = '';
			if (length($message) > GetConfig('item_long_threshold')) {
				$itemTemplate = GetTemplate("itemlong.template");
			} else {
				$itemTemplate = GetTemplate("item.template");
			}
			#$itemTemplate = s/\$primaryColor/$primaryColor/g;

			my $itemClass = "txt $signedCss";

			my $authorUrl;
			my $authorAvatar;
			my $authorLink;
			my $byString = GetString('by');

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
			my $permalinkHtml = "/" . $gitHash . ".html";

			$permalinkTxt =~ s/^\.//;
			$permalinkTxt =~ s/html\///;

			my $itemText = $message;
			my $fileHash = GetFileHash($file);
			my $itemName = substr($gitHash, 0, 8) . "..";

			#			my $ballotTime = time();

			my $replyCount = $row->{'child_count'};

			my $borderColor = '#' . substr($fileHash, 0, 6);

			$itemTemplate =~ s/\$borderColor/$borderColor/g;
			$itemTemplate =~ s/\$itemClass/$itemClass/g;
			$itemTemplate =~ s/\$authorLink/$authorLink/g;
			$itemTemplate =~ s/\$itemName/$itemName/g;
			$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
			$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
			$itemTemplate =~ s/\$itemText/$itemText/g;
			$itemTemplate =~ s/\$fileHash/$fileHash/g;
			$itemTemplate =~ s/\$by/$byString/g;

#			if ($replyCount) {
#				$itemTemplate =~ s/\$replyCount/$replyCount replies/g;
#			} else {
#				$itemTemplate =~ s/\$replyCount//g;
#			}
			if ($replyCount) {
				my $discussLink = '<a href="' . $permalinkHtml . '#reply">' . $replyCount . ' replies</a>';
				$itemTemplate =~ s/\$replyCount/$discussLink/g;
			} else {
				my $discussLink = '<a href="' . $permalinkHtml . '#reply">reply</a>';
				$itemTemplate =~ s/\$replyCount/$discussLink/g;
			}


			#my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
			#$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

			$txtIndex .= $itemTemplate;
		}
	}

#	$txtIndex .= GetTemplate('voteframe.template');

	$txtIndex .= GetPageLinks($currentPageNumber);

	# Add javascript warning to the bottom of the page
	#$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	#$txtIndex =~ s/<\/body>/\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
}

sub GetReadPage {
# GetReadPage
#   $pageType
#		author
#		tag
#	$parameter
#		for author = author's key hash
#		for tag = tag name/value
	my $title;
	my $titleHtml;

	my $pageType = shift;

	my @files;

	my $authorKey;

	if (defined($pageType)) {
		if ($pageType eq 'author') {
			$authorKey = shift;
			my $whereClause = "WHERE author_key='$authorKey'";

			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			if ($authorKey eq GetAdminKey()) {
				$title = "Admin's Blog (Posts by or for $authorAliasHtml)";
				$titleHtml = "Admin's Blog ($authorAvatarHtml)";
			} else {
				$title = "Posts by or for $authorAliasHtml";
				$titleHtml = "$authorAvatarHtml";
			}

			my %queryParams;
			$queryParams{'where_clause'} = $whereClause;
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
			@files = DBGetItemList(\%queryParams);
		}
		if ($pageType eq 'tag') {
			my $tagName = shift;
			chomp($tagName);

			$title = "$tagName, posts with tag";
			$titleHtml = $title;

			my @items = DBGetItemsForTag($tagName);
			my $itemsList = "'" . join ("','", @items) . "'";

			my %queryParams;
			$queryParams{'where_clause'} = "WHERE file_hash IN (" . $itemsList . ")";
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
	$title = HtmlEscape($title);

	my $htmlStart = GetPageHeader($title, $titleHtml);

	$txtIndex .= $htmlStart;

#<span class="replies">last reply at [unixtime]</span>
#javascript foreach span class=replies { get time after "last reply at" and compare to "last visited" cookie

	$txtIndex .= GetTemplate('maincontent.template');

	if ($pageType eq 'author') {
		my $userInfo = GetTemplate('userinfo.template');

		my $authorAliasHtml = GetAlias($authorKey);
		my $authorAvatarHtml = GetAvatar($authorKey);
		my $authorImportance = 1337;

		$userInfo =~ s/\$avatar/$authorAvatarHtml/;
		$userInfo =~ s/\$alias/$authorAliasHtml/;
		$userInfo =~ s/\$fingerprint/$authorKey/;
		$userInfo =~ s/\$importance/$authorImportance/;

		$txtIndex .= $userInfo;
	}

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
			my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
			WriteLog('$messageCacheName (1) = ' . $messageCacheName);
			if ($gpgKey) {
				$message = GetFile($messageCacheName);
			} else {
				$message = GetFile($file);
			}

			#$message = FormatForWeb($message);

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

			WriteLog('GetTemplate("item.template") 2');
			my $itemTemplate = '';
			if ($message) {
				if (length($message) > GetConfig('item_long_threshold')) {
					$itemTemplate = GetTemplate("itemlong.template");
				}
				else {
					$itemTemplate = GetTemplate("item.template");
				}

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
				}
				else {
					$authorLink = "";
				}
				my $permalinkTxt = $file;
				$permalinkTxt =~ s/^\.//;
				$permalinkTxt =~ s/html\///;

				my $permalinkHtml = "/" . $gitHash . ".html";

				my $itemText = FormatForWeb($message);

				$itemText =~ s/([a-f0-9]{8})([a-f0-9]{32})/<a href="\/$1$2.html">$1..<\/a>/g;

				my $fileHash = GetFileHash($file);
				my $itemName = substr($gitHash, 0, 8) . '..';
				my $ballotTime = time();
				my $replyCount = $row->{'child_count'};

				my $borderColor = '#' . substr($fileHash, 0, 6);

				$itemTemplate =~ s/\$borderColor/$borderColor/g;
				$itemTemplate =~ s/\$itemClass/$itemClass/g;
				$itemTemplate =~ s/\$authorLink/$authorLink/g;
				$itemTemplate =~ s/\$itemName/$itemName/g;
				$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
				$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
				$itemTemplate =~ s/\$itemText/$itemText/g;
				$itemTemplate =~ s/\$fileHash/$fileHash/g;

				if ($replyCount) {
					my $discussLink = '<a href="' . $permalinkHtml . '#reply">' . $replyCount . ' replies</a>';
					$itemTemplate =~ s/\$replyCount/$discussLink/g;
				}
				else {
					my $discussLink = '<a href="' . $permalinkHtml . '#reply">reply</a>';
					$itemTemplate =~ s/\$replyCount/$discussLink/g;
				}

				WriteLog("Call to GetVoterTemplate() :881");
				my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
				$itemTemplate =~ s/\$voterButtons/$voterButtons/g;
			} else {
				$itemTemplate = '<hr>Problem decoding message</hr>';
				WriteLog('Something happened and there is no $message where I expected it... Oh well, moving on.');
			}

			$txtIndex .= $itemTemplate;
		}
	}

#	$txtIndex .= GetTemplate('voteframe.template');

	# Add javascript warning to the bottom of the page
	#$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs;
	if ($pageType eq 'author') {
		$avatarjs = GetTemplate('avatar.authorpage.js.template');
	} else {
		$avatarjs = GetTemplate('avatar.js.template');
	}
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;


	return $txtIndex;
}

sub GetIdentityPage {
	my $txtIndex = "";

	my $title = "Identity Management";
	my $titleHtml = "Identity Management";

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('identity.template');

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	$txtIndex =~ s/<\/body>/<script src="zalgo.js"><\/script>\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

	$txtIndex =~ s/<body /<body onload="identityOnload();" /;

	return $txtIndex;
}

#sub InjectJs {
#	my $scriptName = shift;
#	chomp($scriptName);
#
#	if (!$scriptName) {
#		WriteLog('WARNING! InjectJs() called with missing $scriptName. Returning empty string');
#		return '';
#	}
#
#	WriteLog("InjectJs($scriptName)");
#
#	my $scriptInject = GetTemplate('scriptinject.template');
#
#	WriteLog($scriptInject);
#	my $javascript = GetTemplate($scriptName);
#
#	WriteLog($
#
#	$scriptInject =~ s/\$javascript/$javascript/g;
#
#	return $scriptInject;
#}

sub GetVotesPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags';
	my $titleHtml = 'Tags';

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts = DBGetVoteCounts();

	my @voteCountsArray = split("\n", $voteCounts);

	foreach my $row (@voteCountsArray) {
		my @rowSplit = split(/\|/, $row);

		my $voteItemTemplate = GetTemplate('vote_page_link.template');

		my $tagName = $rowSplit[0];
		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName/g;

		$txtIndex .= $voteItemTemplate;
	}

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
}

sub GetTopPage {
	my $tag = shift;
	chomp($tag);

	my $txtIndex = '';

	my $items = GetTopItemsForTag('interesting');

	return $items;


}

sub GetSubmitPage {
	my $txtIndex = "";


	my $title = "Add Text";
	my $titleHtml = "Add Text";

	my $itemCount = DBGetItemCount();
	my $itemLimit = 9000;

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	if (defined($itemCount) && defined($itemLimit)) {
		if ($itemCount < $itemLimit) {
			my $submitForm = GetTemplate('write.template');
			my $prefillText = "";

			$submitForm =~ s/\$extraFields//g;
			$submitForm =~ s/\$prefillText/$prefillText/g;

			$txtIndex .= $submitForm;

			$txtIndex .= "Current Post Count: $itemCount; Current Post Limit: $itemLimit";
		} else {
			$txtIndex .= "Item limit ($itemLimit) has been reached (or exceeded). Please delete some things before posting new ones (or increase the item limit in config)";
		}

		$txtIndex .= GetPageFooter();

		my $scriptInject = GetTemplate('scriptinject.template');
		my $avatarjs = GetTemplate('avatar.js.template');
		$scriptInject =~ s/\$javascript/$avatarjs/g;

		$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

		$txtIndex =~ s/<\/body>/<script src="zalgo.js"><\/script>\<script src="openpgp.js"><\/script>\<script src="crypto.js"><\/script><\/body>/;

		$txtIndex =~ s/<body /<body onload="writeOnload();" /;
	} else {
		my $submitForm = GetTemplate('write.template');
		my $prefillText = "";

		$submitForm =~ s/\$extraFields//g;
		$submitForm =~ s/\$prefillText/$prefillText/g;

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

	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

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


	# Identity page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/identity.html", $identityPage);


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

	my $nextUpdateTime = EpochToHuman($currUpdateTime + $updateInterval);

	$prevUpdateTime = EpochToHuman($prevUpdateTime);
	$currUpdateTime = EpochToHuman($currUpdateTime);

	$graciasTemplate =~ s/\$prevUpdateTime/$prevUpdateTime/;
	$graciasTemplate =~ s/\$currUpdateTime/$currUpdateTime/;
	$graciasTemplate =~ s/\$updateInterval/$updateInterval/;
	$graciasTemplate =~ s/\$nextUpdateTime/$nextUpdateTime/;

	$graciasPage .= $graciasTemplate;

	$graciasPage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$graciasPage =~ s/<\/body>/$scriptInject<\/body>/;


	PutHtmlFile("$HTMLDIR/gracias.html", $graciasPage);


	# Ok page
	my $okPage = GetTemplate('actionvote.template');

	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	#$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote2.html", $okPage);


	# Manual page
	my $tfmPage = GetPageHeader("Manual", "Manual");

	$tfmPage .= GetTemplate('maincontent.template');

	my $tfmPageTemplate = GetTemplate('manual.template');

	$tfmPage .= $tfmPageTemplate;

	$tfmPage .= GetTemplate('netnow3.template');

	$tfmPage .= GetPageFooter();

	$scriptInject = GetTemplate('scriptinject.template');
	$avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$tfmPage =~ s/<\/body>/$scriptInject<\/body>/;

	PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('openpgp.worker.js.template'));

	# Write form javasript
	my $cryptoJsTemplate = GetTemplate('crypto.js.template');
	my $prefillUsername = GetConfig('prefill_username') || '';
	$cryptoJsTemplate =~ s/\$prefillUsername/$prefillUsername/g;

	PutHtmlFile("$HTMLDIR/crypto.js", $cryptoJsTemplate);

	# Write form javasript
	PutHtmlFile("$HTMLDIR/avatar.js", GetTemplate('avatar.js.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');
	PutHtmlFile("$HTMLDIR/.htaccess", $HtaccessTemplate);

	PutHtmlFile("$HTMLDIR/favicon.ico", '');
}

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Authors...");

my @authors = DBGetAuthorList();

WriteLog('@authors: ' . scalar(@authors));

my $authorInterval = 3600;

foreach my $key (@authors) {
	WriteLog ("$key");

	my $lastTouch = GetCache("key/$key");
	if ($lastTouch && $lastTouch + $authorInterval > time()) {
		WriteLog("I already did $key recently, too lazy to do it again");
		next;
	}

	WriteLog("$HTMLDIR/author/$key");

	if (!-e "$HTMLDIR/author") {
		mkdir("$HTMLDIR/author");
	}

	if (!-e "$HTMLDIR/author/$key") {
		mkdir("$HTMLDIR/author/$key");
	}

	my $authorIndex = GetReadPage('author', $key);

	PutHtmlFile("$HTMLDIR/author/$key/index.html", $authorIndex);

	PutCache("key/$key", time());
}

{
	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	WriteLog("DBGetItemList() returned " . scalar(@files) . " items");

	my $fileList = "";

	my $fileInterval = 3600;

	foreach my $file(@files) {
		my $fileHash = $file->{'file_hash'};

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");

			return;
		}

		my $lastTouch = GetCache("file/$fileHash");
		if ($lastTouch && $lastTouch + $fileInterval > time()) {
			WriteLog("I already did $fileHash recently, too lazy to do it again");
			next;
		}

		my $fileName = $file->{'file_hash'};

		$fileName =~ s/^\.//;
		$fileName =~ s/\/html//;

		$fileList .= $fileName . "|" . $fileHash . "\n";

		my $fileIndex = GetItemPage($file);

		my $targetPath = $HTMLDIR . '/' . $fileHash . '.html';

		PutHtmlFile($targetPath, $fileIndex);

		PutCache("file/$fileHash", time());
	}

	PutFile("$HTMLDIR/rss.txt", $fileList);
}

MakeStaticPages();

sub MakeClonePage {
	WriteLog('MakeClonePage() called');

	#This makes the zip file as well as the clone.html page that lists its size

	my $zipInterval = 3600;
	my $lastZip = GetCache('last_zip');

	if (!$lastZip || (time() - $lastZip) > $zipInterval) {
		WriteLog("Making zip file...");

		system("git archive --format zip --output html/hike.tmp.zip master");
		#system("git archive -v --format zip --output html/hike.tmp.zip master");

		system("zip -qr $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");
		#system("zip -qrv $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");

		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");

		PutCache('last_zip', time());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}


	my $clonePage = GetPageHeader("Clone This Site", "Clone This Site");

	$clonePage .= GetTemplate('maincontent.template');

	my $clonePageTemplate = GetTemplate('clone.template');

	my $sizeHikeZip = -s "$HTMLDIR/hike.zip";

	$sizeHikeZip = GetFileSizeHtml($sizeHikeZip);
	if (!$sizeHikeZip) {
		$sizeHikeZip = 0;
	}

	$clonePageTemplate =~ s/\$sizeHikeZip/$sizeHikeZip/g;

	$clonePage .= $clonePageTemplate;

	$clonePage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$clonePage =~ s/<\/body>/$scriptInject<\/body>/;


	PutHtmlFile("$HTMLDIR/clone.html", $clonePage);
}

{
	my $commits = `git log -n 25 | grep ^commit`;

	WriteLog('$commits = git log -n 25 | grep ^commit');

	if ($commits) {
		foreach(split("\n", $commits)) {
			my $commit = $_;
			$commit =~ s/^commit //;
			chomp($commit);
			if (IsSha1($commit)) {
				WriteLog("./html/$commit.html");
				PutHtmlFile("./html/$commit.html", GetVersionPage($commit));
			}
		}
	}
}

{
	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	#if ($itemCount > 0) {
		my $i;

		WriteLog("\$itemCount = $itemCount");

		my $lastPage = ceil($itemCount / $PAGE_LIMIT);

		for ($i = 0; $i < $lastPage; $i++) {
			my %queryParams;
			my $offset = $i * $PAGE_LIMIT;

			#$queryParams{'where_clause'} = "WHERE item_type = 'text' AND IFNULL(parent_count, 0) = 0";
			$queryParams{'limit_clause'} = "LIMIT $PAGE_LIMIT OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';

			my @ft = DBGetItemList(\%queryParams);
			my $indexPage = GetIndexPage(\@ft, $i);

			if ($i > 0) {
				PutHtmlFile("./html/index$i.html", $indexPage);
			} else {
				PutHtmlFile("./html/index.html", $indexPage);
			}
		}
	#}
}

my $votesPage = GetVotesPage();
PutHtmlFile("./html/tags.html", $votesPage); #todo are they tags or votes?


my $voteCounts = DBGetVoteCounts();
if ($voteCounts) {
	my @voteCountsArray = split("\n", $voteCounts);

	foreach my $row (@voteCountsArray) {
		WriteLog($row);

		my @rowSplit = split(/\|/, $row);
		my $tagName = $rowSplit[0];

		my $indexPage = GetReadPage('tag', $tagName);

		PutHtmlFile('./html/top/' . $tagName . '.html', $indexPage);
	}

}


# This is a special call which gathers up last run's written html files
# that were not updated on this run and removes them
#PutHtmlFile("removePreviousFiles", "1");

#my $votesInDatabase = DBGetVotesTable();
#if ($votesInDatabase) {
#	PutFile('./html/votes.txt', DBGetVotesTable());
#}

MakeClonePage();

