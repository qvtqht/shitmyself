use strict;
use warnings;

use utf8;
use 5.010;

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Data::Dumper;
#use List::Uniq ':all';

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

sub GetStylesheet {
	my $style = GetTemplate('style.template');

	if (GetConfig('html/color_avatars')) {
		$style .= "\n" . GetTemplate('style.avatar.template');
	}

	return $style;
}

sub GetAuthorLink { # returns avatar'ed link for an author id
	my $gpgKey = shift;
	my $showPlain = shift;

	if (!$showPlain) {
		$showPlain = 0;
	} else {
		$showPlain = 1;
	}

	if (!IsFingerprint($gpgKey)) {
		WriteLog("WARNING: GetAuthorLink() called with invalid parameter!");
		return;
	}

	my $authorUrl = "/author/$gpgKey/";

	my $authorAvatar = '';
	if ($showPlain) {
		$authorAvatar = GetPlainAvatar($gpgKey);
	} else {
		$authorAvatar = GetAvatar($gpgKey);
	}

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

sub GetEventsPage {
	WriteLog('GetEventsPage()');

	my $txtPage = '';

	my $title = 'Upcoming Events';
	my $titleHtml = 'Upcoming Events';

	$txtPage = GetPageHeader($title, $titleHtml, 'events');

	$txtPage .= GetTemplate('maincontent.template');

	my $eventsArrayRef = DBGetEvents();
	my @events = @{$eventsArrayRef};

	WriteLog('GetEventsPage: Found ' . scalar(@events) . ' items returned from DBGetEvents()');

	my $eventsItemsList = '';

	while (@events) {
		my $event = shift @events;
		my @eventA = @{$event};

		my $eventItem = GetTemplate('event/event_item.template');

		my $eventItemHash = $eventA[3];
		my $eventTitle = $eventA[0];
		my $eventTime = $eventA[1];
		my $eventDuration = $eventA[2];
		my $eventItemLink = GetHtmlLink($eventItemHash);
		my $eventItemAuthor = GetAvatar($eventA[4]);

		if (!$eventTitle) {
			$eventTitle = 'Untitled';
		}

		if ($eventTitle) {
			$eventTitle = '<a href="' . GetHtmlFilename($eventItemHash) . '">' . $eventTitle . '</a>';
		}

		if (!$eventItemAuthor) {
			$eventItemAuthor = '';
		}

		my $eventTimeUntil = $eventTime + $eventDuration;
#		my $eventTimeUntil = $eventTime - GetTime();
#		if ($eventTimeUntil > 0) {
#			$eventTimeUntil = 'in ' . GetSecondsHtml($eventTimeUntil);
#		} else {
#			$eventTimeUntil = $eventTimeUntil * -1;
#			$eventTimeUntil = GetSecondsHtml($eventTimeUntil) . ' ago';
#		}

		if ($eventTime) {
#			$eventTime = EpochToHuman($eventTime);
		} else {
			$eventTime = '(no time)';
		}

		if ($eventDuration) {
			$eventDuration = GetSecondsHtml($eventDuration);
		} else {
			$eventDuration = '(no duration)';
		}

		my $eventVoteButtons = GetItemVoteButtons($eventItemHash, 'event');

		$eventItem =~ s/\$eventTitle/$eventTitle/;
		$eventItem =~ s/\$eventTime/$eventTime/;
		$eventItem =~ s/\$eventTimeUntil/$eventTimeUntil/;
		$eventItem =~ s/\$eventDuration/$eventDuration/;
		$eventItem =~ s/\$eventItemLink/$eventItemLink/;
		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
		$eventItem =~ s/\$voteButtons/$eventVoteButtons/;

		$eventsItemsList .= $eventItem;
	}

	my $eventsList = GetTemplate('event/event_list.template');

	$eventsList =~ s/\$eventsList/$eventsItemsList/;

	$txtPage .= $eventsList;

	$txtPage .= GetPageFooter();

	$txtPage = InjectJs($txtPage, qw(avatar fresh prefs timestamps));

	return $txtPage;

}

sub GetVotesPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags';
	my $titleHtml = 'Tags';

	$txtIndex = GetPageHeader($title, $titleHtml, 'tags');

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts = DBGetVoteCounts();

	my @voteCountsArray = @{$voteCounts};

	my $voteItemsWrapper = GetTemplate('tag_listing_wrapper.template');

	my $voteItems = '';

	while (@voteCountsArray) {
		my $voteItemTemplate = GetTemplate('tag_listing.template');
		#todo don't need to do this every time

		my $tag = shift @voteCountsArray;

		my $tagName = @{$tag}[0];
		my $tagCount = @{$tag}[1];

		my $tagInfo = '';
		if ($tagInfo = GetConfig('string/en/tag_info/'.$tagName)) {
			#great
		} else {
			$tagInfo = '';
		}

		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName/g;
		$voteItemTemplate =~ s/\$tagCount/$tagCount/g;
		$voteItemTemplate =~ s/\$tagInfo/$tagInfo/g;

		$voteItems .= $voteItemTemplate;
	}

	$txtIndex .= '<p><b>Popular</b> <a href="/tags_alpha.html">Alphabetical</a></p>';

	$voteItemsWrapper =~ s/\$tagListings/$voteItems/g;

	$txtIndex .= $voteItemsWrapper;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs));

	return $txtIndex;
}

sub GetTagsPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags Alpha';
	my $titleHtml = 'Tags Alpha';

	$txtIndex = GetPageHeader($title, $titleHtml, 'tags');

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts = DBGetVoteCounts('ORDER BY vote_value'); #todo sql shouldn't be here

	my @voteCountsArray = @{$voteCounts};

	my $voteItemsWrapper = GetTemplate('tag_listing_wrapper.template');

	my $voteItems = '';

	while (@voteCountsArray) {
		my $voteItemTemplate = GetTemplate('tag_listing.template');
		#todo don't need to do this every time

		my $tag = shift @voteCountsArray;

		my $tagName = @{$tag}[0];
		my $tagCount = @{$tag}[1];

		my $tagInfo = '';
		if ($tagInfo = GetConfig('string/en/tag_info/'.$tagName)) {
			#great
		} else {
			$tagInfo = '';
		}

		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName/g;
		$voteItemTemplate =~ s/\$tagInfo/$tagInfo/g;
		$voteItemTemplate =~ s/\$tagCount/$tagCount/g;

		$voteItems .= $voteItemTemplate;
	}

	$txtIndex .= '<p><a href="/tags.html">Popular</a> <b>Alphabetical</b></p>';
	#todo this should not be part of maincontent

	$voteItemsWrapper =~ s/\$tagListings/$voteItems/g;

	$txtIndex .= $voteItemsWrapper;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs));

	return $txtIndex;
}

