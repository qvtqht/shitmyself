use strict;
use warnings;

use utf8;
use 5.010;

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Data::Dumper;
#use Acme::RandomEmoji qw(random_emoji);

require './utils.pl';
require './sqlite.pl';

my $HTMLDIR = "html";


sub GenerateSomeKindOfPage {
	my $pageName = shift;

	#todo is $pageName in list of allowed pages?

	# home
	# write
	# about
	# abyss
	# index
	# tags list
	# items for tag
	# more complicated query
	#
}

sub GetAuthorLink {
	my $gpgKey = shift;

	if (!IsFingerprint($gpgKey)) {
		WriteLog("WARNING: GetAuthorLink() called with invalid parameter!");
		return;
	}

	my $authorUrl = "/author/$gpgKey/";
	my $authorAvatar = GetAvatar($gpgKey);

	my $authorLink = GetTemplate('authorlink.template');

	$authorLink =~ s/\$authorUrl/$authorUrl/g;
	$authorLink =~ s/\$authorAvatar/$authorAvatar/g;

	return $authorLink;
}

sub GetPageLink {
	my $pageNumber = shift;

	state $pageLinkTemplate;
	if (!defined($pageLinkTemplate)) {
		$pageLinkTemplate = GetTemplate('pagelink.template');
	}

	my $pageLink = $pageLinkTemplate;
	$pageLink =~ s/\$pageName/$pageNumber/;

	$pageLink =~ s/\$pageNumber/$pageNumber/;

	return $pageLink;
}

