use strict;
use warnings;

use utf8;
use 5.010;

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime);
use Data::Dumper;
use File::Copy;
use Cwd qw(cwd);

#use List::Uniq ':all';

#use Acme::RandomEmoji qw(random_emoji);

require './utils.pl';
require './sqlite.pl';

my $HTMLDIR = "html";

sub GenerateDialogPage { # generates page with dialog
	# #todo:
	# home
	# write
	# about
	# queue
	# index
	# tags list
	# items for tag
	# more complicated query

	my $pageName = shift; # page name: 404
	my $pageTitle = shift; # page title (
	my $windowContents = shift;

	#todo is $pageName in list of allowed pages?

	if ($pageName) {
		if ($pageName eq '404') {
			$pageTitle = '404 Message Received';

			$windowContents  = '';
			$windowContents .= '<tr><td class=body>';
			$windowContents .= GetTemplate('404.template');
			$windowContents .= '</td></tr>';

			my $pageTemplate;
			$pageTemplate = '';

			$pageTemplate .= GetPageHeader($pageTitle, $pageTitle, 'default'); #GetTemplate('htmlstart.template');

			$pageTemplate .= GetWindowTemplate($pageTitle, '', '', $windowContents, 'Ready');
			#: $windowTitle, $windowMenubar, $columnHeadings, $windowBody, $windowStatus

			$pageTemplate .= GetPageFooter();

			$pageTemplate = InjectJs($pageTemplate, qw(profile));

			return $pageTemplate;
		}
		if ($pageName eq 'ok') {
		}
	}
}

sub GetStylesheet { # returns style template based on config
	my $style = GetTemplate('css/default.css.template');
	# baseline style

	if (GetConfig('html/color_avatars')) {
		$style .= "\n" . GetTemplate('style.avatar.template');
		# add style for color avatars if that's the setting
	}

	if (GetThemeAttribute('additional.css')) {
		$style .= "\n" . GetThemeAttribute('additional.css');
	}

	return $style;
}

sub GetAuthorLink { # returns avatar'ed link for an author id
	my $gpgKey = shift; # author's fingerprint
	my $showPlain = shift; # 1 to display avatar without colors

	# sanitize $showPlain
	if (!$showPlain) {
		$showPlain = 0;
	} else {
		$showPlain = 1;
	}

	# verify $gpgKey is valid 
	if (!IsFingerprint($gpgKey)) {
		WriteLog("WARNING: GetAuthorLink() called with invalid parameter!");
		return;
	}

	my $authorUrl = "/author/$gpgKey/";

	my $authorAvatar = '';
	if ($showPlain) {
		$authorAvatar = GetAvatar($gpgKey);
	} else {
		$authorAvatar = GetAvatar($gpgKey);
	}

	my $authorLink = GetTemplate('authorlink.template');

	$authorAvatar = trim($authorAvatar);

	$authorLink =~ s/\$authorUrl/$authorUrl/g;
	$authorLink =~ s/\$authorAvatar/$authorAvatar/g;

	return $authorLink;
}

sub GetPageLink { # returns one pagination link as html, used by GetPageLinks
	my $pageNumber = shift;
	my $itemCount = shift;

	my $pageLimit = GetConfig('page_limit');

	my $pageStart = $pageNumber * $pageLimit + 1;
	my $pageEnd = $pageNumber * $pageLimit + $pageLimit;
	if ($pageEnd > $itemCount) {
		$pageEnd = $itemCount;
	}
	my $pageCaption = $pageStart . '-' . $pageEnd;

	state $pageLinkTemplate;
	if (!defined($pageLinkTemplate)) {
		$pageLinkTemplate = GetTemplate('pagelink.template');
	}

	my $pageLink = $pageLinkTemplate;
	$pageLink =~ s/\$pageName/$pageCaption/;

	$pageLink =~ s/\$pageNumber/$pageNumber/;

	return $pageLink;
}

sub GetWindowTemplate { #: $windowTitle, $windowMenubarContent, $columnHeadings, $windowBody, $windowStatus
# returns template for html-table-based-"window"
	my $windowTitle = shift;
	my $windowMenubarContent = shift;
	my $columnHeadings = shift;
	my $windowBody = shift;
	my $windowStatus = shift;

	my $contentColumnCount = 0;

	my $windowTemplate = GetTemplate('window/standard.template');

	if ($windowTitle) {
		my $windowTitlebar = GetTemplate('window/titlebar.template');
		$windowTitlebar =~ s/\$windowTitle/$windowTitle/g;
		$windowTitlebar = $windowTitlebar;

		$windowTemplate =~ s/\$windowTitlebar/$windowTitlebar/g;
	} else {
		$windowTemplate =~ s/\$windowTitlebar//g;
	}

	if ($windowMenubarContent) {
		my $windowMenubar = GetTemplate('window/menubar.template');
		$windowMenubar =~ s/\$windowMenubarContent/$windowMenubarContent/;

		$windowTemplate =~ s/\$windowMenubar/$windowMenubar/g;
	} else {
		$windowTemplate =~ s/\$windowMenubar//g;
		#todo currently results in an empty menubar
	}

	if ($columnHeadings) {
		my $windowHeaderTemplate = GetTemplate('window/header_wrapper.template');
		my $windowHeaderColumns = '';
		my @columnsArray = split(',', $columnHeadings);

		my $printedColumnsCount = 0;
		foreach my $columnCaption (@columnsArray) {
			$printedColumnsCount++;
			my $columnHeaderTemplate = GetTemplate('window/header_column.template');
			if ($printedColumnsCount >= scalar(@columnsArray)) {
				$columnCaption .= '<br>'; # for no-table browsers
			}
			$columnHeaderTemplate =~ s/\$headerCaption/$columnCaption/;
			$windowHeaderColumns .= $columnHeaderTemplate;
		}
		$windowHeaderTemplate =~ s/\$windowHeadings/$windowHeaderColumns/;
		$windowTemplate =~ s/\$windowHeader/$windowHeaderTemplate/;
		$contentColumnCount = scalar(@columnsArray);
	} else {
		$windowTemplate =~ s/\$windowHeader//g;
		$contentColumnCount = 0;
	}

	if ($windowBody) {
		# todo there should be some flag to wrap <tr class=content><td> around this, otherwise there's html in the perl
		$windowTemplate =~ s/\$windowBody/$windowBody/g;
	} else {
		$windowTemplate =~ s/\$windowBody//g;
	}

	if ($windowBody) {
		$windowTemplate =~ s/\$windowStatus/$windowStatus/g;
	} else {
		$windowTemplate =~ s/\$windowStatus//g;
	}

	if ($contentColumnCount) {
		$windowTemplate =~ s/\$contentColumnCount/$contentColumnCount/g;
	} else {
		$windowTemplate =~ s/\ colspan=\$contentColumnCount//g;
	}

	return $windowTemplate;
}

sub GetPageLinks { # returns html for pagination links
# $currentPageNumber = current page

	my $currentPageNumber = shift; #

	state $pageLinks; # stores generated links html in case we need them again

	my $pageLimit = GetConfig('page_limit'); # number of items per page

	my $itemCount = DBGetItemCount(); # item count

	WriteLog("GetPageLinks($currentPageNumber)");

	# check if we've generated the html already, if so, use it
	if (defined($pageLinks)) {
		WriteLog("GetPageLinks: \$pageLinks already exists, doing search and replace");

		my $currentPageTemplate = GetPageLink($currentPageNumber, $itemCount);
		
		my $currentPageStart = $currentPageNumber * $pageLimit;
		my $currentPageEnd = $currentPageNumber * $pageLimit + $pageLimit;
		if ($currentPageEnd > $itemCount) {
			$currentPageEnd = $itemCount;
		}
		my $currentPageCaption = $currentPageStart . '-' . $currentPageEnd;

		my $pageLinksReturn = $pageLinks; # make a copy of $pageLinks which we'll modify

		$pageLinksReturn =~ s/$currentPageTemplate/<b>$currentPageCaption<\/b> /g;
		# replace current page link with highlighted one

		return $pageLinksReturn;
	} else {

		# we've ended up here because we haven't generated $pageLinks yet

		WriteLog("GetPageLinks: \$itemCount = $itemCount");

		$pageLinks = "";

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
				$pageLinkTemplate = GetPageLink($i, $itemCount);
				#			}

				$pageLinks .= $pageLinkTemplate;
			}
		}

		my $frame = GetTemplate('pagination.template');

		$frame =~ s/\$paginationLinks/$pageLinks/;

		$pageLinks = $frame;

		# up to this point, we are building the in-memory template for the pagination links
		# once it is stored in $pageLinks, which is a static ("state") variable,
		# GetPageLinks() returns at the top, and does not reach here.
		return GetPageLinks($currentPageNumber);
	}
}