sub GetItemTemplateFromHash {
		my $itemHash = shift;
		my $insetPrefix = shift;

		if (IsSha1($itemHash)) {
	#		my $itemTemplate;
	#		if ($insetPrefix && $insetPrefix eq '>>') {
	#			my %queryParams;
	#			$queryParams{'where_clause'} = "WHERE file_hash IN('$itemHash')";
	#
	#			my @files = DBGetItemList(\%queryParams);
	#
	#			$itemTemplate = GetItemTemplate($files[0]);
	#		} else {
	#			$itemTemplate = GetHtmlLink($itemHash);
	#		}
	#		return $itemTemplate;
	#	} else {
	#		WriteLog("Warning! GetItemTemplateFromHash called with improper parameter!");
	#		return '[item could not be displayed]';
		}
	#
	#	WriteLog("Something is terribly wrong! GetItemTemplateFromHash");
	#	return '[aaaaahhhh!!!]';
}

sub GetItemPage {
	#returns html for individual item page

	my %file = %{shift @_};
	my $fileHash = $file{'file_hash'};

	WriteLog("GetItemPage(" . $file{'file_path'} . ")");

	my $txtIndex = "";

	my $filePath = $file{'file_path'};

	my $title = '';
	my $titleHtml = '';

	if (defined($file{'item_title'}) && $file{'item_title'}) {
		WriteLog("GetItemPage: defined(item_title) = true!");

		$title = HtmlEscape($file{'item_title'});
		$titleHtml = HtmlEscape($file{'item_title'});

		$title .= ' (' . substr($file{'file_hash'}, 0, 8) . '..)';
	} else {
		WriteLog("GetItemPage: defined(item_title) = false!");

		$title = $file{'file_hash'};
		$titleHtml = $file{'file_hash'};
	}

	if (defined($file{'author_key'}) && $file{'author_key'}) {
		# todo the .txt extension should not be hard-coded
		my $alias = GetAlias($file{'author_key'});
		$alias = HtmlEscape($alias);

		$title .= " by $alias";
	}

	# Get the HTML page template
	my $htmlStart = GetPageHeader($title, $titleHtml, 'item');

	$txtIndex .= $htmlStart;

	$txtIndex .= GetTemplate('maincontent.template');

	#$file{'vote_buttons'} = 1;
	$file{'display_full_hash'} = 1;
	$file{'show_vote_summary'} = 1;
	$file{'show_quick_vote'} = 1;
	$file{'vote_buttons'} = 1;
	$file{'format_avatars'} = 1;

	my $itemTemplate = GetItemTemplate(\%file);

	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	if ($file{'child_count'}) {
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		WriteLog('@itemReplies = ' . @itemReplies);

		#$txtIndex .= "<hr size=1>";
		my $allReplies = '';

		$allReplies = '<hr size=3>' . $allReplies;

		my $replyComma = '';

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
				my $subRepliesTemplate = '';

				my $subReplyComma = '';

				my @subReplies = DBGetItemReplies($$replyItem{'file_hash'});
				foreach my $subReplyItem (@subReplies) {
					#$subRepliesTemplate .= $$subReplyItem{'fi
					# le_hash'};
					$$subReplyItem{'template_name'} = 'item/item-small.template';
					$$subReplyItem{'remove_token'} = '>>' . $$replyItem{'file_hash'};

					WriteLog('$$subReplyItem{\'remove_token\'} = \'>>\' . $$subReplyItem{\'file_hash\'}');
					WriteLog($$subReplyItem{'remove_token'} . ',' . $$subReplyItem{'file_hash'});

					my $subReplyTemplate = GetItemTemplate($subReplyItem);

					if ($subReplyComma eq '') {
						$subReplyComma = '<hr size=4>';
					} else {
						$subReplyTemplate = $subReplyComma . $replyTemplate;
					}

					$subRepliesTemplate .= $subReplyTemplate;
				}
				$replyTemplate =~ s/<replies><\/replies>/$subRepliesTemplate/;
			} else {
				$replyTemplate =~ s/<replies><\/replies>//;
			}

			if ($replyTemplate) {
				if ($replyComma eq '') {
					$replyComma = '<hr size=5>';
				} else {
					$replyTemplate = $replyComma . $replyTemplate;
				}

				$allReplies .= $replyTemplate;
			} else {
				WriteLog('Warning: replyTemplate is missing for some reason!');
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

	if ($file{'vote_buttons'} && GetConfig('enable_checkboxes')) {
		my $ballotTime = GetTime();
		my $voterTemplate .= GetTemplate("form/itemvote.template");

		my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
		$voterTemplate =~ s/\$voterButtons/$voterButtons/g;

		$txtIndex .= $voterTemplate;
	}


	# end page with footer
	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar formencode prefs));

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
}

sub GetHtmlLink {
	my $hash = shift;

	if ($hash) {
		#todo templatize this
		return '<a href="/' . GetHtmlFilename($hash) . '">' . substr($hash, 0, 8) . '..</a>';
	} else {
	}
}

