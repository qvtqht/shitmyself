use strict;
use warnings;

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

my $HTMLDIR = "html";

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

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
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
		$message =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2$3.html">$1$2..<\/a>/g;
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
		my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";

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
			$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
		} else {
			$itemTemplate =~ s/\$replyCount//g;
		}

		#todo templatize this
		#this displays the vote summary (tags applied and counts)
		my $votesSummary = '';
		my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});

		foreach my $voteTag (keys %voteTotals) {
			$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
		}
		if ($votesSummary) {
			$votesSummary = '<p>' . $votesSummary . '</p>';
		}
		$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
		#
		#end of tag summary display


		WriteLog("Call to GetVoterTemplate() :309");
		my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
		$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

		return $itemTemplate;
	}
}

sub GetPageFooter {
	my $txtFooter = GetTemplate('htmlend.template');

	my $timeBuilt = time();

	my $timestamp = strftime('%F %T', localtime($timeBuilt));
	my $myVersion = GetMyVersion();
	#my $gpgVersion = GetGpgMajorVersion();

	my $myVersionPrettyLink = '<a href="/' . $myVersion . '.html">' . substr($myVersion, 0, 8) . '..' . '</a>';

	my $footer = "<span title=\"This page was created at $timestamp\">$timeBuilt</span> ; <span title=\"Version Number\">$myVersionPrettyLink</span>";

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

	my $menuTemplate = "";

	$menuTemplate .= GetMenuItem("/", 'Home');
	$menuTemplate .= GetMenuItem("/write.html", GetString('menu/write'));
	$menuTemplate .= GetMenuItem("/tags.html", GetString('menu/tags'));
	$menuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));
	$menuTemplate .= GetMenuItem("/about.html", GetString('menu/about'));
	#$menuTemplate .= GetMenuItem("/identity.html", 'Account');
	#	$menuTemplate .= GetMenuItem("/clone.html", GetString('menu/clone'));

#	my $adminKey = GetAdminKey();
#	if ($adminKey) {
#		$menuTemplate .= GetMenuItem('/author/' . $adminKey . '/', 'Admin');
#	}

	$htmlStart =~ s/\$menuItems/$menuTemplate/g;

	my $identityLink = GetMenuItem("/identity.html", GetString('menu/sign_in'));
	$htmlStart =~ s/\$loginLink/$identityLink/g;

	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetVoterTemplate {
	my $fileHash = shift;
	my $ballotTime = shift;
	my $tagsListName = shift;

	chomp $fileHash;
	chomp $ballotTime;

	if (!$tagsListName) {
		$tagsListName = 'tags';
	} else {
		chomp $tagsListName;
	}

	#todo move this to GetConfig()
	if (!-e "config/secret") {
		my $randomHash = GetRandomHash();

		PutConfig("secret", $randomHash);
	}
	my $mySecret = GetConfig("secret");

	state $voteButtonsTemplate;

	if (!defined($voteButtonsTemplate)) {
		#my $tagsList = GetConfig('tags');
		my $tagsList = GetConfig($tagsListName);
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

				my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";

				my $itemText = FormatForWeb($message);

				$itemText =~ s/([a-f0-9]{2})([a-f0-9]{6})([a-f0-9]{32})/<a href="\/$1\/$2$3.html">$1$2..<\/a>/g;
				#todo verify that the items exist before turning them into links,
				# so that we don't end up with broken links

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
					$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
				} else {
					$itemTemplate =~ s/\$replyCount//g;
				}

				#todo templatize this
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
				#
				#end of tag summary display


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

sub GetMenuItem {
	my $address = shift;
	my $caption = shift;

	my $menuItem = GetTemplate('menuitem.template');

	$menuItem =~ s/\$address/$address/g;
	$menuItem =~ s/\$caption/$caption/g;

	return $menuItem;
}

1;