sub GetEventsPage { # returns html for events page
	WriteLog('GetEventsPage()');

	my $txtPage = '';

	my $title = 'Upcoming Events';
	my $titleHtml = 'Upcoming Events';

	$txtPage = GetPageHeader($title, $titleHtml, 'events');

	$txtPage .= GetTemplate('maincontent.template');

	my @eventsArray = DBGetEvents();

	my $eventsItemsList = '';

	my $rowBgColor = '';
	my $colorRow0Bg = GetThemeColor('row_0');
	my $colorRow1Bg = GetThemeColor('row_1');

	while (@eventsArray) {
		my $event = shift @eventsArray;

		#alternating row colors hack
		if ($rowBgColor eq $colorRow0Bg) {
			$rowBgColor = $colorRow1Bg;
		} else {
			$rowBgColor = $colorRow0Bg;
		}

		my $eventItemHash = $event->{'file_hash'};
		my $eventTitle =  $event->{'event_title'};
		my $eventTime = $event->{'event_time'};
		my $eventDuration = $event->{'event_duration'};
		my $eventItemLink = GetHtmlLink($eventItemHash);
		my $eventItemAuthor = $event->{'author_key'};

		if (!$eventTitle) {
			$eventTitle = 'Untitled';
		}

		if ($eventTitle) {
			$eventTitle = HtmlEscape($eventTitle);
			$eventTitle = '<a href="' . GetHtmlFilename($eventItemHash) . '">' . $eventTitle . '</a>'; #todo templatify
		}

		if (!$eventItemAuthor) {
			$eventItemAuthor = '';
		} else {
			$eventItemAuthor = 'Author: ' . $eventItemAuthor . '<br>'; #todo templatify
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

		my $eventItem = GetTemplate('event/event_item2.template');

		$eventTime = GetTimestampElement($eventTime);
		$eventTimeUntil = GetTimestampElement($eventTimeUntil);

		$eventItem =~ s/\$eventTitle/$eventTitle/;
		$eventItem =~ s/\$eventTime/$eventTime/;
		$eventItem =~ s/\$eventTimeUntil/$eventTimeUntil/;
		$eventItem =~ s/\$eventDuration/$eventDuration/;
		$eventItem =~ s/\$eventItemLink/$eventItemLink/;
		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
		$eventItem =~ s/\$voteButtons/$eventVoteButtons/;
		$eventItem =~ s/\$rowBgColor/$rowBgColor/;

		$eventsItemsList .= $eventItem;
	}

	my $eventsList = GetTemplate('event/event_list2.template');

	$eventsList =~ s/\$eventsList/$eventsItemsList/;

	$txtPage .= $eventsList;

	$txtPage .= GetPageFooter();

	$txtPage = InjectJs($txtPage, qw(avatar fresh prefs timestamps voting profile));

	return $txtPage;

}

sub GetTagsPage { # returns html for tags listing page (sorted by number of uses)
# $title = title of page
# $titleHtml = title of page, html-formatted
# $orderBy = order by clause passed to DBGetVoteCounts()

	my $txtIndex = "";

	my $title = shift || 'Tags';
	chomp $title;

	my $titleHtml = shift || 'Tags';
	chomp $titleHtml;

	my $orderBy = shift || '';
	chomp $orderBy;

	$txtIndex = GetPageHeader($title, $titleHtml, 'tags');

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts;
	$voteCounts = DBGetVoteCounts($orderBy);

	my @voteCountsArray = @{$voteCounts};

	my $voteItemsWrapper = GetTemplate('tag_listing_wrapper.template');

	my $voteItems = '';

	while (@voteCountsArray) {
		my $voteItemTemplate = GetTemplate('tag_listing.template');
		#todo don't need to do this every time

		my $tag = shift @voteCountsArray;

		my $tagName = @{$tag}[0]; #todo assoc-array
		my $tagCount = @{$tag}[1];

		my $tagInfo = '';
		if ($tagInfo = GetConfig('string/en/tag_info/'.$tagName)) {
			#great
		} else {
			$tagInfo = '*';
		}

		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName/g;
		$voteItemTemplate =~ s/\$tagCount/$tagCount/g;
		$voteItemTemplate =~ s/\$tagInfo/$tagInfo/g;

		$voteItems .= $voteItemTemplate;
	}

	$voteItemsWrapper =~ s/\$tagListings/$voteItems/g;

	$txtIndex .= $voteItemsWrapper;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs profile));

	return $txtIndex;
}

sub GetItemPage {	# returns html for individual item page. %file as parameter
	# %file {
	#		file_hash = git's file hash
	#		file_path = path where text file is stored
	#		item_title = title, if any
	#		author_key = author's fingerprint
	#		vote_buttons = 1 to display vote buttons
	#		display_full_hash = 1 to display full hash for permalink (otherwise shortened)
	#		show_vote_summary = 1 to display all votes recieved separately from vote buttons
	#		show_quick_vote = 1 to display quick vote buttons
	#		vote_buttons = 1 to display vote buttons (checkboxes)
	#		format_avatars = 1 to format fingerprint-looking strings into avatars
	#		child_count = number of child items for this item
	#		template_name = name of template to use (item.template is default)
	#		remove_token = reply token to remove from message (used for displaying replies)
	#	}

	# we're expecting a reference to a hash as the first parameter
	# todo sanity checks here, it will probably break if anything else is supplied
	my %file = %{shift @_};
	
	# create $fileHash and $filePath variables, since we'll be using them a lot
	my $fileHash = $file{'file_hash'};
	my $filePath = $file{'file_path'};

	WriteLog("GetItemPage(" . $file{'file_path'} . ")");

	# initialize variable which will contain page html
	my $txtIndex = "";

	my $title = ''; # title for <title>
	my $titleHtml = ''; # title for <h1>

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

	if (!$file{'item_title'}) {
		$file{'item_title'} = 'Untitled';
	}

	my $itemTemplate = GetItemTemplate(\%file);

	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	# if this item has a child_count, we want to print all the child items below
	if ($file{'child_count'}) {
		# get item's children (replies) and store in @itemReplies
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		#debug message
		WriteLog('@itemReplies = ' . @itemReplies);

		# this will contain the replies as html output
		my $allReplies = '';

		# start with a horizontal rule to separate from above content
		$allReplies = '<hr size=3>' . $allReplies;

		# this will store separator between items.
		# first item doesn't need separator above it
		my $replyComma = '';

		foreach my $replyItem (@itemReplies) {
			# output info about item to debug
			WriteLog('$replyItem: ' . $replyItem);
			foreach my $replyVar ($replyItem) {
				WriteLog($replyVar);
			}

			# use item-small template to display the reply items
			$$replyItem{'template_name'} = 'item/item-small.template';
			
			# if the child item contains a reply token for our parent item
			# we want to remove it, to reduce redundant information on the page
			# to do this, we pass the remove_token parameter to GetItemTemplate below
			$$replyItem{'remove_token'} = '>>' . $file{'file_hash'};
			
			# Get the reply template			
			my $replyTemplate = GetItemTemplate($replyItem);
			
			# output it to debug
			WriteLog('$replyTemplate');
			WriteLog($replyTemplate);

			# if the reply item has children also, output the children
			# threads are currently limited to 2 steps
			# eventually, recurdsion can be used to output more levels
			if ($$replyItem{'child_count'}) {
				my $subRepliesTemplate = ''; # will store the sub-replies html output
													  
				my $subReplyComma = ''; # separator for sub-replies

				my @subReplies = DBGetItemReplies($$replyItem{'file_hash'});
				foreach my $subReplyItem (@subReplies) {
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
#					$replyComma = '<p>';
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

		$replyForm = GetTemplate('form/reply3.template');
#		$replyFooter = "&gt;&gt;" . $file{'file_hash'} . "\n\n";
		$replyFooter = '';
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

		if (GetConfig('admin/php/enable')) {
#			my $postHtml = 'post.html';
#			$replyForm =~ s/$postHtml/post.php/;
		}

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

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs fresh voting profile write_buttons timestamps));

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
} # GetItemPage()

sub GetHtmlLink { 
#todo this doesn't work with orgnaize off
	my $hash = shift;

	if ($hash) {
		#todo templatize this
		return '<a href="/' . GetHtmlFilename($hash) . '">' . substr($hash, 0, 8) . '..</a>';
	} else {
	}
}

sub GetItemVoteButtons { # get vote buttons for item in html form
	my $fileHash = shift; # item's file hash
	my $tagSet = shift;   # (optional) use a particular tagset instead of item's default

	WriteLog('GetItemVoteButtons(' . ($fileHash?$fileHash:'-') . ', ' . ($tagSet?$tagSet:'-') . ')');

	#todo sanity checks

	my @quickVotesList; # this will hold all the tag buttons we want to display

	my %voteTotals = DBGetItemVoteTotals($fileHash);

	WriteLog('GetItemVoteButtons(' . scalar(%voteTotals) . ')');
	
	if ($tagSet) {
		# if $tagSet is specified, just use that list of tags
		my $quickVotesForTagSet = GetConfig('tagset/' . $tagSet);
		if ($quickVotesForTagSet) {
			push @quickVotesList, split("\n", $quickVotesForTagSet);
		}
	} else {
		# otherwise it must be calculated
		my $quickVotesForTags;



		foreach my $voteTag (keys %voteTotals) {
			$quickVotesForTags = GetConfig('tagset/' . $voteTag);
			if ($quickVotesForTags) {
				push @quickVotesList, split("\n", $quickVotesForTags);
			}
		}

		# all items will have a 'flag' button
		push @quickVotesList, 'flag';

		my %dedupe = map { $_, 1 } @quickVotesList;
		@quickVotesList = keys %dedupe;
	}

	my $styleSheet = GetStylesheet();

	my $tagButtons = '';
	my $doVoteButtonStyles = GetConfig('style_vote_buttons');
	
	WriteLog('GetItemVoteButtons: @quickVotesList = ' . scalar(@quickVotesList));

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

			if ($voteTotals{$quickTagCaption}) {
				$quickTagCaption .= '(' . $voteTotals{$quickTagCaption} . ')';
#				$quickTagCaption = '<b><big>' . $quickTagCaption . '</big></b>';
			}

			$tagButton =~ s/\$fileHash/$fileHash/g;
			$tagButton =~ s/\$ballotTime/$ballotTime/g;
			$tagButton =~ s/\$voteValue/$quickTagValue/g;
			$tagButton =~ s/\$voteCaption/$quickTagCaption/g;
			$tagButton =~ s/\$checksum/$checksum/g;

			$tagButtons .= $tagButton;
		}
	}

	WriteLog('GetItemVoteButtons returning: ' . $tagButtons);

	return $tagButtons;
}