sub GetItemVoteButtons { # get vote buttons for item in html form
# $fileHash = item's file hash
	my $fileHash = shift;

	#todo sanity checks

	my @quickVotesList;

	my $tagSet;
	$tagSet = shift;

	if ($tagSet) {
		my $quickVotesForTagSet = GetConfig('tagset/' . $tagSet);
		if ($quickVotesForTagSet) {
			push @quickVotesList, split("\n", $quickVotesForTagSet);
		}
	} else {
		my $quickVotesForTags;
		my %voteTotals = DBGetItemVoteTotals($fileHash);

		foreach my $voteTag (keys %voteTotals) {
			$quickVotesForTags = GetConfig('tagset/' . $voteTag);
			if ($quickVotesForTags) {
				push @quickVotesList, split("\n", $quickVotesForTags);
			}
		}

		$quickVotesForTags = GetConfig('tagset/' . 'all');
		if ($quickVotesForTags) {
			unshift @quickVotesList, split("\n", $quickVotesForTags);
		}

		my %dedupe = map { $_, 1 } @quickVotesList;
		@quickVotesList = keys %dedupe;
	}

	my $styleSheet = GetStylesheet();

	my $quickVoteTemplate = GetTemplate('votequick.template');
	my $tagButtons = '';
	my $doVoteButtonStyles = GetConfig('style_vote_buttons');

	foreach my $quickTagValue (@quickVotesList) {
		my $ballotTime = GetTime();
		if ($fileHash && $ballotTime) {
			my $mySecret = GetConfig('admin/secret');
			my $checksum = md5_hex($fileHash . $ballotTime . $mySecret);

			my $tagButton = GetTemplate('vote2button.template');

			my $quickTagCaption = GetString($quickTagValue);

			if ($doVoteButtonStyles) {
				# this is a hack, eventually should be replaced by config/tag_color #todo
				if (index($styleSheet, "tag-$quickTagValue") > -1) {
					$tagButton =~ s/\$class/tag-$quickTagValue/g;
				} else {
					$tagButton =~ s/class="\$class"//g;
				}
			}

			$tagButton =~ s/\$fileHash/$fileHash/g;
			$tagButton =~ s/\$ballotTime/$ballotTime/g;
			$tagButton =~ s/\$voteValue/$quickTagValue/g;
			$tagButton =~ s/\$voteCaption/$quickTagCaption/g;
			$tagButton =~ s/\$checksum/$checksum/g;

			$tagButtons .= $tagButton;
		}
	}

	return $tagButtons;
}

sub GetItemVotesSummary {
	my $fileHash = shift;

	#todo sanity checks

	my %voteTotals = DBGetItemVoteTotals($fileHash);

	my $votesSummary = '';

	foreach my $voteTag (keys %voteTotals) {
		$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
	}
	if ($votesSummary) {
		$votesSummary = $votesSummary;
	}

	return $votesSummary;
}

sub GetItemTemplate { # returns HTML for outputting one item
	WriteLog("GetItemTemplate");

	# %file(hash for each file)
	# file_path = file path including filename
	# file_hash = git's hash of the file's contents
	# author_key = gpg key of author (if any)
	# add_timestamp = time file was added as unix_time #todo
	# child_count = number of replies
	# display_full_hash = display full hash for file
	# template_name = item/item.template by default
	# remove_token = token to remove (for reply tokens)
	# show_vote_summary = shows item's list and count of tags
	# show_quick_vote = displays quick vote buttons
	# item_title = title
	# tags_list = comma-separated list of tags the item has
	# is_textart = set <tt><code> tags for the message itself

	# get %file hash from supplied parameters
	my %file = %{shift @_};

	# verify that referenced file path exists
	if (-e $file{'file_path'}) {
		my $gitHash = $file{'file_hash'};
		my $gpgKey = $file{'author_key'};

		my $isTextart = 0;

		my $isSigned;
		if ($gpgKey) {
			$isSigned = 1;
		} else {
			$isSigned = 0;
		}

		my $alias;
		my $isAdmin = 0;

		my $message = GetItemMessage($file{'file_hash'}, $file{'file_path'});

		if ($file{'remove_token'}) {
			WriteLog('$file{\'remove_token\'} = ' . $file{'remove_token'});


			$message =~ s/$file{'remove_token'}//g;
			$message = trim($message);
			#todo there is a bug here, but it is less significant than the majority of cases
			#  the bug is that it removes the token even if it is not by itself on a single line
			#  this could potentially be mis-used to join together two pieces of a forbidden string
			#todo make it so that post does not need to be trimmed, but extra \n\n after the token is removed
		} else {
			WriteLog('$file{\'remove_token\'} is not set');
		}

		if ($file{'tags_list'}) {
			my @itemTags = split(',', $file{'tags_list'});

			while (scalar(@itemTags)) {
				my $thisTag = pop @itemTags;
				if ($thisTag eq 'textart') {
					$isTextart = 1;
				}
			}
		}

		if ($isTextart) {
			$message = TextartForWeb($message);
		} else {
			$message = FormatForWeb($message);
		}

		#$message =~ s/>>([a-f0-9]{40})/GetItemTemplateFromHash($1, '>>')/eg;

		#hint GetHtmlFilename()
		#todo verify that the items exist before turning them into links,
		# so that we don't end up with broken links
		$message =~ s/([a-f0-9]{40})/GetHtmlLink($1)/eg;

		if ($file{'format_avatars'}) {
			$message =~ s/([A-F0-9]{16})/GetHtmlAvatar($1)/eg;
		}

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
		if ($isTextart) {
			$itemClass .= ' item-textart';
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

		my $addedTime = ''; #todo

		if ($file{'item_title'}) {
			my $itemTitleTemplate = GetTemplate('itemtitlelink.template');

			my $itemTitle = HtmlEscape($file{'item_title'});

			$itemTitleTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTitleTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;

			$itemTemplate =~ s/\$itemTitleTemplate/$itemTitleTemplate/g;
		} else {
			$itemTemplate =~ s/\$itemTitleTemplate//g;
		}

		if ($isTextart) {
			$itemText = '<tt><code>' . $message . '</code></tt>';
		}

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$authorLink/$authorLink/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;
		$itemTemplate =~ s/\$addedTime/$addedTime/g;

#		if ($replyCount) {
#			$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
#		} else {
#			$itemTemplate =~ s/\$replyCount//g;
#		}

		my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});
		#todo this call is only needed if show_vote_summary or show_qiuck_vote

		# if show_vote_summary is set, show a count of all the tags the item has
		if ($file{'show_vote_summary'}) {
			#todo templatize this
			#this displays the vote summary (tags applied and counts)
			my $votesSummary = '';

			foreach my $voteTag (keys %voteTotals) {
				$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
			}
			if ($votesSummary) {
				$votesSummary = '<p class=advanced><b class=beginner>Existing Labels:</b><br class=beginner>' . $votesSummary . '</p>';
				#todo templatize
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;

			#
			#end of tag summary display
		} else {
			$itemTemplate =~ s/\$votesSummary//g;
		}

		if ($file{'show_quick_vote'}) {
			my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});

			my @quickVotesList;

			my $quickVotesForTags;

			foreach my $voteTag (keys %voteTotals) {
				$quickVotesForTags = GetConfig('tagset/' . $voteTag);
				if ($quickVotesForTags) {
					push @quickVotesList, split("\n", $quickVotesForTags);
				}
			}

			my %dedupe = map { $_, 1 } @quickVotesList;
			@quickVotesList = keys %dedupe;

			$quickVotesForTags = GetConfig('tagset/' . 'all');
			if ($quickVotesForTags) {
				unshift @quickVotesList, split("\n", $quickVotesForTags);
			}

			if (1) {
				my $styleSheet = GetStylesheet();

				my $quickVoteTemplate = GetTemplate('votequick.template');
				my $tagButtons = '';
				foreach my $quickTagValue (@quickVotesList) {
					my $ballotTime = GetTime();
					if ($fileHash && $ballotTime) {
						my $mySecret = GetConfig('admin/secret');
						my $checksum = md5_hex($fileHash . $ballotTime . $mySecret);

						my $tagButton = GetTemplate('vote2button.template');

						my $quickTagCaption = GetString($quickTagValue);

						$tagButton =~ s/\$fileHash/$fileHash/g;
						$tagButton =~ s/\$ballotTime/$ballotTime/g;
						$tagButton =~ s/\$voteValue/$quickTagValue/g;
						$tagButton =~ s/\$voteCaption/$quickTagCaption/g;
						$tagButton =~ s/\$checksum/$checksum/g;

						# this is a hack, eventually should be replaced by config/tag_color #todo
						if (index($styleSheet, "tag-$quickTagValue") > -1) {
							$tagButton =~ s/\$class/tag-$quickTagValue/g;
						} else {
							$tagButton =~ s/class="\$class"//g;
						}

						$tagButtons .= $tagButton;
					}
				}

				$quickVoteTemplate =~ s/\$quickVoteButtons/$tagButtons/;

				$itemTemplate =~ s/\$quickVoteButtonGroup/$quickVoteTemplate/;
			} else {
				$itemTemplate =~ s/\$quickVoteButtonGroup//;
			}
		} else {
			$itemTemplate =~ s/\$quickVoteButtonGroup//g;
		}

		return $itemTemplate;
	} else {
		return '';
	}
}