sub GetPageLinks {
	state $pageLinks;

	my $currentPageNumber = shift;

	WriteLog("GetPageLinks($currentPageNumber)");

	if (defined($pageLinks)) {
		WriteLog("GetPageLinks: \$pageLinks already exists, doing a quickie");

		my $currentPageTemplate = GetPageLink($currentPageNumber);

		my $pageLinksFinal = $pageLinks;
		$pageLinksFinal =~ s/$currentPageTemplate/<b>Page $currentPageNumber<\/b> /g;

		return $pageLinksFinal;
	}

	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	WriteLog("GetPageLinks: \$itemCount = $itemCount");

	$pageLinks = "";

	my $pageLimit = GetConfig('page_limit');

	my $lastPageNum = ceil($itemCount / $pageLimit);

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

	if ($itemCount > $pageLimit) {
		#		for (my $i = $lastPageNum - 1; $i >= 0; $i--) {
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

sub GetVotesPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags';
	my $titleHtml = 'Tags';

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts = DBGetVoteCounts();

	my @voteCountsArray = @{$voteCounts};

	while (@voteCountsArray) {
		my $voteItemTemplate = GetTemplate('vote_page_link.template');
		#todo don't need to do this every time

		my $tag = shift @voteCountsArray;

		my $tagName = @{$tag}[0];
		my $tagCount = @{$tag}[1];

		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName ($tagCount)/g;

		$txtIndex .= $voteItemTemplate;
	}

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
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

	#$file{'vote_buttons'} = 1;
	$file{'display_full_hash'} = 1;
	$file{'show_vote_summary'} = 1;
	$file{'vote_buttons'} = 1;

	my $itemTemplate = GetItemTemplate(\%file);

	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	if ($file{'child_count'}) {
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		WriteLog('@itemReplies = ' . @itemReplies);

		#$txtIndex .= "<hr>";
		my $allReplies = '';

		foreach my $replyItem (@itemReplies) {
			WriteLog('$replyItem: ' . $replyItem);
			foreach my $replyVar ($replyItem) {
				WriteLog($replyVar);
			}

			$$replyItem{'template_name'} = 'item/item-small.template';
			$$replyItem{'remove_token'} = '>>' . $file{'file_hash'};

			WriteLog('$$replyItem{\'template_name\'} = ' . $$replyItem{'template_name'});

			my $replyTemplate = GetItemTemplate($replyItem);

			WriteLog('$replyTemplate');
			WriteLog($replyTemplate);

			if ($$replyItem{'child_count'}) {
				my $subReplies = '';

				#$replyTemplate .= "<p><font color=red>more replies here!</font></p>";
				my @subReplies = DBGetItemReplies($file{'file_hash'});
				foreach my $subReplyItem (@subReplies) {
					$$subReplyItem{'template_name'} = 'item/item-small.template';
					$$subReplyItem{'remove_token'} = '>>' . $file{'file_hash'};

					my $subReplyTemplate = GetItemTemplate($subReplyItem);

					$subReplies .= $subReplyTemplate;
				}
				$replyTemplate =~ s/<replies><\/replies>/$subReplies/;
			} else {
				$replyTemplate =~ s/<replies><\/replies>//;
			}

			if ($replyTemplate) {
				$allReplies .= $replyTemplate;
			} else {
				WriteLog('Warning:  replyTemplate is missing for some reason!');
			}
		}

		$itemTemplate =~ s/<replies><\/replies>/$allReplies/;
	}

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	if (GetConfig('replies') == 1) {
		my $replyForm;
		my $replyTag = GetTemplate('replytag.template');
		my $replyFooter;
		my $replyTo;
		my $prefillText;
		my $fileContents;

		$fileContents = GetFile($file{'file_path'});

		$replyForm = GetTemplate('form/reply.template');
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

	if ($file{'vote_buttons'}) {
#		my $ballotTime = time();
#		$txtIndex .= GetTemplate("form/itemvote.template");
#
#		my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
#		$txtIndex =~ s/\$voterButtons/$voterButtons/g;
	}


	# end page with footer
	$txtIndex .= GetPageFooter();

	#Inject necessary javascript
	my $scriptInject = GetTemplate('scriptinject.template');

	#avatar.js
	my $avatarjs = GetTemplate('js/avatar.js.template');

	#formencode.js
	my $formEncodeJs = GetTemplate('js/formencode.js.template');

	#add them together
	my $fullJs = $avatarjs . "\n" . $formEncodeJs;

	#replace the scripts in scriptinject.template
	$scriptInject =~ s/\$javascript/$fullJs/g;

	#add to the end of the page
	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
}

sub GetHtmlLink {
	my $hash = shift;

	#todo sanity check

	#todo templatize this
	return '<a href="/' . GetHtmlFilename($hash) . '">' . substr($hash, 0, 8) . '..</a>';
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
	# template_name = item/item.template by default
	# remove_token = token to remove (for reply tokens)

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

		my $alias;

		my $isAdmin = 0;

		my $message;
		my $messageCacheName = "./cache/" . GetMyVersion() . "/message/$gitHash";
		WriteLog('$messageCacheName (2) = ' . $messageCacheName);


		if (-e $messageCacheName) {
			$message = GetFile($messageCacheName);
		} else {
			$message = GetFile($file{'file_path'});
		}

		if ($file{'remove_token'}) {
			$message =~ s/$file{'remove_token'}//g;
			$message = trim($message);
			#todo there is a bug here, but it is less significant than the majority of cases
			#todo make it so that post does not need to be trimmed, but extra \n\n after the token is removed
		}

		$message = FormatForWeb($message);

		#$message =~ s/([a-f0-9]{40})/<a href="\/$1.html">$1<\/a>/g;
		#$message =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2$3.html">$1$2..<\/a>/g;
		#$message =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2.html">$1$2..<\/a>/g;
		$message =~ s/([a-f0-9]{40})/GetHtmlLink($1)/eg;

		if ($file{'format_avatars'}) {
			$message =~ s/([A-F0-9]{16})/GetHtmlAvatar($1)/eg;
		}

		#hint GetHtmlFilename()
		#todo verify that the items exist before turning them into links,
		# so that we don't end up with broken links

		#$message =~ s/([A-F0-9]{16})/xxx/g;

		if (
			$isSigned
				&&
			IsAdmin($gpgKey)
		) {
			$isAdmin = 1;
		}

		$alias = HtmlEscape($alias);

		my $itemTemplate = '';
		if ($file{'template_name'}) {
			$itemTemplate = GetTemplate($file{'template_name'});
		} else {
			if (length($message) > GetConfig('item_long_threshold')) {
				$itemTemplate = GetTemplate("item/itemlong.template");
			} else {
				$itemTemplate = GetTemplate("item/item.template");
			}
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
#		my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";
		my $permalinkHtml = '/' . GetHtmlFilename($gitHash);

#		$permalinkTxt =~ s/^\.//;
		$permalinkTxt =~ s/html\//\//;

		my $itemText = $message;
		my $fileHash = GetFileHash($file{'file_path'});
		my $itemName;
		if ($file{'display_full_hash'}) {
			$itemName = $fileHash;
		} else {
			$itemName = substr($fileHash, 0, 8) . '..';
		}

		#my $replyCount = $file{'child_count'};

		my $borderColor = '#' . substr($fileHash, 0, 6);

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;

#		if ($replyCount) {
#			$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
#		} else {
#			$itemTemplate =~ s/\$replyCount//g;
#		}
#
		if ($file{'show_vote_summary'}) {
			#todo templatize this
			#this displays the vote summary (tags applied and counts)
			my $votesSummary = '';
			my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});

			my @quickVotesList;

			my $quickVotesForTags = GetConfig('tagset/' . 'all');
			if ($quickVotesForTags) {
				push @quickVotesList, split("\n", $quickVotesForTags);
			}

			foreach my $voteTag (keys %voteTotals) {
				$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";

				my $quickVotesForTags = GetConfig('tagset/' . $voteTag);
				if ($quickVotesForTags) {
					push @quickVotesList, split("\n", $quickVotesForTags);
				}
			}
			if ($votesSummary) {
				$votesSummary = '<p>' . $votesSummary . '</p>';
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;

			{
				my $quickVoteTemplate = GetTemplate('votequick.template');
				my $tagButtons = '';
				foreach my $quickTagValue (@quickVotesList) {
					my $ballotTime = time();
					if ($fileHash && $ballotTime) {
						my $mySecret = GetConfig('secret');
						my $checksum = md5_hex($fileHash . $ballotTime . $mySecret);

						my $tagButton = GetTemplate('vote2button.template');

						my $quickTagCaption = GetString($quickTagValue);

						$tagButton =~ s/\$fileHash/$fileHash/g;
						$tagButton =~ s/\$ballotTime/$ballotTime/g;
						$tagButton =~ s/\$voteValue/$quickTagValue/g;
						$tagButton =~ s/\$voteCaption/$quickTagCaption/g;
						$tagButton =~ s/\$class/vb tag-$quickTagValue/g; #.vb class? css
						$tagButton =~ s/\$checksum/$checksum/g;

						$tagButtons .= $tagButton;
					}
				}

				$quickVoteTemplate =~ s/\$quickVoteButtons/$tagButtons/;

				$itemTemplate =~ s/\$quickVoteButtonGroup/$quickVoteTemplate/;
			}

			#
			#end of tag summary display
		} else {
			$itemTemplate =~ s/\$quickVoteButtonGroup//g;
			$itemTemplate =~ s/\$votesSummary//g;
		}

		return $itemTemplate;
	}
}

sub GetPageFooter {
	my $txtFooter = GetTemplate('htmlend.template');

	my $disclaimer = GetConfig('string/en/disclaimer') . "\n" . GetConfig('string/ru/disclaimer');

	$txtFooter =~ s/\$disclaimer/$disclaimer/g;

	my $timeBuilt = time();

	my $timestamp = strftime('%F %T', localtime($timeBuilt));
	my $myVersion = GetMyVersion();
	#my $gpgVersion = GetGpgMajorVersion();

	my $myVersionPrettyLink = '<a href="/' . substr($myVersion, 0, 2) . '/' . substr($myVersion, 2) . '.html">' . substr($myVersion, 0, 8) . '..' . '</a>';

	my $footer = "<span title=\"This page was created at $timestamp\">$timeBuilt</span> ; <span title=\"Version Number\">$myVersionPrettyLink</span> ; ";

	my $menuTemplate = "";

	$menuTemplate .= GetMenuItem("/stats.html", 'Stats');
	$menuTemplate .= GetMenuItem("/top/admin.html", 'Admin');
	$menuTemplate .= GetMenuItem("/clone.html", 'Clone');
	$menuTemplate .= GetMenuItem("/index0.html", 'Abyss');
	$menuTemplate .= GetMenuItem("/tags.html", GetString('menu/tags'));
	$menuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));

	$footer .= $menuTemplate;

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
		#$logoText = FormatForWeb($logoText);
		#$logoText = HtmlEscape($logoText);
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
#
#	my @availablePatterns = glob('template/pattern/*.template');
#	my $randomNumber = int(rand(@availablePatterns));
#	my $patternName = $availablePatterns[$randomNumber];
#	$patternName =~ s/^template\///;

	#my $patternName = 'pattern/bokeh.template';
	my $patternName = trim(GetConfig('header_pattern'));
	my $introText = trim(GetConfig('intro_text'));
	$patternName = GetConfig('header_pattern');

	my $headerBackgroundPattern = GetTemplate($patternName);
	WriteLog("$headerBackgroundPattern");
	$styleSheet =~ s/\$headerBackgroundPattern/$headerBackgroundPattern/g;
	WriteLog($styleSheet);

	#$styleSheet =~ s/\w\w/ /g;

	# Get the HTML page template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title
	$htmlStart =~ s/\$logoText/$logoText/g;
	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$titleHtml/$titleHtml/g;
	$htmlStart =~ s/\$title/$title/g;
	$htmlStart =~ s/\$primaryColor/$primaryColor/g;
	$htmlStart =~ s/\$secondaryColor/$secondaryColor/g;
	$htmlStart =~ s/\$textColor/$textColor/g;
	$htmlStart =~ s/\$disabledColor/$disabledColor/g;
	$htmlStart =~ s/\$disabledTextColor/$disabledTextColor/g;
	$htmlStart =~ s/\$orangeColor/$orangeColor/g;
	$htmlStart =~ s/\$neutralColor/$neutralColor/g;
	$htmlStart =~ s/\$highlightColor/$highlightColor/g;
	$htmlStart =~ s/\$introText/$introText/g;

	my $menuTemplate = "";

	#todo replace with config/menu/*

	#$menuTemplate .= GetMenuItem("/", GetString('menu/home'));
	$menuTemplate .= GetMenuItem("/write.html", GetString('menu/write'));