sub GetItemVotesSummary { # returns html with list of tags applied to item, and their counts
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
		my $gitHash = $file{'file_hash'}; # file hash/item identifier
		my $gpgKey = $file{'author_key'}; # author's fingerprint

		my $isTextart = 0; # if textart, need extra formatting
		my $isSurvey = 0; # if survey, need extra formatting

		my $alias; # stores author's alias / name
		my $isAdmin = 0; # author is admin? (needs extra styles)

		my $isSigned; # is signed by user (also if it's a pubkey)
		if ($gpgKey) { # if there's a gpg key, it's signed
			$isSigned = 1;
		} else {
			$isSigned = 0;
		}

		# get formatted/post-processed message for this item
		my $message = GetItemMessage($file{'file_hash'}, $file{'file_path'});

		if (!$file{'item_title'}) {
			#hack #todo
			#$file{'item_title'} = 'Untitled';
			$file{'item_title'} = '';
		}

		if ($file{'remove_token'}) {
			# if remove_token is specified, remove it from the message

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
			# if there is a list of tags, check to see if there is a 'textart' tag

			# split the tags list into @itemTags array
			my @itemTags = split(',', $file{'tags_list'});

			# loop through all the tags in @itemTags
			while (scalar(@itemTags)) {
				my $thisTag = pop @itemTags;
				if ($thisTag eq 'textart') {
					$isTextart = 1; # set isTextart to 1 if 'textart' tag is present
				}
				if ($thisTag eq 'survey') {
					$isSurvey = 1; # set $isSurvey to 1 if 'survey' tag is present
				}
			}
		}

		if ($isTextart) {
			# if textart, format with extra spacing to preserve character arrangement
			$message = TextartForWeb($message);
		} elsif ($isSurvey) {
			# if survey, format with text fields for answers
			$message = SurveyForWeb($message);
			$message = 'poop';
		} else {
			# if not textart, just escape html characters
			$message = FormatForWeb($message);
		}

		#$message =~ s/>>([a-f0-9]{40})/GetItemTemplateFromHash($1, '>>')/eg;

		# if any references to other items, replace with link to item
		$message =~ s/([a-f0-9]{40})/GetHtmlLink($1)/eg;

#		$message =~ s/([a-f0-9]{40})/DBGetItemTitle($1)/eg;

		#hint GetHtmlFilename()
		#todo verify that the items exist before turning them into links,
		# so that we don't end up with broken links
#		$message =~ s/([a-f0-9]{40})/GetHtmlLink($1)/eg;
#		$message =~ s/([a-f0-9]{40})/GetItemTemplateFromHash($1)/eg;

		# if format_avatars flag is set, replace author keys with avatars
		if ($file{'format_avatars'}) {
			$message =~ s/([A-F0-9]{16})/GetHtmlAvatar($1)/eg;
		}
													 
		if (
			$isSigned
				&&
			IsAdmin($gpgKey)
		) {
			# if item is signed, and the signer is an admin, set $isAdmin = 1
			$isAdmin = 1;
		}

		# escape the alias name for outputting to page
		$alias = HtmlEscape($alias);

		# initialize $itemTemplate for storing item output
		my $itemTemplate = '';
		if ($file{'template_name'}) {
			# if template_name is specified, use that as the template
			$itemTemplate = GetTemplate($file{'template_name'});
		} else {
			# otherwise, determine template based on item length (config/item_long_threshold)
			if (length($message) > GetConfig('item_long_threshold')) {
				# if item is long, use template/item/itemlong.template
				$itemTemplate = GetTemplate("item/item2.template");
			} else {
				# otherwise use template/item/item.template
				$itemTemplate = GetTemplate("item/item2.template");
			}
		}

		# initialize item's css class to 'txt'
		my $itemClass = "txt";
		if ($isSigned) {
			# if item is signed, add "signed" css class
			$itemClass .= ' signed';
		}
		if ($isAdmin) {
			# if item is signed by an admin, add "admin" css class
			$itemClass .= ' admin';
		}
		if ($isTextart) {
			# if item is textart, add "item-textart" css class
			#todo this may not be necessary anymore
			$itemClass .= ' item-textart';
		}

		my $authorUrl; # author's profile url
		my $authorAvatar; # author's avatar
		my $authorLink; # author's link

		if ($gpgKey) {
			# if theres a $gpgKey, set up related variables
			
			$authorUrl = "/author/$gpgKey/";
			$authorAvatar = GetAvatar($gpgKey);

			$authorAvatar = trim($authorAvatar);

			# generate $authorLink from template
			$authorLink = GetTemplate('authorlink.template');
			
			$authorLink =~ s/\$authorUrl/$authorUrl/g;
			$authorLink =~ s/\$authorAvatar/$authorAvatar/g;
		} else {
			# if no author, no $authorLink
			$authorLink = ''; #todo put it into getitemtemplate logic instead
		}
		$authorLink = trim($authorLink);

		# set up $permalinkTxt, which links to the .txt version of the file
		my $permalinkTxt = $file{'file_path'};
		# strip the 'html/' prefix on the file's path, replace with /
		# todo relative links
		$permalinkTxt =~ s/html\//\//;

		# set up $permalinkHtml, which links to the html page for the item
		my $permalinkHtml = '/' . GetHtmlFilename($gitHash);
		#		my $permalinkHtml = '/' . substr($gitHash, 0, 2) . '/' . substr($gitHash, 2) . ".html";
		#		$permalinkTxt =~ s/^\.//;
													 
		my $itemText = $message; # output for item's message (formatted text)
		my $fileHash = GetFileHash($file{'file_path'}); # get file's hash
		my $fileHashShort = substr($fileHash, 0, 8) . '..';
		my $itemName; # item's 'name'
		
		if ($file{'display_full_hash'} && $file{'display_full_hash'} != 0) {
			# if display_full_hash is set, display the item's entire hash for name
			$itemName = $fileHash;
		} else {
			# if display_full_hash is not set, truncate the hash to 8 characters
			$itemName = substr($fileHash, 0, 8) . '..';
		}

		my $replyCount = $file{'child_count'};

		my $borderColor = '#' . substr($fileHash, 0, 6); # item's border color

		my $addedTime = DBGetAddedTime($fileHash); #todo optimize
		$addedTime = GetTimestampElement($addedTime);
										  
		if ($file{'item_title'}) {
			my $itemTitleTemplate = GetTemplate('item_title_link2.template');

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

		my $replyLink = $permalinkHtml . '#reply'; #todo this doesn't need the url before #reply if it is on the item's page

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		if ($authorLink) {
			$itemTemplate =~ s/\$authorLink/[$authorLink]/g;
		} else {
			$itemTemplate =~ s/\$authorLink//g;
		}
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHashShort/$fileHashShort/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;
		$itemTemplate =~ s/\$addedTime/$addedTime/g;
		$itemTemplate =~ s/\$replyLink/$replyLink/g;

		if ($replyCount) {
			$itemTemplate =~ s/\$replyCount/$replyCount/g;
		} else {
			$itemTemplate =~ s/\$replyCount/0/g;
		}


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
				$votesSummary = $votesSummary . '<br>';
				#todo templatize
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;

			#
			#end of tag summary display
		} else {
			$itemTemplate =~ s/\$votesSummary//g;
		}

		if (defined($file{'show_quick_vote'})) {
			WriteLog('GetItemTemplate: $file{\'show_quick_vote\'} = ' . $file{'show_quick_vote'});
	
			if ($file{'show_quick_vote'}) {
				my $quickVotesButtons = GetItemVoteButtons($file{'file_hash'}); #todo refactor to take vote totals directly

				my $quickVoteButtonGroup = GetTemplate('votequick2.template');
				$quickVoteButtonGroup =~ s/\$quickVotesButtons/$quickVotesButtons/g;
	
				$itemTemplate =~ s/\$quickVoteButtonGroup/$quickVoteButtonGroup/;
				$itemTemplate =~ s/\$infoBox/$quickVoteButtonGroup/;
			} else {
				$itemTemplate =~ s/\$quickVoteButtonGroup//g;
			}
		} else {
			$itemTemplate =~ s/\$quickVoteButtonGroup//g;
		}

		my $itemFlagButton = GetItemVoteButtons($file{'file_hash'}, 'all');
		$itemTemplate =~ s/\$itemFlagButton/$itemFlagButton/g;

		return $itemTemplate;
	} else {
		return '';
	}
}

sub GetPageFooter { # returns html for page footer
	my $txtFooter = GetTemplate('htmlend.template');

	my $disclaimer = GetString('disclaimer');

	$txtFooter =~ s/\$disclaimer/$disclaimer/g;

	return $txtFooter;
}

sub GetThemeColor { # returns theme color based on html/theme
	my $colorName = shift;
	chomp $colorName;

	$colorName = 'color_' . $colorName;

	my $color = GetThemeAttribute($colorName);

	if (!defined($color)) {
		$color = 'red';
		WriteLog("GetThemeColor: WARNING: Value for $colorName not found");
	}

	if ($color =~ m/^[0-9a-fA-F]{6}$/) {
		$color = '#' . $color;
	}

	return $color;
}

sub GetThemeAttribute { # returns theme color from config/theme/
	my $attributeName = shift;
	chomp $attributeName;

	# default theme
#	my $themeName = 'theme.dark';
#	my $themeName = 'theme.win95';

	my $themeName = GetConfig('html/theme');
	if (substr($themeName, 0, 6) eq 'theme.') {
	# compatibility
		if (length($themeName) > 6) {
			$themeName = substr($themeName, 6);
		}
	}

	my $attributePath = 'theme/' . $themeName . '/' . $attributeName;
	#todo sanity checks

	my $attributeValue = GetConfig($attributePath) || '';

	WriteLog('GetThemeAttribute: ' . $attributeName . ' -> ' . $attributePath . ' -> ' . $attributeValue);

	return trim($attributeValue);
}