sub GetPageFooter {
	my $txtFooter = GetTemplate('htmlend.template');

#	my $disclaimer = GetConfig('string/en/disclaimer') . "\n" . GetConfig('string/ru/disclaimer');
	my $disclaimer = GetConfig('string/en/disclaimer');

	$txtFooter =~ s/\$disclaimer/$disclaimer/g;

	my $timeBuilt = GetTime();

	my $timestamp = strftime('%F %T', localtime($timeBuilt));
	my $myVersion = GetMyVersion();
	#my $gpgVersion = GetGpgMajorVersion();

	my $versionPageUrl = '/' . substr($myVersion, 0, 2) . '/' . substr($myVersion, 2, 2) . '/' . $myVersion . '.html';

	my $myVersionPrettyLink = '<a href="' . $versionPageUrl . '">' . substr($myVersion, 0, 8) . '..' . '</a>';

	my $footer = "<span title=\"This page was created at $timestamp\">$timeBuilt</span> ; <span title=\"Version Number\">$myVersionPrettyLink</span> ; ";

	my $footerMenuTemplate = '';

	#footer menu
	$footerMenuTemplate .= GetMenuItem("/stats.html", 'Stats');
	$footerMenuTemplate .= GetMenuItem("/top/admin.html", 'Admin');
	$footerMenuTemplate .= GetMenuItem("/clone.html", 'Clone');
	$footerMenuTemplate .= GetMenuItem("/index0.html", 'Abyss');
	$footerMenuTemplate .= GetMenuItem("/tags.html", GetString('menu/tags'));
	$footerMenuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));

	$footer .= $footerMenuTemplate;

	$txtFooter =~ s/\$footer/$footer/;

	my $ssiFooter;
	if (GetConfig('admin/ssi/enable')) {
		$ssiFooter = '<p>' . GetTemplate('ssi/print_date.ssi.template') . '</p>';
	} else {
		$ssiFooter = '';
	}
	$txtFooter =~ s/\$ssiFooter/$ssiFooter/;

	return $txtFooter;
}

my $primaryColor;
my $secondaryColor;
my $textColor;