#	$menuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));
	$menuTemplate .= GetMenuItem("/top/pubkey.html", 'Authors');
	$menuTemplate .= GetMenuItem("/top/hastext.html", 'Texts');
	#$menuTemplate .= GetMenuItem("/stats.html", GetString('menu/stats'));
	$menuTemplate .= GetMenuItem("/manual.html", 'Manual');
	#$menuTemplate .= GetMenuItem("/index0.html", GetString('menu/abyss'));
	#$menuTemplate .= GetMenuItem("/profile.html", 'Account');
	#$menuTemplate .= GetMenuItem("/clone.html", GetString('menu/clone'));
	#$menuTemplate .= GetMenuItem("/top/admin.html", 'Admin');

#	my $adminKey = GetAdminKey();
#	if ($adminKey) {
#		$menuTemplate .= GetMenuItem('/author/' . $adminKey . '/', 'Admin');
#	}

	$htmlStart =~ s/\$menuItems/$menuTemplate/g;

	my $identityLink = GetMenuItem("/profile.html", GetString('menu/sign_in'));
	$htmlStart =~ s/\$loginLink/$identityLink/g;

	$txtIndex .= $htmlStart;

	return $txtIndex;
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
		my @tagsListList = qw(tags tags2 johari nohari rhetoric emotions flags);
		my @voteValues;

		foreach (@tagsListList) {
			if (scalar(@voteValues)) {
				push @voteValues, '--';
			}
			my $tagsList = GetConfig("$_");
			chomp $tagsList;
			push @voteValues, split("\n", $tagsList);
		}

		foreach my $tag (@voteValues) {
			if ($tag eq '--') {
				$voteButtonsTemplate .= "<hr>\n";
				next;
			}
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
	my $pageParam;

	my @files;

	my $authorKey;

	if (defined($pageType)) {
		if ($pageType eq 'author') {
			$pageParam = shift;
			$authorKey = $pageParam;

			my $whereClause = "WHERE author_key='$authorKey'";

			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			if (IsAdmin($authorKey)) {
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
			$pageParam = shift;
			my $tagName = $pageParam;
			chomp($tagName);

			$title = "$tagName, posts with tag";
			$titleHtml = $title;

			my %queryParams;
			$queryParams{'join_clause'} = "JOIN vote ON (item_flat.file_hash = vote.file_hash)";
			$queryParams{'group_by_clause'} = "GROUP BY vote.file_hash";
			$queryParams{'where_clause'} = "WHERE vote.vote_value = '$tagName'";
			$queryParams{'order_clause'} = "ORDER BY item_flat.add_timestamp DESC";
			$queryParams{'limit_clause'} = "LIMIT 100"; #todo fix hardcoded limit

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
		my $authorInfo = GetTemplate('authorinfo.template');

		my $authorAliasHtml = GetAlias($authorKey);
		my $authorAvatarHtml = GetAvatar($authorKey);
		my $authorImportance = 1337;

		$authorInfo =~ s/\$avatar/$authorAvatarHtml/;
		$authorInfo =~ s/\$alias/$authorAliasHtml/;
		$authorInfo =~ s/\$fingerprint/$authorKey/;
		$authorInfo =~ s/\$importance/$authorImportance/;

		$txtIndex .= $authorInfo;
	}

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		WriteLog("DBAddItemPage (1)");
		DBAddItemPage($pageType, $pageParam, $row->{'file_hash'});

		if ($file && -e $file) {
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

			if ($isSigned && IsAdmin($gpgKey)) {
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

			WriteLog('GetTemplate("item/item.template") 2');
			my $itemTemplate = '';
			if ($message) {
				$itemTemplate = GetItemTemplate($row);

#				if (length($message) > GetConfig('item_long_threshold')) {
#					$itemTemplate = GetTemplate("item/itemlong.template");
#				}
#				else {
#					$itemTemplate = GetTemplate("item/item.template");
#				}
#
#				my $itemClass = "txt $signedCss";
#
#				my $authorUrl;
#				my $authorAvatar;
#				my $authorLink;
#
#				if ($gpgKey) {
#					$authorUrl = "/author/$gpgKey/";
#					$authorAvatar = GetAvatar($gpgKey);
#
#					$authorLink = GetTemplate('authorlink.template');
#
#					$authorLink =~ s/\$authorUrl/$authorUrl/g;
#					$authorLink =~ s/\$authorAvatar/$authorAvatar/g;
#				}
#				else {
#					$authorLink = "";
#				}
#				my $permalinkTxt = $file;
#				#$permalinkTxt =~ s/^\.//;
#				$permalinkTxt =~ s/html\//\//g;
#
#				my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";
#
#				my $itemText = FormatForWeb($message);
#
#				$itemText =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2$3.html">$1$2..<\/a>/g;
#				#todo verify that the items exist before turning them into links,
#				# so that we don't end up with broken links
#
#				my $fileHash = GetFileHash($file);
#				my $itemName = substr($gitHash, 0, 8) . '..';
#				my $ballotTime = time();
#				my $replyCount = $row->{'child_count'};
#
#				my $borderColor = '#' . substr($fileHash, 0, 6);
#
#				$itemTemplate =~ s/\$borderColor/$borderColor/g;
#				$itemTemplate =~ s/\$itemClass/$itemClass/g;
#				$itemTemplate =~ s/\$authorLink/$authorLink/g;
#				$itemTemplate =~ s/\$itemName/$itemName/g;
#				$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
#				$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
#				$itemTemplate =~ s/\$itemText/$itemText/g;
#				$itemTemplate =~ s/\$fileHash/$fileHash/g;
#
#				if ($replyCount) {
#					$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
#				} else {
#					$itemTemplate =~ s/\$replyCount//g;
#				}
#
#				#todo templatize this
#				#this displays the vote summary (tags applied and counts)
#				my $votesSummary = '';
#				my %voteTotals = DBGetItemVoteTotals($fileHash);
#
#				foreach my $voteTag (keys %voteTotals) {
#					$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
#				}
#				if ($votesSummary) {
#					$votesSummary = '<p>' . $votesSummary . '</p>';
#				}
#				$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
#				#
#				#end of tag summary display
#
#
#				WriteLog("Call to GetVoterTemplate() :881");
#				my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
#				$itemTemplate =~ s/\$voterButtons/$voterButtons/g;
			} else {
				$itemTemplate = '<hr>Problem decoding message</hr>';
				WriteLog('Something happened and there is no $message where I expected it... Oh well, moving on.');
			}

			$txtIndex .= $itemTemplate;
		}
	}

	#	$txtIndex .= GetTemplate('voteframe.template');

	# Add javascript warning to the bottom of the page
	$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs;
	if ($pageType eq 'author') {
		$avatarjs = GetTemplate('js/avatar.authorpage.js.template');
	} else {
		$avatarjs = GetTemplate('js/avatar.js.template');
	}
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;


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

	$txtIndex .= $htmlStart;

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	$txtIndex .= GetTemplate('maincontent.template');

	my $itemList = '';

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		if ($file && -e $file) {
			my $gitHash = $row->{'file_hash'};

			WriteLog('DBAddItemPage (2)');
			#DBAddItemPage('index', $currentPageNumber, $gitHash);

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

			#$message =~ s/([a-f0-9]{8})([a-f0-9]{32})/<a href="\/$1$2.html">$1..<\/a>/g;
			#$message =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2.html">$1$2..<\/a>/g;
			$message =~ s/([a-f0-9]{40})/GetHtmlLink($1)/eg;
			$message =~ s/([A-F0-9]{16})/GetHtmlAvatar($1)/eg;
			#hint GetHtmlFilename
			#todo verify that the items exist before turning them into links,
			# so that we don't end up with broken links

			if ($isSigned && IsAdmin($gpgKey)) {
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

			#todo $alias = GetAlias($gpgKey);

			$alias = HtmlEscape($alias);

			WriteLog('GetTemplate("item/item.template") 1');

			my $itemTemplate = '';
			if (length($message) > GetConfig('item_long_threshold')) {
				$itemTemplate = GetTemplate("item/itemlong.template");
			} else {
				$itemTemplate = GetTemplate("item/item.template");
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
			#my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";
			my $permalinkHtml = '/' . GetHtmlFilename($gitHash);

			my $permalinkTxt = $file;
			#			$permalinkTxt =~ s/^\.//;
			$permalinkTxt =~ s/html\//\//g;

			my $itemText = $message;
			my $fileHash = GetFileHash($file);
			my $itemName = substr($gitHash, 0, 8) . "..";

			#			my $ballotTime = time();

#			my $replyCount = $row->{'child_count'};

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
#			if ($replyCount) {
#				$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
#			} else {
#				$itemTemplate =~ s/\$replyCount//g;
#			}

			if (index($itemTemplate, '$quickVoteButtonGroup')) {
				$itemTemplate =~ s/\$quickVoteButtonGroup//g;
			}

			if (index($itemTemplate, '$votesSummary')) {
				#only make the votes summary if the template needs it
				#this displays the vote summary (tags applied and counts)
				my $votesSummary = '';
				my %voteTotals = DBGetItemVoteTotals($fileHash);

				foreach my $voteTag (keys %voteTotals) {
					$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
				}
				if ($votesSummary) {
					$votesSummary = '<p>' . $votesSummary . '</p>';
				}
				$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
			}
			#
			#end of tag summary display


			#my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
			#$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

			#$txtIndex .= $itemTemplate;
			$itemList = $itemTemplate . $itemList;
		}
	}

	$txtIndex .= $itemList;

	#	$txtIndex .= GetTemplate('voteframe.template');

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	# Add javascript warning to the bottom of the page
	$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	#$txtIndex =~ s/<\/body>/\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
}

sub WriteIndexPages {
	my $pageLimit = GetConfig('page_limit');
	if (!$pageLimit) {
		$pageLimit = 250;
	}
	#my $PAGE_THRESHOLD = 5;

	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	my $overlapPage = GetConfig('overlap_page');
	#in order to keep both the "last" and the "first" page the same length
	#and avoid having mostly-empty pages with only a few items
	#we introduce an overlap on page 5, where some items are displayed
	#twice. this also allows us to only update the first 5 plus all affected
	#when a new item is added, instead of the whole catalog
	#todo does not work as expected, fix it

	if (defined($itemCount) && $itemCount && $itemCount > 0) {
		my $i;

		WriteLog("\$itemCount = $itemCount");

		my $lastPage = ceil($itemCount / $pageLimit);

		for ($i = 0; $i < $lastPage; $i++) {
			my %queryParams;
			my $offset = $i * $pageLimit;

			#$queryParams{'where_clause'} = "WHERE item_type = 'text' AND IFNULL(parent_count, 0) = 0";

			if ($overlapPage && $lastPage > $overlapPage && $i > $overlapPage) {
				$offset = $offset - ($itemCount % $pageLimit);
			}
			$queryParams{'limit_clause'} = "LIMIT $pageLimit OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp';

			my @ft = DBGetItemList(\%queryParams);

			my $indexPage;
			if ($lastPage > 1) {
				$indexPage = GetIndexPage(\@ft, $i);
			} else {
				$indexPage = GetIndexPage(\@ft);
			}

			if ($i < $lastPage-1) {
				PutHtmlFile("html/index$i.html", $indexPage);
			} else {
				if (GetConfig('home_page_auto')) {
					PutHtmlFile("html/index.html", $indexPage);
				}
				PutHtmlFile("html/index$i.html", $indexPage);
			}
		}
	} else {
		my $indexPage = GetPageHeader(GetConfig('home_title'), GetConfig('home_title'));

		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';

		$indexPage .= GetPageFooter();

		PutHtmlFile('html/index.html', $indexPage);
	}
}

1;