sub GetPageHeader { # $title, $titleHtml, $pageType ; returns html for page header
	my $title = shift; # page title
	my $titleHtml = shift; # formatted page title
	my $pageType = shift; # type of page

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
		$logoText = GetConfig('logo/logo_text');
		if (!$logoText) {
			#$logoText = random_emoji();
			#$logoText = encode_entities($logoText, '^\n\x20-\x25\x27-\x7e');
			#$logoText = "*"
			$logoText = '';
		}
		#$logoText = FormatForWeb($logoText);
		#$logoText = HtmlEscape($logoText);
	}

	my $txtIndex = "";

	my $colorPrimary = GetThemeColor('primary');
	my $colorSecondary = GetThemeColor('secondary');
	my $colorBackground = GetThemeColor('background');
	my $colorText = GetThemeColor('text');
	my $colorLink = GetThemeColor('link');
	my $colorVlink = GetThemeColor('vlink');
	my $colorInputBackground = GetThemeColor('input_background');
	my $colorInputText = GetThemeColor('input_text');
	my $colorRow0Bg = GetThemeColor('row_0');
	my $colorRow1Bg = GetThemeColor('row_1');

	my $colorTagNegative = GetThemeColor('tag_negative');
	my $colorTagPositive = GetThemeColor('tag_positive');

	my $colorHighlightAdvanced = GetThemeColor('highlight_advanced');
	my $colorHighlightBeginner = GetThemeColor('highlight_beginner');

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
#	$patternName = GetConfig('header_pattern');

	# this is for the css pattern that's displayed in the background of the top menu
	my $headerBackgroundPattern = GetTemplate($patternName);
	WriteLog("$headerBackgroundPattern");
	$styleSheet =~ s/\$headerBackgroundPattern/$headerBackgroundPattern/g;
	WriteLog($styleSheet);

	#$styleSheet =~ s/\w\w/ /g;

	my $clock = '';
	if (GetConfig('clock')) {
		$clock = GetTemplate('clock.template');

		my $currentTime = GetTime();
#
#		if (GetConfig('admin/ssi/enable') && GetConfig('admin/ssi/clock_enhance')) {
#			$currentTime = GetTemplate('clock_ssi.template');
#		}
#		
#		$currentTime = trim($currentTime);

		$clock =~ s/\$currentTime/$currentTime/;
	}

	# Get the HTML page template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title

	#top menu
						  
	my $identityLink = '<span id="signin"><a href="/profile.html">Profile</a></span> <span class="myid" id=myid></span> ';
#	my $noJsIndicator = '<noscript><a href="/profile.html">Profile</a></noscript>';
	#todo profile link should be color-underlined like other menus

	my $adminKey = GetAdminKey();

	my $topMenuTemplate = GetTemplate('topmenu2.template');
	
	my $menuItems = '';

	#todo replace with config/menu/*
	$menuItems .= GetMenuItem("/", 'Read');
	$menuItems .= GetMenuItem("/write.html", 'Write');
	$menuItems .= GetMenuItem("/etc.html", 'etc.');
#	$menuItems .= GetMenuItem("/events.html", 'Events', 'advanced');
#	$menuItems .= GetMenuItem("/authors.html", 'Authors', 'advanced');
#	$menuItems .= GetMenuItem("/index0.html", GetString('menu/queue'), 'voter');
#	$menuItems .= GetMenuItem("/settings.html", 'Settings');
#	$menuItems .= GetMenuItem("/stats.html", 'Status', 'advanced');
#	$menuItems .= GetMenuItem("/tags.html", 'Tags', 'advanced');
#	if ($adminKey) {
#		$menuItems .= GetMenuItem('/author/' . $adminKey . '/', 'Admin', 1);
#	}
#	$menuItems .= GetMenuItem("/help.html", 'Help');
#	$menuItems .= GetMenuItem("/profile.html", 'Profile');
#
#	$menuItems .= $identityLink;
#	$menuItems .= $noJsIndicator;

	$topMenuTemplate =~ s/\$menuItems/$menuItems/g;
	
	$htmlStart =~ s/\$topMenu/$topMenuTemplate/g;

	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$titleHtml/$titleHtml/g;
	$htmlStart =~ s/\$title/$title/g;
	$htmlStart =~ s/\$colorLink/$colorLink/g;
	$htmlStart =~ s/\$colorVlink/$colorVlink/g;
	$htmlStart =~ s/\$colorPrimary/$colorPrimary/g;
	$htmlStart =~ s/\$colorSecondary/$colorSecondary/g;
	$htmlStart =~ s/\$colorBackground/$colorBackground/g;
	$htmlStart =~ s/\$colorText/$colorText/g;
	$htmlStart =~ s/\$colorTagNegative/$colorTagNegative/g;
	$htmlStart =~ s/\$colorTagPositive/$colorTagPositive/g;
	$htmlStart =~ s/\$colorHighlightAdvanced/$colorHighlightAdvanced/g;
	$htmlStart =~ s/\$colorHighlightBeginner/$colorHighlightBeginner/g;
	$htmlStart =~ s/\$colorInputBackground/$colorInputBackground/g;
	$htmlStart =~ s/\$colorInputText/$colorInputText/g;
	$htmlStart =~ s/\$clock/$clock/g;
	$htmlStart =~ s/\$introText/$introText/g;
	$htmlStart =~ s/\$colorRow0Bg/$colorRow0Bg/g;
	$htmlStart =~ s/\$colorRow1Bg/$colorRow1Bg/g;


	if (GetConfig('logo/enabled')) {
		$htmlStart =~ s/\$logoText/$logoText/g;
	} else {
		$htmlStart =~ s/\$logoText/$logoText/g;
	}

	# end top menu

	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetVoterTemplate { # returns html for voter checkboxes
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
		
		my $fileHashShort = substr($fileHash, 0, 8);
		
		$voteButtons =~ s/\$fileHashShort/$fileHashShort/g;
		$voteButtons =~ s/\$fileHash/$fileHash/g;
		$voteButtons =~ s/\$ballotTime/$ballotTime/g;
		$voteButtons =~ s/\$checksum/$checksum/g;

		return $voteButtons;
	}
}


sub GetTopItemsPage { # returns page with top items listing
	WriteLog("GetTopItemsPage()");

	my $txtIndex = '';

	my $title = 'Topics';
	my $titleHtml = 'Topics';

	$txtIndex = GetPageHeader($title, $titleHtml, 'top');

	$txtIndex .= GetTemplate('maincontent.template');

	my @topItems = DBGetTopItems();
							 
	if (scalar(@topItems)) {
		my $itemListingWrapper = GetTemplate('item_listing_wrapper2.template');

		my $itemListings = '';

		my $rowBgColor = '';
		my $colorRow0Bg = GetThemeColor('row_0');
		my $colorRow1Bg = GetThemeColor('row_1');

		my $itemCount = scalar(@topItems);

		while (@topItems) {
			my $itemTemplate = GetTemplate('item_listing.template');
			#todo don't need to do this every time

			#alternating row colors hack
			if ($rowBgColor eq $colorRow0Bg) {
				$rowBgColor = $colorRow1Bg;
			} else {

				$rowBgColor = $colorRow0Bg;
			}

			my $itemRef = shift @topItems;
			my %item = %{$itemRef};

			my $itemKey = $item{'file_hash'};
			my $itemTitle = $item{'item_title'};
			my $itemScore = $item{'item_score'};
			my $authorKey = $item{'author_key'};
			my $itemLastTouch = DBGetItemLatestAction($itemKey);

			if (trim($itemTitle) eq '') {
				$itemTitle = '(' . $itemKey . ')';
			}

			my $itemLink = GetHtmlFilename($itemKey);
			$itemTitle = HtmlEscape($itemTitle);

			my $authorAvatar;
			if ($authorKey) {
#				$authorAvatar = GetPlainAvatar($authorKey);
				$authorAvatar = 'by ' . GetAuthorLink($authorKey, 1);
			} else {
				$authorAvatar = '';
			}
			
			$itemLastTouch = GetTimestampElement($itemLastTouch);

			$itemTemplate =~ s/\$link/$itemLink/g;
			$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTemplate =~ s/\$itemScore/$itemScore/g;
			$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
			$itemTemplate =~ s/\$itemLastTouch/$itemLastTouch/g;
			$itemTemplate =~ s/\$rowBgColor/$rowBgColor/g;

			$itemListings .= $itemTemplate;
		}

		$itemListingWrapper =~ s/\$itemListings/$itemListings/;

		my $statusText = '';
		if ($itemCount == 0) {
			$statusText = 'No threads found.';
		} elsif ($itemCount == 1) {
			$statusText = '1 thread';
		} elsif ($itemCount > 1) {
			$statusText = $itemCount . ' threads';
		}

#		my $columnHeadings = 'Title,Score,Replied,Author';
		my $columnHeadings = '';



		$itemListingWrapper = GetWindowTemplate(
			'Top Threads',
			'<a href="/write.html">New Topic</a>',
			$columnHeadings,
			$itemListings,
			$statusText
		);

		$txtIndex .= $itemListingWrapper;
	} else {
		$txtIndex .= GetTemplate('item/no_items.template');
	}

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(prefs voting timestamps profile avatar));
#	$txtIndex = InjectJs($txtIndex, qw(prefs));

	return $txtIndex;
}

sub GetStatsPage { # returns html for stats page
	my $statsPage;

	my $itemCount = DBGetItemCount();
	my $authorCount = DBGetAuthorCount();

	my $adminId = GetAdminKey();
	my $adminLink = GetAuthorLink($adminId);

	my $serverId = GetServerKey();
	my $serverLink = GetAuthorLink($serverId);

	my $versionFull = GetMyVersion();
	my $versionShort = substr($versionFull, 0, 8);
	
	###

	$statsPage = GetPageHeader('Stats', 'Stats', 'stats');
	
	my $statsTable = GetTemplate('stats2.template');

	if ($adminId) {
		$statsTable =~ s/\$admin/$adminLink/;
	} else {
		$statsTable =~ s/\$admin/(Not defined)/;
	}
						 
	if ($serverId) {
		$statsTable =~ s/\$server/$serverLink/;
	} else {
		$statsTable =~ s/\$server/(Not defined)/;
	}

	my $lastUpdateTime = GetConfig('system/last_update_time');
	if (!defined($lastUpdateTime) || !$lastUpdateTime) {
		$lastUpdateTime = 0;
	}

	$lastUpdateTime = GetTimestampElement($lastUpdateTime);
	$statsTable =~ s/\$lastUpdateTime/$lastUpdateTime/;
##
	my $lastBuildTime = GetConfig('admin/build_end');
	if (!defined($lastBuildTime) || !$lastBuildTime) {
		$lastBuildTime = 0;
	}

	my $filesLeft = GetConfig('admin/update/files_left') || 0;

	$lastBuildTime = GetTimestampElement($lastBuildTime);
	$statsTable =~ s/\$lastBuildTime/$lastBuildTime/;

	$statsTable =~ s/\$versionFull/$versionFull/;
	$statsTable =~ s/\$versionShort/$versionShort/;
	$statsTable =~ s/\$itemCount/$itemCount/;
	$statsTable =~ s/\$authorCount/$authorCount/;
	$statsTable =~ s/\$filesLeft/$filesLeft/;

	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	$statsPage = InjectJs($statsPage, qw(avatar fresh prefs timestamps pingback profile));

	return $statsPage;
}