sub GetPageHeader {
	my $title = shift;
	my $titleHtml = shift;
	my $pageType = shift;

	if (!$pageType) {
		$pageType = 'default';
	}

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
	my $styleSheet = GetStylesheet();

#
#	my @availablePatterns = glob('template/pattern/*.template');
#	my $randomNumber = int(rand(@availablePatterns));
#	my $patternName = $availablePatterns[$randomNumber];
#	$patternName =~ s/^template\///;

	#my $patternName = 'pattern/bokeh.template';
	my $patternName = trim(GetConfig('header_pattern'));
	my $introText = trim(GetString('page_intro/' . $pageType));
	if (!$introText) {
		$introText = trim(GetString('page_intro/default'));
	}
	#$patternName = GetConfig('header_pattern');

	my $headerBackgroundPattern = GetTemplate($patternName);
	WriteLog("$headerBackgroundPattern");
	$styleSheet =~ s/\$headerBackgroundPattern/$headerBackgroundPattern/g;
	WriteLog($styleSheet);

	#$styleSheet =~ s/\w\w/ /g;

	my $clock = '';
	if (GetConfig('clock')) {
		$clock = GetTemplate('clock.template');
		my $currentTime = GetTime();
		$clock =~ s/\$currentTime/$currentTime/;
	}

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
	$htmlStart =~ s/\$clock/$clock/g;
#
#	if (GetConfig('funstuff/js_clock')) {
#		my $jsClock = Get
#		$htmlStart =~ s/\$putClockHere/$putClockHere/g;
#
#	}

	$htmlStart =~ s/\$introText/$introText/g;

	my $topMenuTemplate = "";

	#todo replace with config/menu/*

	#header menu
	#
	#my $identityLink = GetMenuItem("/profile.html", GetString('menu/sign_in'));


	my $identityLink = '<span id="signin"></span><span class="myid" id=myid></span> ';

	$topMenuTemplate .= $identityLink;
	$topMenuTemplate .= GetMenuItem("/", GetString('menu/home'), 1);
	$topMenuTemplate .= GetMenuItem("/write.html", GetString('menu/write'));
	$topMenuTemplate .= GetMenuItem("/scores.html", 'Authors');
	$topMenuTemplate .= GetMenuItem("/top.html", 'Texts');
	$topMenuTemplate .= GetMenuItem("/tags.html", 'Tags', 1);
	$topMenuTemplate .= GetMenuItem("/events.html", 'Events');
	$topMenuTemplate .= GetMenuItem("/manual.html", 'Manual', 1);
	$topMenuTemplate .= GetMenuItem("/stats.html", 'Stats', 1);
	$topMenuTemplate .= GetMenuItem("/index0.html", 'Abyss', 1);

	$htmlStart =~ s/\$menuItems/$topMenuTemplate/g;

#	my $adminKey = GetAdminKey();
#	if ($adminKey) {
#		$topMenuTemplate .= GetMenuItem('/author/' . $adminKey . '/', 'Admin');
#	}


	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetVoterTemplate {
	my $fileHash = shift;
	my $ballotTime = shift;

	chomp $fileHash;
	chomp $ballotTime;

	#todo move this to GetConfig()
	if (!-e "config/admin/secret") {
		my $randomHash = GetRandomHash();

		PutConfig("admin/secret", $randomHash);
	}
	my $mySecret = GetConfig("admin/secret");

	state $voteButtonsTemplate;

	if (!defined($voteButtonsTemplate)) {
		my @tagsListList = qw(tags tags2 johari nohari rhetoric emotions flags);
		my @voteValues;

		foreach (@tagsListList) {
			if (scalar(@voteValues)) {
				push @voteValues, '--';
			}
			my $tagsList = GetConfig("list/$_");
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

sub GetTopItemsPage {
	WriteLog("GetTopItemsPage()");

	my $txtIndex = '';

	my $title = 'Top Items';
	my $titleHtml = 'Top Items';

	$txtIndex = GetPageHeader($title, $titleHtml, 'top');

	$txtIndex .= GetTemplate('maincontent.template');

	my $topItems = DBGetTopItems();

	my @topItemsArray = @{$topItems};

	if (scalar(@topItemsArray)) {
		my $itemListingWrapper = GetTemplate('item_listing_wrapper.template');

		my $itemListings = '';

		while (@topItemsArray) {
			my $itemTemplate = GetTemplate('item_listing.template');
			#todo don't need to do this every time

			my $item = shift @topItemsArray;

			my $itemKey = @{$item}[2];
			my $itemTitle = @{$item}[7];
			my $itemScore = @{$item}[8];
			my $authorKey = @{$item}[3];

			if (trim($itemTitle) eq '') {
				$itemTitle = '(' . $itemKey . ')';
			}

			my $itemLink = GetHtmlFilename($itemKey);
			$itemTitle = HtmlEscape($itemTitle);

			my $authorAvatar;
			if ($authorKey) {
#				$authorAvatar = GetPlainAvatar($authorKey);
				$authorAvatar = GetAuthorLink($authorKey, 1);
			} else {
				$authorAvatar = '';
			}

			$itemTemplate =~ s/\$link/$itemLink/g;
			$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTemplate =~ s/\$itemScore/$itemScore/g;
			$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;

			$itemListings .= $itemTemplate;
		}

		$itemListingWrapper =~ s/\$itemListings/$itemListings/;

		$txtIndex .= $itemListingWrapper;
	} else {
		$txtIndex .= "<p class=beginner>Couldn't find any items to put on this page. Recommend that you post something or contact your operator.</p><p>No matches.</p>";
		#todo should be in template/
	}

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs));

	return $txtIndex;
}

sub GetStatsPage {
	my $statsPage;

	$statsPage = GetPageHeader('Stats', 'Stats', 'stats');

	my $statsTable = GetTemplate('stats.template');

	my $itemCount = DBGetItemCount();
	my $authorCount = DBGetAuthorCount();

	my $adminId = GetAdminKey();
	if ($adminId) {
		$statsTable =~ s/\$admin/GetAuthorLink($adminId)/e;
	} else {
		$statsTable =~ s/\$admin/(None)/;
	}

	my $serverId = GetServerKey();
	if ($serverId) {
		$statsTable =~ s/\$server/GetAuthorLink($serverId)/e;
	} else {
		$statsTable =~ s/\$server/(None)/;
	}


	my $currUpdateTime = GetTime();
	my $prevUpdateTime = GetConfig('last_update_time');
	if (!defined($prevUpdateTime) || !$prevUpdateTime) {
		$prevUpdateTime = GetTime();
	}

	my $updateInterval = $currUpdateTime - $prevUpdateTime;

	PutConfig("last_update_time", $currUpdateTime);

#	my $nextUpdateTime = ($currUpdateTime + $updateInterval) . ' (' . EpochToHuman($currUpdateTime + $updateInterval) . ')';
#	$prevUpdateTime = $prevUpdateTime . ' (' . EpochToHuman($prevUpdateTime) . ')';
#	$currUpdateTime = $currUpdateTime . ' (' . EpochToHuman($currUpdateTime) . ')';

	my $nextUpdateTime = ($currUpdateTime + $updateInterval);

	$statsTable =~ s/\$prevUpdateTime/GetTimestampElement($prevUpdateTime)/e;
	$statsTable =~ s/\$currUpdateTime/GetTimestampElement($currUpdateTime)/e;
	$statsTable =~ s/\$updateInterval/$updateInterval/;
	$statsTable =~ s/\$nextUpdateTime/GetTimestampElement($nextUpdateTime)/e;

	$statsTable =~ s/\$version/GetMyVersion()/e;
	$statsTable =~ s/\$itemCount/$itemCount/e;
	$statsTable =~ s/\$authorCount/$authorCount/e;

	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	$statsPage = InjectJs($statsPage, qw(avatar fresh prefs timestamps));

	return $statsPage;
}

sub InjectJs { # inject js template(s) before </body> ; $html, @scriptNames
	my $html = shift;
	my @scriptNames = @_;

	my $scriptsText = '';
	my $scriptsComma = '';

	if (GetConfig('clock')) {
		push @scriptNames, 'clock';
	}

	foreach my $script (@scriptNames) {
		if (!$scriptsComma) {
			$scriptsComma = "\n\n";
		} else {
			$scriptsText .= $scriptsComma;
		}

		$scriptsText .= GetTemplate("js/$script.js.template");
	}

	my $scriptInject = GetTemplate('scriptinject.template');
	$scriptInject =~ s/\$javascript/$scriptsText/g;

	$html =~ s/<\/body>/$scriptInject<\/body>/;

	return $html;
}

sub GetScoreboardPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Top Scores';
	my $titleHtml = 'Top Scores';

	my $currentTime = GetTime();

	$txtIndex = GetPageHeader($title, $titleHtml, 'scoreboard');

	$txtIndex .= GetTemplate('maincontent.template');

	my $topAuthors = DBGetTopAuthors();

	my @topAuthorsArray = @{$topAuthors};

	my $authorListingWrapper = GetTemplate('author_listing_wrapper.template');

	my $authorListings = '';

	while (@topAuthorsArray) {
		my $authorItemTemplate = GetTemplate('author_listing.template');
		#todo don't need to do this every time

		my $author = shift @topAuthorsArray;

		my $authorKey = @{$author}[0];
		my $authorAlias = @{$author}[1];
		my $authorScore = @{$author}[2];
		my $authorWeight = @{$author}[3] || 1;
		my $authorLastSeen = @{$author}[4];
		my $authorItemCount = @{$author}[5];
		my $authorAvatar = GetHtmlAvatar($authorKey);

		my $authorLink = "/author/" . $authorKey . ".html";

#		$authorLastSeen = GetSecondsHtml(GetTime() - $authorLastSeen) . ' ago';

		$authorItemTemplate =~ s/\$link/$authorLink/g;
		$authorItemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
		$authorItemTemplate =~ s/\$authorScore/$authorScore/g;
		$authorItemTemplate =~ s/\$authorWeight/$authorWeight/g;
		$authorItemTemplate =~ s/\$authorLastSeen/$authorLastSeen/g;
		$authorItemTemplate =~ s/\$authorItemCount/$authorItemCount/g;
		$authorItemTemplate =~ s/\$authorKey/$authorKey/g;

		$authorListings .= $authorItemTemplate;
	}

	$authorListingWrapper =~ s/\$authorListings/$authorListings/;

	$txtIndex .= $authorListingWrapper;


	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs timestamps));

	return $txtIndex;
}

sub GetReadPage { # generates page with item listing based on parameters
	# GetReadPage
	#   $pageType
	#		author
	#		tag
	#	$parameter
	#		for author = author's key hash
	#		for tag = tag name/value

	my $title; # plain-text title for <title>
	my $titleHtml; # title which can have html formatting

	my $pageType = shift; # page type parameter
	my $pageParam; # parameter for page type, optionally looked up later

	my @files; # will contain array of hash-refs, one for each file

	my $authorKey; # stores author's key, if page type is author
	# #todo figure out why this is needed here

	if (defined($pageType)) {
		if ($pageType eq 'author') {
			$pageParam = shift;
			$authorKey = $pageParam;

			if (!IsFingerprint($authorKey)) {
				WriteLog('GetReadPage(author) called with invalid parameter');
				return;
			}

			my $whereClause = "WHERE author_key = '$authorKey'";

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

	my $htmlStart = GetPageHeader($title, $titleHtml, 'read_' . $pageType);

	$txtIndex .= $htmlStart;

	#<span class="replies">last reply at [unixtime]</span>
	#javascript foreach span class=replies { get time after "last reply at" and compare to "last visited" cookie

	$txtIndex .= GetTemplate('maincontent.template');

	if ($pageType eq 'author') {
		my $authorInfoTemplate = GetTemplate('authorinfo.template');

		my $authorAliasHtml = GetAlias($authorKey);
		my $authorAvatarHtml = GetAvatar($authorKey);
		my $authorImportance = 1;
		my $authorScore = DBGetAuthorScore($authorKey);
		my $itemCount = DBGetAuthorItemCount($authorKey);
		my $authorDescription = '';
		my $authorWeight = DBGetAuthorWeight($authorKey);
		my $authorLastSeen = DBGetAuthorLastSeen($authorKey);

		my $publicKeyHash = DBGetAuthorPublicKeyHash($authorKey);
		my $publicKeyHashHtml = '';
		my $authorPubkeyTxtLink = '';
		if (defined($publicKeyHash) && IsSha1($publicKeyHash)) {
			$publicKeyHashHtml = GetHtmlLink($publicKeyHash);
			$authorPubkeyTxtLink = '<span class=advanced>.txt</span>';
			#todo my $publicKeyTxtLink = ..;
		}

		if (IsServer($authorKey)) {
			if ($authorDescription) {
				$authorDescription .= '<br>';
			}
			$authorDescription .= '<b>Server signing key.</b>';
		}

		if (IsAdmin($authorKey)) {
			if ($authorDescription) {
				$authorDescription .= '<br>';
			}
			$authorDescription .= '<b>Admin. Do not taunt.</b>';
		}

		if ($authorDescription) {
			$authorDescription .= '<br>';
		}
		$authorDescription .= GetItemVotesSummary($publicKeyHash);

		my $profileVoteButtons = GetItemVoteButtons($publicKeyHash);

		$authorInfoTemplate =~ s/\$avatar/$authorAvatarHtml/;
		$authorInfoTemplate =~ s/\$authorName/$authorAliasHtml/;
		$authorInfoTemplate =~ s/\$fingerprint/$authorKey/;
		$authorInfoTemplate =~ s/\$importance/$authorImportance/;
		$authorInfoTemplate =~ s/\$authorScore/$authorScore/;
		$authorInfoTemplate =~ s/\$itemCount/$itemCount/;
		$authorInfoTemplate =~ s/\$authorWeight/$authorWeight/;
		$authorInfoTemplate =~ s/\$authorDescription/$authorDescription/;
		$authorInfoTemplate =~ s/\$authorLastSeen/$authorLastSeen/g;
		$authorInfoTemplate =~ s/\$profileVoteButtons/$profileVoteButtons/g;
		if ($publicKeyHash) {
			$authorInfoTemplate =~ s/\$publicKeyHash/$publicKeyHashHtml/g;
			$authorInfoTemplate =~ s/\$authorPubkeyTxtLink/$authorPubkeyTxtLink/g;
		} else {
			$authorInfoTemplate =~ s/\$publicKeyHash//g;
			$authorInfoTemplate =~ s/\$authorPubkeyTxtLink//g;
		}


		##### friends list begin #####

		# get list of friends from db
		my @authorFriendsArray = DBGetAuthorFriends($authorKey);

		# generated html will reside here
		my $authorFriends = '';

		while (@authorFriendsArray) {
			# get the friend's key
			my $authorFriend = shift @authorFriendsArray;
			my $authorFriendKey = %{$authorFriend}{'author_key'};

			# get avatar (with link) for key
			my $authorFriendAvatar .= GetAuthorLink($authorFriendKey);

			# get friend list item template and insert linked avatar to it
			my $authorFriendTemplate = GetTemplate('author/author_friends_item.template');
			$authorFriendTemplate =~ s/\$authorFriendAvatar/$authorFriendAvatar/g;

			# append it to list of friends html
			$authorFriends .= $authorFriendTemplate
		}

		# wrap list of friends in wrapper
		my $authorFriendsWrapper = GetTemplate('author/author_friends.template');
		$authorFriendsWrapper =~ s/\$authorFriendsList/$authorFriends/;

		# insert list of friends into authorinfo template
		$authorInfoTemplate =~ s/\$authorFriends/$authorFriendsWrapper/;

		# add authorinfo template to page
		$txtIndex .= $authorInfoTemplate;
	}

	my $itemComma = '';

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		WriteLog("DBAddItemPage (1)");
		DBAddItemPage($row->{'file_hash'}, $pageType, $pageParam);

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
#				$row->{'show_quick_vote'} = 1;
				$itemTemplate = GetItemTemplate($row);
			} else {
				$itemTemplate = '<p>Problem decoding message</p>';
				WriteLog('Something happened and there is no $message where I expected it... Oh well, moving on.');
			}

			if ($itemComma eq '') {
				$itemComma = '<hr size=7>';
			} else {
				$itemTemplate = $itemComma . $itemTemplate;
			}

			$txtIndex .= $itemTemplate;
		}
	}

	#	$txtIndex .= GetTemplate('voteframe.template');

	# Add javascript warning to the bottom of the page
	$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	if ($pageType eq 'author') {
		$txtIndex = InjectJs($txtIndex, qw(avatar.authorpage prefs));
	} else {
		$txtIndex = InjectJs($txtIndex, qw(avatar prefs));
	}

	return $txtIndex;
}