sub InjectJs { # inject js template(s) before </body> ; $html, @scriptNames
	my $html = shift;     # html we're going to inject into

	my @scriptNames = @_; # array of names of script templates (minus the .js.template suffix)

	my $scriptsText = '';  # will contain all the js we want to inject
	my $scriptsComma = ''; # separator between scripts, will be set to \n\n after first script

	my %scriptsDone = ();  # hash to keep track of scripts we've already injected, to avoid duplicates

	if (GetConfig('clock')) {
		# if clock is enabled, automatically add it
		push @scriptNames, 'clock';
	}

	if (GetConfig('admin/force_profile')) {
		# if force_profile is enabled, automatically add it
		push @scriptNames, 'force_profile';
	}

	# loop through all the scripts
	foreach my $script (@scriptNames) {
		# only inject each script once, otherwise move on
		if (defined($scriptsDone{$script})) {
			next;
		} else {
			$scriptsDone{$script} = 1;
		}

		# separate each script with \n\n
		if (!$scriptsComma) {
			$scriptsComma = "\n\n";
		} else {
			$scriptsText .= $scriptsComma;
		}

		my $scriptTemplate = GetTemplate("js/$script.js.template");

		if ($script eq 'voting') {
			# for voting.js we need to fill in some theme colors
			my $colorSuccessVoteUnsigned = GetThemeColor('success_vote_unsigned');
			my $colorSuccessVoteSigned = GetThemeColor('success_vote_signed');

			$scriptTemplate =~ s/\$colorSuccessVoteUnsigned/$colorSuccessVoteUnsigned/g;
			$scriptTemplate =~ s/\$colorSuccessVoteSigned/$colorSuccessVoteSigned/g;
		}

		if (index($scriptTemplate, '>') > -1) {
			# warning here if script content contains > character, which is incompatible with mosaic's html comment syntax
			WriteLog('InjectJs(): WARNING! Inject script "' . $script . '" contains > character');
		}

		# add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	# get the wrapper, i.e. <script>$javascript</script>
	my $scriptInject = GetTemplate('scriptinject.template');
	# fill in the wrapper with our scripts from above
	$scriptInject =~ s/\$javascript/$scriptsText/g;

	if (index($html, '</body>') > -1) {
		# replace it into html, right before the closing </body> tag
		$html =~ s/<\/body>/$scriptInject<\/body>/;
	} else {
		# if there was no </body> tag, just append at the end
		$html .= "\n\n" . $scriptInject;
		WriteLog('InjectJs(): WARNING! $html does not contain </body>');
	}

	return $html;
}

sub GetScoreboardPage { #returns html for /authors.html
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Top Scores';
	my $titleHtml = 'Top Scores';

	my $currentTime = GetTime();

	$txtIndex = GetPageHeader($title, $titleHtml, 'scoreboard');

	$txtIndex .= GetTemplate('maincontent.template');

	my @topAuthors = DBGetTopAuthors();

	my $authorListingWrapper = GetTemplate('author_listing_wrapper.template');

	my $authorListings = '';

	my $authorCount = scalar(@topAuthors);

	while (@topAuthors) {
		# get the friend's key
		my $authorRef = shift @topAuthors;
		my %author = %{$authorRef};

		my $authorKey = $author{'author_key'};
		my $authorAlias = $author{'author_alias'};
		my $authorScore = $author{'author_score'};
		my $authorWeight = $author{'author_weight'} || 1;
		my $authorLastSeen = $author{'last_seen'};
		my $authorItemCount = $author{'item_count'};
		my $authorAvatar = GetHtmlAvatar($authorKey);
		my $authorVoteButtons = GetItemVoteButtons($authorKey, 'author');

		if (!$authorVoteButtons) {
			$authorVoteButtons = '-';
		}

		my $authorLink = "/author/" . $authorKey . "/";

#		my $authorFriendKey = $authorFriend->{'author_key'};

		my $authorItemTemplate = GetTemplate('author_listing.template');
		#todo don't need to do this every time
#
		$authorLastSeen = GetTimestampElement($authorLastSeen);
#		$authorLastSeen = GetSecondsHtml(GetTime() - $authorLastSeen) . ' ago';
#
		$authorItemTemplate =~ s/\$link/$authorLink/g;
		$authorItemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
		$authorItemTemplate =~ s/\$authorScore/$authorScore/g;
		$authorItemTemplate =~ s/\$authorWeight/$authorWeight/g;
		$authorItemTemplate =~ s/\$authorLastSeen/$authorLastSeen/g;
		$authorItemTemplate =~ s/\$authorItemCount/$authorItemCount/g;
		$authorItemTemplate =~ s/\$authorKey/$authorKey/g;
		$authorItemTemplate =~ s/\$authorVoteButtons/$authorVoteButtons/g;

		$authorListings .= $authorItemTemplate;
	}

	my $authorCountMessage = '';
	if ($authorCount == 1) {
		$authorCountMessage = '1 author';
	} else {
		$authorCountMessage = $authorCount . ' authors';
	}

	$authorListingWrapper =~ s/\$authorListings/$authorListings/;
	$authorListingWrapper =~ s/\$authorCountMessage/$authorCountMessage/;

	$txtIndex .= $authorListingWrapper;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs timestamps profile voting));

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
		#$pageType can be 'author', 'tag
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
		my $authorScore = DBGetAuthorScore($authorKey) || 0;
		my $itemCount = DBGetAuthorItemCount($authorKey);
		my $authorDescription = '';
		my $authorWeight = DBGetAuthorWeight($authorKey);
		my $authorLastSeen = DBGetAuthorLastSeen($authorKey) || 0;

		my $publicKeyHash = DBGetAuthorPublicKeyHash($authorKey);
		my $publicKeyHashHtml = '';
		if (defined($publicKeyHash) && IsSha1($publicKeyHash)) {
			$publicKeyHashHtml = GetHtmlLink($publicKeyHash);
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
			$authorDescription .= '<b>Admin.</b>';
		}

		if ($authorDescription) {
			$authorDescription .= '<br>';
		}
		$authorDescription .= GetItemVotesSummary($publicKeyHash);

		my $profileVoteButtons = GetItemVoteButtons($publicKeyHash, 'pubkey');
		
		$authorLastSeen = GetTimestampElement($authorLastSeen);

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
		} else {
			$authorInfoTemplate =~ s/\$publicKeyHash//g;
		}


		##### friends list begin #####

		# get list of friends from db
		my @authorFriendsArray = DBGetAuthorFriends($authorKey);

		# generated html will reside here
		my $authorFriends = '';

		while (@authorFriendsArray) {
			# get the friend's key
			my $authorFriend = shift @authorFriendsArray;
			my $authorFriendKey = $authorFriend->{'author_key'};

			# get avatar (with link) for key
			my $authorFriendAvatar .= GetAuthorLink($authorFriendKey);

			# get friend list item template and insert linked avatar to it
			my $authorFriendTemplate = GetTemplate('author/author_friends_item.template');
			$authorFriendTemplate =~ s/\$authorFriendAvatar/$authorFriendAvatar/g;

			# append it to list of friends html
			$authorFriends .= $authorFriendTemplate;
		}

		if (!$authorFriends) {
			$authorFriends = '(has no friends)';
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
		$txtIndex = InjectJs($txtIndex, qw(avatar prefs timestamps voting profile));
	} else {
		$txtIndex = InjectJs($txtIndex, qw(avatar prefs voting profile));
	}

	return $txtIndex;
} # /GetReadPage


sub GetMenuItem { # returns html snippet for a menu item (used for both top and footer menus)
	my $address = shift;
	my $caption = shift;
	my $className = shift;

	if (!$className) {
		$className = '';
	}
#
#	if (!-e "html/$address") { #don't make a menu item if file doesn't exist
#		return '';
#	}

	my $menuItem = '';
	if ($className eq 'advanced') {
		$menuItem = GetTemplate('menuitem-advanced.template');
	} elsif ($className eq 'voter') {
		$menuItem = GetTemplate('menuitem-voter.template');
	} else {
		$menuItem = GetTemplate('menuitem.template');
	}

	my $color = '#' . substr(md5_hex($caption), 0, 6);

	$menuItem =~ s/\$address/$address/g;
	$menuItem =~ s/\$caption/$caption/g;
	$menuItem =~ s/\$color/$color/g;

	return $menuItem;
}

sub GetIndexPage { # returns html for an index page, given an array of hash-refs containing item information
	# Called from WriteIndexPages() and generate.pl
	# Should probably be replaced with GetReadPage()

	my $filesArrayReference = shift;
	my @files = @$filesArrayReference;
	my $currentPageNumber = shift;

	my $txtIndex = "";

	my $pageTitle = GetConfig('home_title');

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle, 'item_list');
	
	$txtIndex .= $htmlStart;

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	$txtIndex .= '<p>';

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
			$row->{'display_full_hash'} = 0;

			my $itemTemplate;
			$itemTemplate = GetItemTemplate($row);

			$itemList = $itemList . $itemComma . $itemTemplate;

			if ($itemComma eq '') {
				$itemComma = '<hr size=8>';
#				$itemComma = '<p>';
			}
		}
	}

	$txtIndex .= $itemList;

	$txtIndex .= '<p>';

	#	$txtIndex .= GetTemplate('voteframe.template');

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	# Add javascript warning to the bottom of the page
	$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs voting profile fresh timestamps));

	return $txtIndex;
}