sub GetMenuItem {
	my $address = shift;
	my $caption = shift;
	my $advanced = shift;
#
#	if (!-e "html/$address") { #don't make a menu item if file doesn't exist
#		return '';
#	}

	my $menuItem = '';
	if ($advanced) {
		$menuItem = GetTemplate('menuitem-advanced.template');
	} else {
		$menuItem = GetTemplate('menuitem.template');
	}

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

	my $itemComma = '';

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

			$row->{'show_quick_vote'} = 1;
			$row->{'vote_buttons'} = 1;
			$row->{'show_vote_summary'} = 1;

			my $itemTemplate;
			$itemTemplate = GetItemTemplate($row);

			$itemList = $itemList . $itemComma . $itemTemplate;

			if ($itemComma eq '') {
				$itemComma = '<hr size=8>';
			}
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

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs));

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
			my $percent = (($i+1) / $lastPage) * 100;
			WriteMessage("*** WriteIndexPages: " . ($i+1) . "/$lastPage ($percent %) ");

			my %queryParams;
			my $offset = $i * $pageLimit;

			#$queryParams{'where_clause'} = "WHERE item_type = 'text' AND IFNULL(parent_count, 0) = 0";

			if ($overlapPage && $lastPage > $overlapPage && $i > $overlapPage) {
				$offset = $offset - ($itemCount % $pageLimit);
			}
			$queryParams{'limit_clause'} = "LIMIT $pageLimit OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';

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
		my $indexPage = GetPageHeader(GetConfig('home_title'), GetConfig('home_title'), 'home_empty');

		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';

		$indexPage .= GetPageFooter();

		PutHtmlFile('html/index.html', $indexPage);
	}
}

sub MakeStaticPages {
	WriteLog('MakeStaticPages() BEGIN');

	# Submit page
	my $submitPage = GetWritePage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);

	# Add Event page
	my $eventAddPage = GetEventAddPage();
	PutHtmlFile("$HTMLDIR/event.html", $eventAddPage);


	# Stats page
	my $statsPage = GetStatsPage();
	PutHtmlFile("$HTMLDIR/stats.html", $statsPage);


	# Profile Management page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/profile.html", $identityPage);


	# Target page for the submit page
	my $graciasPage = GetPageHeader("Thank You", "Thank You", 'gracias');
	$graciasPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	$graciasPage .= GetTemplate('maincontent.template');

	my $graciasTemplate = GetTemplate('page/gracias.template');

	$graciasPage .= $graciasTemplate;

	$graciasPage .= GetPageFooter();

	$graciasPage = InjectJs($graciasPage, qw(avatar gracias prefs));

	$graciasPage =~ s/<body /<body onload="makeRefLink();" /;

	PutHtmlFile("$HTMLDIR/gracias.html", $graciasPage);


	# Ok page
	my $okPage = GetTemplate('actionvote.template');

	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	#$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote2.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/event.html", $okPage);


	# Manual page
	my $tfmPage = GetPageHeader("Manual", "Manual", 'manual');

	$tfmPage .= GetTemplate('maincontent.template');

	my $tfmPageTemplate = GetTemplate('page/manual.template');

	$tfmPage .= $tfmPageTemplate;

	$tfmPage .= '<p>' . GetTemplate('netnow3.template') . '</p>';

	$tfmPage .= GetPageFooter();

	$tfmPage = InjectJs($tfmPage, qw(avatar prefs));

	PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('js/zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('js/lib/openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('js/lib/openpgp.worker.js.template'));

	# Write form javasript
	my $cryptoJsTemplate = GetTemplate('js/crypto.js.template');
	my $prefillUsername = GetConfig('prefill_username') || '';
	$cryptoJsTemplate =~ s/\$prefillUsername/$prefillUsername/g;

	PutHtmlFile("$HTMLDIR/crypto.js", $cryptoJsTemplate);

	# Write avatar javasript
	PutHtmlFile("$HTMLDIR/avatar.js", GetTemplate('js/avatar.js.template'));

	# Write prefs javasript
	PutHtmlFile("$HTMLDIR/prefs.js", GetTemplate('js/prefs.js.template'));
	PutHtmlFile("$HTMLDIR/prefstest.html", GetTemplate('js/prefstest.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');
	if (GetConfig('admin/php/enable')) {
		$HtaccessTemplate .= "\n".GetTemplate('php/htaccess.for.php.template')."\n";

		PutFile("$HTMLDIR/spasibo.php", GetTemplate('php/spasibo.php.template'));

		my $spasibo2Template = GetTemplate('php/spasibo2.php.template');
		my $myPath = `pwd`;
		chomp $myPath;
		$spasibo2Template =~ s/\$myPath/$myPath/g;
		PutFile("$HTMLDIR/spasibo2.php", $spasibo2Template);
	}
	PutHtmlFile("$HTMLDIR/.htaccess", $HtaccessTemplate);

	PutHtmlFile("$HTMLDIR/favicon.ico", '');

	WriteLog('MakeStaticPages() END');
}

sub GetWritePage {
	# $txtIndex stores html page output
	my $txtIndex = "";

	my $title = "Write";
	my $titleHtml = "Write";

	my $itemCount = DBGetItemCount();
	my $itemLimit = GetConfig('item_limit');
	if (!$itemLimit) {
		$itemLimit = 9000;
	}

	$txtIndex = GetPageHeader($title, $titleHtml, 'write');

	$txtIndex .= GetTemplate('maincontent.template');

	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
		if ($itemCount < $itemLimit) {
			my $submitForm = GetTemplate('form/write2.template');
			#my $submitForm = GetTemplate('form/write.template');

			if (GetConfig('admin/php/enable')) {
				$submitForm =~ s/\<textarea/<textarea onkeyup="if (this.length > 2) { document.forms['compose'].action='\/gracias2.php'; }" /;
			}

			my $prefillText = "";

			$submitForm =~ s/\$extraFields//g;
			$submitForm =~ s/\$prefillText/$prefillText/g;

			$txtIndex .= $submitForm;

			#$txtIndex .= "Current Post Count: $itemCount; Current Post Limit: $itemLimit";
		} else {
			$txtIndex .= "Item limit ($itemLimit) has been reached (or exceeded). Please remove something before posting.";
		}

		$txtIndex .= GetPageFooter();

		$txtIndex = InjectJs($txtIndex, qw(avatar writeonload prefs));

		#todo break out into IncludeJs();
		#		my $scriptsInclude = '<script type="text/javascript" src="/zalgo.js"></script><script type="text/javascript" src="/openpgp.js"></script><script type="text/javascript" src="/crypto.js"></script>';
		#		$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

		$txtIndex =~ s/<body /<body onload="writeOnload();" /;
	} else {
		my $submitForm = GetTemplate('form/write2.template');
		#my $submitForm = GetTemplate('form/write.template');
		my $prefillText = "";

		$submitForm =~ s/\$extraFields//g;
		$submitForm =~ s/\$prefillText/$prefillText/g;

		$txtIndex .= $submitForm;
		$txtIndex .= "Something went wrong. Could not get item count.";
	}

	return $txtIndex;
}


sub GetEventAddPage { # get html for /event.html
	# $txtIndex stores html page output
	my $txtIndex = "";

	my $title = "Add Event";
	my $titleHtml = "Add Event";

	$txtIndex = GetPageHeader($title, $titleHtml, 'event_add');

	$txtIndex .= GetTemplate('maincontent.template');

	my $eventAddForm = GetTemplate('form/event_add.template');

#	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
#		localtime(time);
#
#	my $amPm = 0;
#	if ($hour > 12) {
#		$hour -= 12;
#		$amPm = 1;
#	}
#
	$txtIndex .= $eventAddForm;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar writeonload prefs event_add));

#	$txtIndex =~ s/<body /<body onload="writeOnload();" /;

	return $txtIndex;
}

sub GetIdentityPage {
	my $txtIndex = "";

	my $title = "Profile";
	my $titleHtml = "Profile";

	$txtIndex = GetPageHeader($title, $titleHtml, 'identity');

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('form/identity.template');

	my $idCreateForm = GetTemplate('form/id_create.template');
	my $prefillUsername = GetConfig('prefill_username');
	my $termsOfService = FormatForWeb(GetConfig('string/en/tos'));

	$idCreateForm =~ s/\$prefillUsername/$prefillUsername/g;
	$idCreateForm =~ s/\$termsOfService/$termsOfService/g;
	$idPage =~ s/\$formIdCreate/$idCreateForm/g;

	my $idCurrentForm = GetTemplate('form/id_current.template');
	$idPage =~ s/\$formIdCurrent/$idCurrentForm/g;

	my $idAdminForm = GetTemplate('form/id_admin.template');
	$idPage =~ s/\$formIdAdmin/$idAdminForm/g;

	if (GetConfig('admin/gpg/use_gpg2')) {
		my $gpg2Choices = GetTemplate('gpg2.choices.template');
		$idPage =~ s/\$gpg2Algochoices/$gpg2Choices/;
	} else {
		$idPage =~ s/\$gpg2Algochoices//;
	}

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs));

	my $scriptsInclude = '<script src="/zalgo.js"></script><script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="identityOnload();" /;

	return $txtIndex;
}

1;