sub WriteIndexPages { # writes the queue pages (index0-n.html)
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

#		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';

		my $infoMessage = '<tr><td><p>It looks like there is nothing to display here.</p><p><a href="/write.html">Would you like to write something?</a></p></td></tr>';

		$indexPage .= GetWindowTemplate('No Items', '', '', $infoMessage, 'Ready');

		$indexPage .= GetPageFooter();

		$indexPage = InjectJs($indexPage, qw(profile prefs));

		PutHtmlFile('html/index.html', $indexPage);
		PutHtmlFile('html/index0.html', $indexPage);
	}
}

sub GetLighttpdConfig {
	my $conf = GetTemplate('lighttpd/lighttpd.conf.template');
	print $conf;
	
#	my $pwd = `pwd`;
	my $pwd = cwd();
	chomp $pwd; # get rid of tailing newline
	
	my $docRoot = $pwd . '/' . 'html' . '/';
	my $serverPort = GetConfig('admin/lighttpd/port') || 3000;
	
	$conf =~ s/\$serverDocumentRoot/$docRoot/;
	$conf =~ s/\$serverPort/$serverPort/;

	if (GetConfig('admin/php/enable')) {
		my $phpConf = GetTemplate('lighttpd/lighttpd_php.conf.template');
		
		WriteLog('$phpConf beg =====');
		WriteLog($phpConf);
		WriteLog('$phpConf end =====');
		
		$conf .= "\n" . $phpConf;
	}
	
	if (GetConfig('admin/ssi/enable')) {
		my $ssiConf = GetTemplate('lighttpd/lighttpd_ssi.conf.template');

		WriteLog('$ssiConf beg =====');
		WriteLog($ssiConf);
		WriteLog('$ssiConf end =====');

		$conf .= "\n" . $ssiConf;
	}
	
	return $conf;
}

sub MakeFormPages { #generates and writes all 'form' pages (doesn't do anything atm)
}

#sub GetUserInitPage {
#	my $userInitPage = GetTemplate('user_init.template');
#	$userInitPage = InjectJs($userInitPage, 'user_init');
#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
#	$userInitPage =~ s/<\/body>/$scriptsInclude<\/body>/;
#
#	return $userInitPage;
#}
#
sub MakeSummaryPages { # generates and writes all "summary" and "static" pages
# write, add event, stats, profile management, preferences, post ok, action/vote, action/event
	WriteLog('MakeSummaryPages() BEGIN');
	
	PutHtmlFile("$HTMLDIR/test.html", GetTemplate('test.template'));

#	# User Init page
#	my $userInitPage = GetUserInitPage();
#	PutHtmlFile("$HTMLDIR/user_init.html", $userInitPage);
#
	# Submit page
	my $submitPage = GetWritePage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);

	# Add Event page
	my $eventAddPage = GetEventAddPage();
	PutHtmlFile("$HTMLDIR/event.html", $eventAddPage);

	# Stats page
	my $statsPage = GetStatsPage();
	PutHtmlFile("$HTMLDIR/stats.html", $statsPage);

	my $jsTestPage = GetTemplate('js/test.js.template');
	PutHtmlFile("$HTMLDIR/jstest.html", $jsTestPage);

	my $jsTest2Page = GetTemplate('js/test2.js.template');
#	$jsTest2Page = InjectJs($jsTest2Page, qw(sha512.js));
	PutHtmlFile("$HTMLDIR/jstest2.html", $jsTest2Page);

	my $jsTest3Page = GetTemplate('js/test3.js.template');
#	$jsTest3Page = InjectJs($jsTest3Page, qw(sha512.js));
	PutHtmlFile("$HTMLDIR/jstest3.html", $jsTest3Page);

	my $clockTest = GetTemplate('clock2.template');
	my $clockTestPage = '<html><body>';
	$clockTestPage .= $clockTest;
	$clockTestPage .= '</body></html>';
	$clockTestPage = InjectJs($clockTestPage, qw(clock));
#	$jsTest3Page = InjectJs($jsTest3Page, qw(sha512.js));
	PutHtmlFile("$HTMLDIR/clock.html", $clockTestPage);

	my $fourOhFourPage = GenerateDialogPage('404');#GetTemplate('404.template');
	if (GetConfig('clock')) {
		$fourOhFourPage = InjectJs($fourOhFourPage, qw(clock));
	}
	PutHtmlFile("$HTMLDIR/404.html", $fourOhFourPage);
#
#	# Profile page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/gpg.html", $identityPage);

	# Profile page
	my $identityPage2 = GetIdentityPage2();
	PutHtmlFile("$HTMLDIR/profile.html", $identityPage2);

	# Settings page
	my $settingsPage = GetPrefsPage();
	PutHtmlFile("$HTMLDIR/settings.html", $settingsPage);

	# Preferences page
	my $etcPage = GetEtcPage();
	PutHtmlFile("$HTMLDIR/etc.html", $etcPage);

	# Target page for the submit page
	my $postPage = GetPageHeader("Thank You", "Thank You", 'post');
#	$postPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	$postPage .= GetTemplate('maincontent.template');

	my $postTemplate = GetTemplate('page/post.template');

	$postPage .= $postTemplate;

	$postPage .= GetPageFooter();

	$postPage = InjectJs($postPage, qw(avatar post prefs));

	$postPage =~ s/<body /<body onload="makeRefLink();" /;
	
	WriteLog('MakeSummaryPages: ' . "$HTMLDIR/post.html");

	PutHtmlFile("$HTMLDIR/post.html", $postPage);
	
	
	# Ok page
#	my $okPage = GetTemplate('action_ok.template');
	my $okPage;# = GetTemplate('action_ok.template');

	$okPage .= GetPageHeader('OK', 'OK', 'default'); #GetTemplate('htmlstart.template');

	my $windowContents = GetTemplate('action_ok2.template');

	$okPage .= GetWindowTemplate('Data Received', '', '', $windowContents, 'Ready');
	#: $windowTitle, $windowMenubar, $columnHeadings, $windowBody, $windowStatus

	$okPage .= GetPageFooter();

#	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	#$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote2.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/event.html", $okPage);
		
	{
		# Manual page
		my $tfmPage = GetPageHeader("Manual", "Manual", 'manual');

		$tfmPage .= GetTemplate('maincontent.template');

		my $tfmPageContent = GetTemplate('page/manual.template');
#		$tfmPageContent .= '<p>' . GetTemplate('netnow3.template') . '</p>';

		my $tfmPageWindow = GetWindowTemplate(
			'Manual',
			'', #menubar
			'', #columns
			'<tr class=body><td>'.$tfmPageContent.'</td></tr>', #todo unhack
			'Ready'
		);

		$tfmPage .= $tfmPageWindow;

		$tfmPage .= GetPageFooter();

		$tfmPage = InjectJs($tfmPage, qw(avatar prefs profile));

		PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);

	}

	{
		# Help page
		my $tfmPage = GetPageHeader("Help", "Help", 'help');

		$tfmPage .= GetTemplate('maincontent.template');

		my $tfmPageContent = GetTemplate('page/help.template');

		my $tfmPageWindow = GetWindowTemplate(
			'Help',
			'', #menubar
			'', #columns
			'<tr class=body><td>'.$tfmPageContent.'</td></tr>', #todo unhack
			'Ready'
		);

		$tfmPage .= $tfmPageWindow;

		$tfmPage .= GetPageFooter();

		$tfmPage = InjectJs($tfmPage, qw(avatar prefs profile));

		PutHtmlFile("$HTMLDIR/help.html", $tfmPage);

	}

	{
		# Advanced Manual page
		my $tfmPage = GetPageHeader("Advanced Manual", "Advanced Manual", 'manual_advanced');

		$tfmPage .= GetTemplate('maincontent.template');

		my $tfmPageContent = GetTemplate('page/manual_advanced.template');

		my $tfmPageWindow = GetWindowTemplate(
			'Advanced Manual',
			'', #menubar
			'', #columns
			'<tr class=body><td>'.$tfmPageContent.'</td></tr>', #todo unhack
			'Ready'
		);

		$tfmPage .= $tfmPageWindow;

		$tfmPage .= GetPageFooter();

		$tfmPage = InjectJs($tfmPage, qw(avatar prefs));

		PutHtmlFile("$HTMLDIR/manual_advanced.html", $tfmPage);
	}


	# Tokens Reference page
	my $tokensPage = GetPageHeader("Tokens Reference", "Tokens Reference", 'manual_tokens');

	$tokensPage .= GetTemplate('maincontent.template');

	my $tokensPageTemplate = GetTemplate('page/manual_tokens.template');

	$tokensPage .= $tokensPageTemplate;

	$tokensPage .= GetPageFooter();

	$tokensPage = InjectJs($tokensPage, qw(avatar prefs));

	PutHtmlFile("$HTMLDIR/manual_tokens.html", $tokensPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('js/zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('js/lib/openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('js/lib/openpgp.worker.js.template'));

	# Write form javasript
	my $cryptoJsTemplate = GetTemplate('js/crypto.js.template');
#	my $prefillUsername = GetConfig('prefill_username') || '';
#	$cryptoJsTemplate =~ s/\$prefillUsername/$prefillUsername/g;

	if (GetConfig('admin/php/enable')) {
	#if php/enabled, then use post.php instead of post.html
	#todo add rewrites for this
#		$cryptoJsTemplate =~ s/\/post\.html/\/post.php/;
	}
	PutHtmlFile("$HTMLDIR/crypto.js", $cryptoJsTemplate);
	
	# Write avatar javasript
	PutHtmlFile("$HTMLDIR/avatar.js", GetTemplate('js/avatar.js.template'));

	# Write prefs javasript
	PutHtmlFile("$HTMLDIR/prefs.js", GetTemplate('js/prefs.js.template'));
	PutHtmlFile("$HTMLDIR/prefstest.html", GetTemplate('js/prefstest.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');
	if (GetConfig('admin/php/enable')) {
		$HtaccessTemplate .= "\n".GetTemplate('php/htaccess_php.template')."\n";

		my $postPhpTemplate = GetTemplate('php/post.php.template');
		PutFile('html/post.php', $postPhpTemplate);

		my $writePhpTemplate = GetTemplate('php/write.php.template');
		PutFile('html/write.php', $writePhpTemplate);

		my $cookiePhpTemplate = GetTemplate('php/cookie.php.template');
		PutFile('html/cookie.php', $cookiePhpTemplate);

		my $profilePhpTemplate = GetTemplate('php/profile.php.template');
		PutFile('html/profile.php', $profilePhpTemplate);

		my $utilsPhpTemplate = GetTemplate('php/utils.php.template');
		PutFile('html/utils.php', $utilsPhpTemplate);
	}
	PutHtmlFile("$HTMLDIR/.htaccess", $HtaccessTemplate);

	PutHtmlFile("$HTMLDIR/favicon.ico", '');

	{
		# p.gif
		WriteLog('making p.gif');

		if (!-e './config/template/p.gif.template') {
			if (-e 'default/template/p.gif.template') {
				copy('default/template/p.gif.template', 'config/template/p.gif.template');
			}
		}

		if (-e 'config/template/p.gif.template') {
			copy('config/template/p.gif.template', 'html/p.gif');
		}
	}

	WriteLog('MakeSummaryPages() END');
}

sub GetWritePage { # returns html for write page
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

	my $submitForm = GetTemplate('form/write3.template');
	#my $submitForm = GetTemplate('form/write.template');

	if (GetConfig('admin/php/enable')) {
	#if php module is enabled, change the form target to post.php
#		my $postHtml = 'post.html';
		# on a separate line because 
		# putting it into the regex would require escaping the period,
		# would in turn would mean that searching for "post.html" in the codebase would not find this line
		
#		$submitForm =~ s/$postHtml/post.php/;

		# this is how autosave would work
		# $submitForm =~ s/\<textarea/<textarea onkeyup="if (this.length > 2) { document.forms['compose'].action='\/post2.php'; }" /;
	}

	my $initText = '';

	$submitForm =~ s/\$extraFields//g;
	$submitForm =~ s/\$initText/$initText/g;

	$txtIndex .= $submitForm;

	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
		my $itemCounts = GetTemplate('form/itemcount.template');

		$itemCounts =~ s/\$itemCount/$itemCount/g;
		$itemCounts =~ s/\$itemLimit/$itemLimit/g;
	}

	$txtIndex .= GetPageFooter();

	if (GetConfig('php/enable')) {
		$txtIndex = InjectJs($txtIndex, qw(avatar write prefs profile));
	} else {
		$txtIndex = InjectJs($txtIndex, qw(avatar write write_php prefs profile));
	}
#	$txtIndex = InjectJs($txtIndex, qw(avatar write prefs profile geo));

	# add call to writeOnload to page
	$txtIndex =~ s/<body /<body onload="if (window.writeOnload) writeOnload();" /;

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
	
	if (GetConfig('brc/enable')) {;
		# if brc mode is enabled, add fields for burning man location
		my $brcLocationTemplate = GetTemplate('event/brc_location.template');
		
		$eventAddForm =~ s/\$brcLocation/$brcLocationTemplate/g;
	} else {
		$eventAddForm =~ s/\$brcLocation//g;
	}

	if (GetConfig('brc/enable')) {
		my $brcAddressForm = GetTemplate('form/brc_address.template');
		$eventAddForm =~ s/\$brcAddressForm/$brcAddressForm/;
	} else {
		$eventAddForm =~ s/\$brcAddressForm//;
	}

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

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs event_add fresh profile));

	my $colorRow0Bg = GetThemeColor('row_0');
	my $colorRow1Bg = GetThemeColor('row_1');

	$txtIndex =~ s/\$colorRow0Bg/$colorRow0Bg/g;
	$txtIndex =~ s/\$colorRow1Bg/$colorRow1Bg/g;

	return $txtIndex;
}

sub GetIdentityPage { # gpg-based identity
	my $txtIndex = "";

	my $title = "Profile";
	my $titleHtml = "Profile";

	$txtIndex = GetPageHeader($title, $titleHtml, 'identity');

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('form/profile.template');

	my $idCreateForm = GetTemplate('form/id_create2.template');
	my $prefillUsername = GetConfig('prefill_username');
	my $termsOfService = FormatForWeb(GetConfig('string/en/tos'));
	my $usernameMaxLength = GetConfig('');

	$idCreateForm =~ s/\$prefillUsername/$prefillUsername/g;
	$idCreateForm =~ s/\$termsOfService/$termsOfService/g;
	$idCreateForm =~ s/\$usernameMaxLength/$usernameMaxLength/g;
	$idPage =~ s/\$formIdCreate/$idCreateForm/g;

	my $idCurrentForm = GetTemplate('form/id_current.template');
	$idPage =~ s/\$formIdCurrent/$idCurrentForm/g;

	my $idAdminForm = GetTemplate('form/id_admin.template');
	$idPage =~ s/\$formIdAdmin/$idAdminForm/g;

	my $noJsInformation = '<noscript>' . GetWindowTemplate(
		'Without JavaScript',
		'',
		'',
		'<tr class=content><td>' . GetTemplate('no_js.template') . '</td></tr>',
		'Ready'
	) . '</noscript>';

	$idPage =~ s/\$noJsInformation/$noJsInformation/g;

	if (GetConfig('admin/gpg/use_gpg2')) {
		my $gpg2Choices = GetTemplate('gpg2.choices.template');
		$idPage =~ s/\$gpg2Algochoices/$gpg2Choices/;
	} else {
		$idPage =~ s/\$gpg2Algochoices//;
	}

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar fresh profile prefs));

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="if (window.identityOnload) { identityOnload(); }" /;

	return $txtIndex;
}

sub GetIdentityPage2 { # cookie-based identity #todo rename function
	my $txtIndex = "";

	my $title = "Profile";
	my $titleHtml = "Profile";

	$txtIndex = GetPageHeader($title, $titleHtml, 'identity');

	$txtIndex .= GetTemplate('maincontent.template');

	my $profileWindowContents = GetTemplate('form/profile2.template');
	my $profileWindow = GetWindowTemplate(
		'Profile',
		'<a class=advanced href="/gpg.html">Signatures</a>',
		'',
		'<tr class=content><td>' . $profileWindowContents . '</td></tr>',
		'Ready'
	);

	$txtIndex .= $profileWindow;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(prefs profile avatar));

	return $txtIndex;
}

sub GetPrefsPage { # returns html for preferences page (/settings.html)
	my $txtIndex = "";

	my $title = "Settings";
	my $titleHtml = "Settings";

	$txtIndex = GetPageHeader($title, $titleHtml, 'settings');

	$txtIndex .= GetTemplate('maincontent.template');

	my $prefsPage = GetTemplate('form/preferences.template');

	$txtIndex .= $prefsPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar fresh profile prefs));

#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="PrefsOnload();" /;

	return $txtIndex;
}

sub GetEtcPage { # returns html for etc page (/etc.html)
	my $txtIndex = "";

	my $title = "Etc";
	my $titleHtml = "Etc";

	$txtIndex = GetPageHeader($title, $titleHtml, 'etc');

	$txtIndex .= GetTemplate('maincontent.template');

	my $prefsPage = GetTemplate('etc.template');

	$txtIndex .= $prefsPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar fresh profile prefs));

#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

#	$txtIndex =~ s/<body /<body onload="PrefsOnload();" /;

	return $txtIndex;
}

sub GetRssFile { # returns rss feed for current site
	my %queryParams;
	
	$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
	my @files = DBGetItemList(\%queryParams);

	my $feedContainerTemplate = GetTemplate('rss/feed.xml.template');;
	if (GetConfig('admin/html/ascii_only')) {
		my $unicodeHeader = GetTemplate('rss/feed_header_utf8.xml.template');
		my $asciiHeader = GetTemplate('rss/feed_header_ascii.xml.template');
		
		$feedContainerTemplate = $asciiHeader . substr($feedContainerTemplate, length($unicodeHeader));
	}

	my $baseUrl = 'http://localhost:3000/';

	my $feedTitle = GetConfig('home_title');
	my $feedLink = GetConfig('admin/my_domain'); # default = http://localhost:3000/
	my $feedDescription = 'site_description';
	my $aboutUrl = $baseUrl;
	
	my $feedPubDate = GetTime();
	$feedPubDate = localtime($feedPubDate);
	#%a, %d %b %Y %H:%M +:%S %Z
	
	if (!$feedLink) {
		$feedLink = 'localhost:3000';
	}
	$feedLink = 'http://' . $feedLink;

	$feedContainerTemplate =~ s/\$feedTitle/$feedTitle/;
	$feedContainerTemplate =~ s/\$feedLink/$feedLink/;
	$feedContainerTemplate =~ s/\$feedDescription/$feedDescription/;
	$feedContainerTemplate =~ s/\$feedPubDate/$feedPubDate/;
	$feedContainerTemplate =~ s/\$aboutUrl/$aboutUrl/;

	my $feedItems = '';
	my $feedItemsToc = '';

	foreach my $file(@files) {
		my $fileHash = $file->{'file_hash'};

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");

			return;
		}


		#
		#"item_flat.file_path file_path,
		#item_flat.item_name item_name,
		#item_flat.file_hash file_hash,
		#item_flat.author_key author_key,
		#item_flat.child_count child_count,
		#item_flat.parent_count parent_count,
		#item_flat.add_timestamp add_timestamp,
		#item_flat.item_title item_title,
		#item_flat.item_score item_score,
		#item_flat.tags_list tags_list";


		my $feedItem = GetTemplate('rss/feed.item.xml.template');

		my $fileName = $file->{'file_path'};
		my $itemPubDate = $file->{'add_timestamp'};
		my $itemTitle = $file->{'item_title'};
		my $itemLink = 'http://localhost:3000/' . GetHtmlFilename($fileHash);
		my $itemAbout = $itemLink;
		my $itemGuid = $itemLink;
		my $itemDescription = GetItemMessage($fileHash, $file->{'file_path'});

		if ($itemTitle eq '') {
			if ($itemDescription) {
				$itemTitle = $itemDescription;
			} else {
				$itemTitle = '(Untitled)';
			}
		}
		
		if (!$itemPubDate) {
			$itemPubDate = GetTime();
		}

		$itemTitle = FormatForRss($itemTitle);
		$itemDescription = FormatForRss($itemDescription);
		
		#todo sanitize

		$feedItem =~ s/\$itemAbout/$itemAbout/g;
		$feedItem =~ s/\$itemGuid/$itemGuid/g;
		$feedItem =~ s/\$itemPubDate/$itemPubDate/g;
		$feedItem =~ s/\$itemTitle/$itemTitle/g;
		$feedItem =~ s/\$itemLink/$itemLink/g;
		$feedItem =~ s/\$itemDescription/$itemDescription/g;

		my $feedTocItem = GetTemplate('rss/feed.toc.item.xml.template');

		$feedTocItem =~ s/\$itemUrl/$itemLink/;

		$feedItems .= $feedItem;
		$feedItemsToc .= $feedTocItem;
	}

	$feedContainerTemplate =~ s/\$feedItemsList/$feedItemsToc/;
	$feedContainerTemplate =~ s/\$feedItems/$feedItems/;

	return $feedContainerTemplate;
}

sub GetVersionPage { # returns html with version information for $version (git commit id)
	my $version = shift;

	if (!IsSha1($version)) {
		return;
	}

	my $txtPageHtml = '';

	my $pageTitle = "Information page for version $version";

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle, 'version');

	$txtPageHtml .= $htmlStart;

	$txtPageHtml .= GetTemplate('maincontent.template');

	my $versionInfo = GetTemplate('versioninfo.template');
	my $shortVersion = substr($version, 0, 8);

	$versionInfo =~ s/\$version/$version/g;
	$versionInfo =~ s/\$shortVersion/$shortVersion/g;

	$txtPageHtml .= $versionInfo;

	$txtPageHtml .= GetPageFooter();

	$txtPageHtml = InjectJs($txtPageHtml, qw(avatar fresh prefs));

	return $txtPageHtml;
}

sub MakeDataPage { # returns html for /data.html
	WriteLog('MakeDataPage() called');

	#This makes the zip file as well as the data.html page that lists its size

	my $zipInterval = 3600;
	my $lastZip = GetCache('last_zip');

	if (!$lastZip || (GetTime() - $lastZip) > $zipInterval) {
		WriteLog("Making zip files...");
		
		# zip -qr foo.zip somefile
		# -q for quiet
		# -r for recursive

		system("zip -qr $HTMLDIR/hike.tmp.zip html/txt/ log/votes.log");
		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");
		
		system("zip -q $HTMLDIR/index.sqlite3.zip.tmp cache/" . GetMyVersion() . "/index.sqlite3");
		rename("$HTMLDIR/index.sqlite3.zip.tmp", "$HTMLDIR/index.sqlite3.zip");

		PutCache('last_zip', GetTime());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}


	my $dataPage = GetPageHeader("Data", "Data", 'data');

	$dataPage .= GetTemplate('maincontent.template');

	my $dataPageContents = GetTemplate('data.template');

	my $sizeHikeZip = -s "$HTMLDIR/hike.zip";
	my $sizeSqliteZip = -s "$HTMLDIR/index.sqlite3.zip";

	$sizeHikeZip = GetFileSizeHtml($sizeHikeZip);
	if (!$sizeHikeZip) {
		$sizeHikeZip = 0;
	}

	$sizeSqliteZip = GetFileSizeHtml($sizeSqliteZip);
	if (!$sizeSqliteZip) {
		$sizeSqliteZip = 0;
	}

	$dataPageContents =~ s/\$sizeHikeZip/$sizeHikeZip/g;
	$dataPageContents =~ s/\$sizeSqliteZip/$sizeSqliteZip/g;

	$dataPageContents = '<tr><td>' . $dataPageContents . '</td></tr>';#todo this should be in a template somewhere

	my $dataPageWindow = GetWindowTemplate('Data', '', '', $dataPageContents, 'Ready');

	$dataPage .= $dataPageWindow;

	$dataPage .= GetPageFooter();

	$dataPage = InjectJs($dataPage, qw(avatar prefs profile));

	PutHtmlFile("$HTMLDIR/data.html", $dataPage);
}

sub MakePage { # make a page and write it into html/ directory; $pageType, $pageParam
	# $pageType = author, item, tags, etc.
	# $pageParam = author_id, item_hash, etc.
	my $pageType = shift;
	my $pageParam = shift;

	#todo sanity checks

	WriteLog('MakePage(' . $pageType . ', ' . $pageParam . ')');

	# tag page, get the tag name from $pageParam
	if ($pageType eq 'tag') {
		my $tagName = $pageParam;

		WriteLog("update.pl \$pageType = $pageType; \$pageParam = \$tagName = $pageParam");

		my $tagPage = GetReadPage('tag', $tagName);

		PutHtmlFile('html/top/' . $tagName . '.html', $tagPage);
	}
	#
	# author page, get author's id from $pageParam
	elsif ($pageType eq 'author') {
		my $authorKey = $pageParam;

		my $authorPage = GetReadPage('author', $authorKey);

		if (!-e 'html/author/' . $authorKey) {
			mkdir ('html/author/' . $authorKey);
		}

		PutHtmlFile('html/author/' . $authorKey . '/index.html', $authorPage);
	}
	#
	# if $pageType eq item, generate that item's page
	elsif ($pageType eq 'item') {
		# get the item's hash from the param field
		my $fileHash = $pageParam;

		# get item list using DBGetItemList()
		# #todo clean this up a little, perhaps crete DBGetItem()
		my @files = DBGetItemList({'where_clause' => "WHERE file_hash = '$fileHash'"});

		if (scalar(@files)) {
			my $file = $files[0];

			# get item page's path #todo refactor this into a function
			#my $targetPath = 'html/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
			my $targetPath = 'html/' .GetHtmlFilename($fileHash);

			# create a subdir for the first 2 characters of its hash if it doesn't exist already
			if (!-e 'html/' . substr($fileHash, 0, 2)) {
				mkdir('html/' . substr($fileHash, 0, 2));
			}

			# get the page for this item and write it
			WriteLog('my $filePage = GetItemPage($file = "' . $file . '")');
			my $filePage = GetItemPage($file);
			WriteLog('PutHtmlFile($targetPath = ' . $targetPath . ', $filePage = ' . $filePage . ')');
			PutHtmlFile($targetPath, $filePage);
		} else {
			WriteLog("pages.pl: Asked to index file $fileHash, but it is not in the database! Quitting.");
		}
	}
	#
	# tags page
	elsif ($pageType eq 'tags') {
		my $tagsPage = GetTagsPage('Tags', 'Tags', '');
		PutHtmlFile("html/tags.html", $tagsPage);

		my $votesPage = GetTagsPage('Votes', 'Votes', 'ORDER BY vote_value');
		PutHtmlFile("html/votes.html", $votesPage);
	}
	#
	# events page
	elsif ($pageType eq 'events') {
		my $eventsPage = GetEventsPage();
		PutHtmlFile("html/events.html", $eventsPage);
	}
	#
	# scores page
	elsif ($pageType eq 'scores') {
		my $scoresPage = GetScoreboardPage();
		PutHtmlFile('html/authors.html', $scoresPage);
	}
	#
	# topitems page
	elsif ($pageType eq 'top') {
		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile('html/top.html', $topItemsPage);
	}
	#
	# stats page
	elsif ($pageType eq 'stats') {
		my $statsPage = GetStatsPage();
		PutHtmlFile('html/stats.html', $statsPage);
	}
	#
	# index pages (queue)
	elsif ($pageType eq 'index') {
		WriteIndexPages();
	}
	#
	# rss feed
	elsif ($pageType eq 'rss') {
		my %queryParams;

		$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
		my @rssFiles = DBGetItemList(\%queryParams);

		PutFile('html/rss.xml', GetRssFile(@rssFiles));
	}
	#
	# summary pages
	elsif ($pageType eq 'summary') {
		MakeSummaryPages();
	}
}

sub BuildTouchedPages {
	my $pagesLimit = GetConfig('admin/update/limit_page');
	if (!$pagesLimit) {
		WriteLog("WARNING: config/admin/update/limit_page missing!");
		$pagesLimit = 1000;
	}
	state $pagesProcessed;
	if (!$pagesProcessed) {
		$pagesProcessed = 1;
	}

	# get a list of pages that have been touched since the last git_flow
	# this is from the page_touch table
	my $touchedPages = DBGetTouchedPages($pagesLimit);

	# de-reference array of touched pages
	my @touchedPagesArray = @$touchedPages;

	# write number of touched pages to log
	WriteLog('scalar(@touchedPagesArray) = ' . scalar(@touchedPagesArray));

	# this part will refresh any pages that have been "touched"
	# in this case, 'touch' means when an item that affects the page
	# is updated or added
	foreach my $page (@touchedPagesArray) {
		$pagesProcessed++;
		#	if ($pagesProcessed > $pagesLimit) {
		#		WriteLog("Will not finish processing pages, as limit of $pagesLimit has been reached");
		#		last;
		#	}
		#	if ((GetTime2() - $startTime) > $timeLimit) {
		#		WriteLog("Time limit reached, exiting loop");
		#		last;
		#	}

		# dereference @pageArray
		my @pageArray = @$page;

		# get the 3 items in it
		my $pageType = shift @pageArray;
		my $pageParam = shift @pageArray;
		my $touchTime = shift @pageArray;

		# output to log
		WriteLog("\$pageType = $pageType");
		WriteLog("\$pageParam = $pageParam");
		WriteLog("\$touchTime = $touchTime");

		MakePage($pageType, $pageParam);

		DBDeletePageTouch($pageType, $pageParam);
	}

	return $pagesProcessed;
}


my $arg1 = shift;
if ($arg1) {
	if (IsItem($arg1)) {
		MakePage('item', $arg1);
	}
	if ($arg1 eq '--summary') {
		MakeSummaryPages();
	}
}

1;
