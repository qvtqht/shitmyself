#!/usr/bin/perl

# pages.pl
# to do with html page generation

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
# use File::Copy qw(copy);
use Cwd qw(cwd);


my $SCRIPTDIR = cwd();
my $HTMLDIR = $SCRIPTDIR . '/html';
my $PHPDIR = $SCRIPTDIR . '/html';
my $TXTDIR = $HTMLDIR . '/txt';
my $IMAGEDIR = $HTMLDIR . '/image';

#use List::Uniq ':all';

#use Acme::RandomEmoji qw(random_emoji);

require './utils.pl';
require './sqlite.pl';


sub GetDialogPage { # returns html page with dialog
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

			$windowContents = GetTemplate('404.template');

			# todo choose random item from list/looking_for
			my $lookingFor = 'mittens';
			$windowContents =~ s/looking for mittens/looking for $lookingFor/;

			my $pageTemplate;
			$pageTemplate = '';

			$pageTemplate .= GetPageHeader($pageTitle, $pageTitle, '404'); #GetTemplate('htmlstart.template');
			$pageTemplate .= GetTemplate('maincontent.template');
			$pageTemplate .= GetWindowTemplate($pageTitle, '', '', $windowContents, '');
			#: $windowTitle, $windowMenubar, $columnHeadings, $windowBody, $windowStatus
			$pageTemplate .= GetPageFooter();

			# settings.js provides ui consistency with other pages
			$pageTemplate = InjectJs($pageTemplate, qw(settings profile));

			return $pageTemplate;
		}
		if ($pageName eq '401') {
			$pageTitle = '401 Welcome to Access Denied';

			$windowContents = GetTemplate('401.template');

			my $pageTemplate;
			$pageTemplate = '';

			$pageTemplate .= GetPageHeader($pageTitle, $pageTitle, '401'); #GetTemplate('htmlstart.template');
			$pageTemplate .= GetTemplate('maincontent.template');
			$pageTemplate .= GetWindowTemplate($pageTitle, '', '', $windowContents, '');
			$pageTemplate .= GetPageFooter();

			return $pageTemplate;
		}
		if ($pageName eq 'ok') {
		}
	}
}

sub GetStylesheet { # returns style template based on config
	state $styleSheet;
	if ($styleSheet) {
		return $styleSheet;
	}

	my $style = GetTemplate('css/default.css.template');
	# baseline style

	if (GetConfig('html/color_avatars')) {
		$style .= "\n" . GetTemplate('style.avatar.template');
		# add style for color avatars if that's the setting
	}

	if (GetThemeAttribute('additional.css')) {
		$style .= "\n" . GetThemeAttribute('additional.css');
	}

	$styleSheet = $style;

	return $styleSheet;
}

sub GetAuthorLink { # $gpgKey, $showPlain ; returns avatar'ed link for an author id
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

	my $authorUrl = "/author/$gpgKey/index.html";

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

	my $pageStart = $pageNumber * $pageLimit;
	my $pageEnd = $pageNumber * $pageLimit + $pageLimit;
	if ($pageEnd > $itemCount) {
		$pageEnd = $itemCount - 1;
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

	# this is part of transitioning second argument to being id instead of menubar
	my $windowId = '';
	if ($windowMenubarContent) {
		if ($windowMenubarContent eq 'dialogProfile') {
			$windowId = 'dialogProfile';
		}
	}

	# stores number of columns if they exist
	# if no columns, remains at 0
	# whether there are columns or not determines:
	# * column headers
	# * colspan= in non-column cells
	my $contentColumnCount = 0;

	# base template
	my $windowTemplate = GetTemplate('window/standard.template');

	# titlebar, if there is a title
	if ($windowTitle) {
		my $windowTitlebar = GetTemplate('window/titlebar.template');
		$windowTitlebar =~ s/\$windowTitle/$windowTitle/g;

		$windowTemplate =~ s/\$windowTitlebar/$windowTitlebar/g;
	} else {
		$windowTemplate =~ s/\$windowTitlebar//g;
	}

	# menubar, if there is menubar content
	if ($windowMenubarContent) {
		my $windowMenubar = GetTemplate('window/menubar.template');
		$windowMenubar =~ s/\$windowMenubarContent/$windowMenubarContent/;

		$windowTemplate =~ s/\$windowMenubar/$windowMenubar/g;
	} else {
		$windowTemplate =~ s/\$windowMenubar//g;
		#todo currently results in an empty menubar
	}

	# column headings
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

	# main window content, aka body
	if ($windowBody) {
		if (index(lc($windowBody), '<tr') == -1) {
			$windowBody = '<tr class=content><td>' . $windowBody . '</td></tr>';
		}

		$windowTemplate =~ s/\$windowBody/$windowBody/g;
	} else {
		$windowTemplate =~ s/\$windowBody//g;
	}

	# statusbar
	if ($windowStatus) {
		my $windowStatusTemplate = GetTemplate('window/status.template');

		$windowStatusTemplate =~ s/\$windowStatus/$windowStatus/g;

		$windowTemplate =~ s/\$windowStatus/$windowStatusTemplate/g;
	} else {
		$windowTemplate =~ s/\$windowStatus//g;
	}

	# fill in column counts if necessary
	if ($contentColumnCount) {
		$windowTemplate =~ s/\$contentColumnCount/$contentColumnCount/g;
	} else {
		$windowTemplate =~ s/\ colspan=\$contentColumnCount//g;
	}

	return $windowTemplate;
}

sub InjectBodyOnload { #injects <body onload event into supplied html
	my $html = shift; #page event is to be added to
	my $onLoad = shift; #javascript to go inside onload=""

	my $onLoadTemplate = '<body onload="' . $onLoad . '" ';
	my $onLoadNeedle = '<body ';

	$html =~ s/$onLoadNeedle/$onLoadTemplate/;

	return $html;
}

sub GetPageLinks { # $currentPageNumber ; returns html for pagination links with frame/window
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
			$currentPageEnd = $itemCount - 1;
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
		my $eventItemLink = GetItemHtmlLink($eventItemHash);
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

		$eventTime = GetTimestampWidget($eventTime);
		$eventTimeUntil = GetTimestampWidget($eventTimeUntil);

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

	$txtPage = InjectJs($txtPage, qw(settings avatar timestamp voting profile));

	return $txtPage;

}

sub GetTagLinks { # $tagSelected ; returns html-formatted tags list
# tag_wrapper.template, tag.template

	my $tagSelected = shift;

	if (!$tagSelected) {
		$tagSelected = '';
	} else {
		chomp $tagSelected;
	}

	WriteLog("GetTagLinks($tagSelected)");

	my $voteCounts;
	$voteCounts = DBGetVoteCounts();
	my @voteCountsArray = @{$voteCounts};

	my $voteItemsWrapper = GetTemplate('tag_wrapper.template');

	my $voteItems = '';

	my $voteItemTemplateTemplate = GetTemplate('tag.template');
	while (@voteCountsArray) {
		my $voteItemTemplate = $voteItemTemplateTemplate;

		my $tagArrayRef = shift @voteCountsArray;

		my $tagName = @{$tagArrayRef}[0]; #todo assoc-array
		my $tagCount = @{$tagArrayRef}[1];
		my $voteItemLink = "/top/" . $tagName . ".html";

		if ($tagName eq $tagSelected) {
			#todo template this
			$voteItems .= "<b>#$tagName</b>\n";
		}
		else {
			$voteItemTemplate =~ s/\$link/$voteItemLink/g;
			$voteItemTemplate =~ s/\$tagName/$tagName/g;
			$voteItemTemplate =~ s/\$tagCount/$tagCount/g;

			$voteItems .= $voteItemTemplate;
		}
	}

	if (!$voteItems) {
		# $voteItems = GetTemplate('tag_listing_empty.template');
	}

	$voteItemsWrapper =~ s/\$tagLinks/$voteItems/g;

	return $voteItemsWrapper;
} # GetTagLinks()

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

	if (!$voteItems) {
		$voteItems = GetTemplate('tag_listing_empty.template');
	}

	$voteItemsWrapper =~ s/\$tagListings/$voteItems/g;

	$txtIndex .= $voteItemsWrapper;

	$txtIndex .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar profile utils fresh));
		$txtIndex =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$txtIndex =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}

	return $txtIndex;
} # GetTagsPage

sub GetItemPage { # %file ; returns html for individual item page. %file as parameter
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

	my $title = '';     # title for <title>
	my $titleHtml = ''; # title for <h1>

	if (defined($file{'item_title'}) && $file{'item_title'}) {
		WriteLog("GetItemPage: defined(item_title) = true!");

		$title = HtmlEscape($file{'item_title'});
		$titleHtml = HtmlEscape($file{'item_title'});

		$title .= ' (' . substr($file{'file_hash'}, 0, 8) . '..)';
	}
	else {
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

	$file{'display_full_hash'} = 1;
	$file{'show_vote_summary'} = 1;
	# $file{'show_quick_vote'} = 1;
	$file{'vote_buttons'} = 1;
	$file{'format_avatars'} = 1;

	if (!$file{'item_title'}) {
		$file{'item_title'} = 'Untitled';
	}

	my $itemTemplate = GetItemTemplate(\%file); # GetItemPage()

	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});

	$file{'show_easyfind'} = 0;

	if ($file{'show_easyfind'}) {
		my $itemEasyFind = GetItemEasyFind($fileHash);
		#$itemTemplate =~ s/\$itemEasyFind/EasyFind: $itemEasyFind/g;
		$itemTemplate .= $itemEasyFind;
	} else {
		#$itemTemplate =~ s/\$itemEasyFind//g;
	}

	# if this item has a child_count, we want to print all the child items below
	# keywords: reply replies subitems child parent
	# REPLIES
	######################################
	if ($file{'child_count'}) {
		# get item's children (replies) and store in @itemReplies
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		#debug message
		WriteLog('@itemReplies = ' . @itemReplies);

		# this will contain the replies as html output
		my $allReplies = '';

		if (GetConfig('replies') && GetConfig('html/reply_form_before_reply_list')) {
			# add reply form
			my $replyForm = GetReplyForm($file{'file_hash'});
			$allReplies .= $replyForm;
		}

		# start with a horizontal rule to separate from above content
		$allReplies .= '<hr size=3>';

		# this will store separator between items.
		# first item doesn't need separator above it
		my $replyComma = '';

		foreach my $replyItem (@itemReplies) {
			# output info about item to debug
			WriteLog('$replyItem: ' . $replyItem);
			foreach my $replyVar ($replyItem) {
				WriteLog($replyVar);
			}

			DBAddItemPage($$replyItem{'file_hash'}, 'item', $file{'file_hash'});

			# use item-small template to display the reply items
			$$replyItem{'template_name'} = 'item/item-mini.template';

			# if the child item contains a reply token for our parent item
			# we want to remove it, to reduce redundant information on the page
			# to do this, we pass the remove_token parameter to GetItemTemplate() below
			$$replyItem{'remove_token'} = '>>' . $file{'file_hash'};

			# after voting, return to the main thread page
			$$replyItem{'vote_return_to'} = $file{'file_hash'};

			# trim long text items
			$$replyItem{'trim_long_text'} = 1;

			if (index(','.$$replyItem{'tags_list'}.',', ','.'notext'.',') != -1) {
				$$replyItem{'template_name'} = 'item/item-mini.template';
			} else {
				$$replyItem{'template_name'} = 'item/item-small.template';
			}

			# Get the reply template
			my $replyTemplate = GetItemTemplate($replyItem); # GetItemPage()

			# output it to debug
			WriteLog('$replyTemplate');
			WriteLog($replyTemplate);

			# if the reply item has children also, output the children
			# threads are currently limited to 2 steps
			# eventually, recurdsion can be used to output more levels
			if ($$replyItem{'child_count'}) {
				my $subRepliesTemplate = ''; # will store the sub-replies html output

				my $subReplyComma = ''; # separator for sub-replies, set to <hr on first use

				my @subReplies = DBGetItemReplies($$replyItem{'file_hash'});
				foreach my $subReplyItem (@subReplies) {
					DBAddItemPage($$subReplyItem{'file_hash'}, 'item', $file{'file_hash'});

					if (index(','.$$subReplyItem{'tags_list'}.',', ','.'notext'.',') != -1) {
						$$subReplyItem{'template_name'} = 'item/item-mini.template';
					} else {
						$$subReplyItem{'template_name'} = 'item/item-small.template';
					}
					$$subReplyItem{'remove_token'} = '>>' . $$replyItem{'file_hash'};
					$$subReplyItem{'vote_return_to'} = $file{'file_hash'};

					WriteLog('$$subReplyItem{\'remove_token\'} = ' . $$subReplyItem{'remove_token'});
					WriteLog('$$subReplyItem{\'template_name\'} = ' . $$subReplyItem{'template_name'});
					WriteLog('$$subReplyItem{\'vote_return_to\'} = ' . $$subReplyItem{'vote_return_to'});

					$$subReplyItem{'trim_long_text'} = 1;

					my $subReplyTemplate = GetItemTemplate($subReplyItem); # GetItemPage()

					if ($subReplyComma eq '') {
						$subReplyComma = '<hr size=4>';
					}
					else {
						$subReplyTemplate = $subReplyComma . $replyTemplate;
					}

					$subRepliesTemplate .= $subReplyTemplate;
				}

				# replace replies placeholder with generated html
				$replyTemplate =~ s/<replies><\/replies>/$subRepliesTemplate/;
			}
			else {
				# there are no replies, so remove replies placeholder
				$replyTemplate =~ s/<replies><\/replies>//;
			}

			if ($replyTemplate) {
				if ($replyComma eq '') {
					$replyComma = '<hr size=5>';
					# $replyComma = '<p>';
				}
				else {
					$replyTemplate = $replyComma . $replyTemplate;
				}

				$allReplies .= $replyTemplate;
			}
			else {

				WriteLog('Warning: replyTemplate is missing for some reason!');
			}
		}

		if (GetConfig('replies') && GetConfig('html/reply_form_after_reply_list') && !GetConfig('html/reply_form_before_reply_list')) {
			# add reply form
			my $replyForm = GetReplyForm($file{'file_hash'});
			# start with a horizontal rule to separate from above content
			$allReplies .= '<hr size=3>';
			$allReplies .= $replyForm;
		}

		$itemTemplate =~ s/<replies><\/replies>/$allReplies/;
		$itemTemplate .= '<hr><br>';
	}
	else {
		my $allReplies = '';
		if (GetConfig('replies')) {
			# add reply form
			my $replyForm = GetReplyForm($file{'file_hash'});
			$allReplies .= $replyForm;
		}
		$itemTemplate =~ s/<replies><\/replies>/$allReplies/;
		$itemTemplate .= '<hr><br>';
	}

	###############
	### /REPLIES##########

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	{
		#my $itemInfoTemplate = GetTemplate('item_info.template');
		my $itemInfoTemplate;

		my $itemAttributes = DBGetItemAttribute($file{'file_hash'});
		$itemAttributes = trim($itemAttributes);

		my $itemAttributesTable = '';
		{ # arrange into table nicely
			foreach my $itemAttribute (split("\n", $itemAttributes)) {
				if ($itemAttribute) {
					my ($iaName, $iaValue) = split('\|', $itemAttribute);
					if ($iaName =~ m/_timestamp/) {
						$iaValue = $iaValue . ' (' . GetTimestampWidget($iaValue) . ')';
					}
					if ($iaName eq 'author_key') {
						$iaValue = $iaValue . ' (' . trim(GetAvatar($iaValue)) . ')';
					}
					if ($iaName eq 'title') {
						$iaValue = HtmlEscape($iaValue);;
					}

					$itemAttributesTable .= '<tr><td>';
					$itemAttributesTable .= $iaName;
					$itemAttributesTable .= '</td><td>';
					$itemAttributesTable .= $iaValue;
					$itemAttributesTable .= '</td></tr>';
				}
			}

			{ # tags list for attributes list bolt-on
				$itemAttributesTable .= '<tr><td>';
				$itemAttributesTable .= 'tags_all';
				$itemAttributesTable .= '</td><td>';
				$itemAttributesTable .= $file{'tags_list'};
				$itemAttributesTable .= '</td></tr>';
			}

			# # #todo turn it into a loop and turn plain epoch timestamps into timestamp elements
			# my $trTr = '</td></tr><tr><td>';
			# $itemAttributes =~ s/\n/$trTr/gi;
			# my $tdTd = '</td><td>';
			# $itemAttributes =~ s/\|/$tdTd/gi;
			# $itemAttributes = '<tr><td>' . $itemAttributes . '</td></tr>';

			my $itemAttributesWindow = GetWindowTemplate('Item Attributes', '', 'attribute,value', $itemAttributesTable, '');
			$itemAttributesWindow = '<span class=advanced>' . $itemAttributesWindow . '</span>';
			$txtIndex .= $itemAttributesWindow;
		}
	}

	# end page with footer
	$txtIndex .= GetPageFooter();

	if (GetConfig('replies')) {
		# if replies is on, include write.js and write_buttons.js
		$txtIndex = InjectJs($txtIndex, qw(settings avatar voting utils profile translit write write_buttons timestamp));
	} else {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar voting utils profile translit timestamp));
	}

	if (GetConfig('admin/js/enable')) {
		$txtIndex =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$txtIndex =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}

	#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto2.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
} # GetItemPage()

sub GetReplyForm { # $replyTo ; returns reply form for specified item
	my $replyTo = shift;
	chomp $replyTo;

	if (!$replyTo || !IsItem($replyTo)) {
		WriteLog('GetReplyForm: warning: sanity check failed');
		return '';
	}
	my $replyTag = GetTemplate('replytag.template');
	my $replyForm = GetTemplate('form/write/reply.template');

	$replyTag =~ s/\$parentPost/$replyTo/g;
	$replyForm =~ s/\$replyTo/$replyTo/g;

	# at the top of reply.template, there is a placeholder for the voting buttons
	my $voteButtons = GetItemVoteButtons($replyTo);
	$replyForm =~ s/\$votesSummary/$voteButtons/g;

	if (GetConfig('admin/php/enable') && !GetConfig('admin/php/rewrite')) {
		$replyForm =~ s/\/post\.html/\/post.php/g;
	}

	if (GetConfig('admin/js/enable')) {
		$replyForm = AddAttributeToTag(
			$replyForm,
			'input type=submit',
			'onclick',
			"this.value='Meditate...';if(window.writeSubmit){return writeSubmit(this);}"
		);

		if (GetConfig('admin/php/enable')) {
			$replyForm = AddAttributeToTag($replyForm, 'textarea', 'onchange', "if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }");
			$replyForm = AddAttributeToTag($replyForm, 'textarea', 'onkeyup', "if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }");
		}

		if (GetConfig('admin/js/translit')) {
			# add onkeydown event which calls translitKey if feature is enabled
			# translit substitutes typed characters with a different character set
			$replyForm = AddAttributeToTag(
				$replyForm,
				'textarea',
				'onkeydown',
				'if (window.translitKey) { translitKey(event, this); } else { return true; }'
			);
		}

		return $replyForm;
	}

	return $replyForm;
} # GetReplyForm();

sub GetItemHtmlLink { # $hash, [link caption], [#anchor]
	my $hash = shift;

	if ($hash) {
		#todo templatize this
		my $linkCaption = shift;
		if (!$linkCaption) {
			$linkCaption = substr($hash, 0, 8) . '..';
		}

		my $hashAnchor = shift;
		if ($hashAnchor) {
			if (substr($hashAnchor, 0, 1) ne '#') {
				$hashAnchor = '#' . $hashAnchor;
			}
		} else {
			$hashAnchor = '';
		}

		return '<a href="/' . GetHtmlFilename($hash) . $hashAnchor . '">' . $linkCaption . '</a>';
	} else {
	}
} # GetItemHtmlLink()

sub GetItemVoteButtons { # $fileHash, [$tagSet], [$returnTo] ; get vote buttons for item in html form
	my $fileHash = shift; # item's file hash
	my $tagSet = shift;   # (optional) use a particular tagset instead of item's default
	my $returnTo = shift; # (optional) what page to return to instead of current (for use by post.php)
	WriteLog('GetItemVoteButtons(' . ($fileHash ? $fileHash : '-') . ', ' . ($tagSet ? $tagSet : '-') . ')');

	if (!IsItem($fileHash)) {
		WriteLog('GetItemVoteButtons: warning: sanity check failed, returning');
		return '';
	}

	my @quickVotesList; # this will hold all the tag buttons we want to display
	my %voteTotals = DBGetItemVoteTotals($fileHash);
	WriteLog('GetItemVoteButtons: scalar(%voteTotals) = ' . scalar(%voteTotals));

	if ($tagSet) {
		# if $tagSet is specified, just use that list of tags
		my $quickVotesForTagSet = GetConfig('tagset/' . $tagSet);
		if ($quickVotesForTagSet) {
			push @quickVotesList, split("\n", $quickVotesForTagSet);
		}
		else {
			# no tagset?
			WriteLog('GetItemVoteButtons: warning: tagset not found: ' . $tagSet);
			return '';
		}
	} # $tagSet
	else {
		# need to look up item's default tagset
		my $quickVotesForTags;
		foreach my $voteTag (keys %voteTotals) {
			$quickVotesForTags = GetConfig('tagset/' . $voteTag);
			if ($quickVotesForTags) {
				push @quickVotesList, split("\n", $quickVotesForTags);
			}
		}

		# all items will have a 'flag' button
		push @quickVotesList, 'flag';

		# remove duplicates
		my %dedupe = map {$_, 1} @quickVotesList;
		@quickVotesList = keys %dedupe;
	}

	my $styleSheet = GetStylesheet(); # for looking up which vote buttons need a class=
	# if they're listed in the stylesheet, add a class= below
	# the class name is tag-foo, where foo is tag

	my $tagButtons = '';
	my $doVoteButtonStyles = GetConfig('style_vote_buttons');
	my $jsEnabled = GetConfig('admin/js/enable');

	WriteLog('GetItemVoteButtons: @quickVotesList = ' . scalar(@quickVotesList));

	foreach my $quickTagValue (@quickVotesList) {
		my $ballotTime = GetTime();

		if ($fileHash && $ballotTime) {
			my $tagButton = GetTemplate('vote/vote_button.template');

			if ($jsEnabled) {
				$tagButton = AddAttributeToTag(
					$tagButton,
					'a', 'onclick',
					trim("
						if (window.SignVote) {
							var gt = unescape('%3E');
							return SignVote(this, gt+gt+'\$fileHash\\n#\$voteValue');
						}
					")
				);
			}

			if ($doVoteButtonStyles) {
				# this is a hack, eventually should be replaced by config/tag_color #todo
				if (index($styleSheet, "tag-$quickTagValue") > -1) {
					$tagButton =~ s/\$class/tag-$quickTagValue/g;
				}
				else {
					$tagButton =~ s/class="\$class"//g;
				}
			}

			my $quickTagCaption = GetString($quickTagValue);
			WriteLog('GetItemVoteButtons: $$$ ' . $quickTagCaption . ' $ ' . $quickTagValue);
			if ($voteTotals{$quickTagCaption}) {
				# $voteTotals{$quickTagCaption} is the number of tags of this type item has

				$quickTagCaption .= '(' . $voteTotals{$quickTagCaption} . ')';
				# $quickTagCaption = '<b><big>' . $quickTagCaption . '</big></b>';
			}

			if ($returnTo) {
				# set value for $returnTo placeholder
				$tagButton =~ s/\$returnTo/$returnTo/g;
			}
			else {
				# remove entire returnto= parameter
				$tagButton =~ s/&returnto=\$returnTo//g;
			}

			$tagButton =~ s/\$fileHash/$fileHash/g;
			$tagButton =~ s/\$ballotTime/$ballotTime/g;
			$tagButton =~ s/\$voteValue/$quickTagValue/g;
			$tagButton =~ s/\$voteCaption/$quickTagCaption/g;

			$tagButtons .= $tagButton;
		} # if ($fileHash && $ballotTime)
	} # foreach my $quickTagValue (@quickVotesList)

	WriteLog('GetItemVoteButtons returning: ' . $tagButtons);

	return $tagButtons;
} # GetItemVoteButtons()

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

sub str_repeat {
	my $string = shift;
	my $count = shift;
	WriteLog('str_repeat: $string = ' . $string . '; $count = ' . $count);
	WriteLog('str_repeat: ' . $string x $count); #todo performance?
	return $string x $count;
}

sub GetWidgetExpand { # $parentCount, $url ; gets "More" button widget GetExpandWidget
	my $parentCount = shift; # how many levels of parents to go up
	# for example, for <table><tr><td><a>here it would be 3 layers instead of 1
	# accepts integers 1-10

	my $url = shift;
	# url to point the link to after the expand happens

	if (!$parentCount || !$parentCount) {
		WriteLog('GetWidgetExpand: warning: sanity check failed');
		return '';
	}

	my $widgetTemplate = GetTemplate('widget/more_button.template');

	if ($widgetTemplate) {
		# <a href="/etc.html">More</a>
		WriteLog('GetWidgetExpand: got template ok, going to fill it in');
		$widgetTemplate = str_replace('/etc.html', $url, $widgetTemplate);

		if (GetConfig('admin/js/enable')) {
			my $jsTemplate = "if (window.ShowAll && this.removeAttribute) { if (this.style) { this.style.display = 'none'; } return ShowAll(this, this.parentElement); } else { return true; }";
			if ($parentCount < 10 && $parentCount > 1 && !($parentCount =~ /\\D/)) {
				# adjust number of times it says ".parentElement"
				$jsTemplate = str_replace('.parentElement', str_repeat('.parentElement', $parentCount), $jsTemplate);
			} else {
				WriteLog('GetWidgetExpand: warning: $parentCount sanity check failed');
				return '';
			}

			$widgetTemplate = AddAttributeToTag(
				$widgetTemplate,
				'a href="/etc.html"', #todo this should link to item itself
				'onclick',
				$jsTemplate
			);
		}

		#$widgetTemplate = str_replace('/etc.html', $url, $widgetTemplate);
	} else {
		WriteLog('GetWidgetExpand: warning: widget/more_button template not found');
		return '';
	}

	return $widgetTemplate;
} # GetWidgetExpand() @16019xxxxx

sub GetItemTemplate { # returns HTML for outputting one item
	WriteLog("GetItemTemplate() begin");

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

	# show_easyfind = show/hide easyfind words
	# item_type = 'txt' or 'image'
	# vote_return_to = page to redirect user to after voting, either item hash or url
	# trim_long_text = trim text if it is longer than config/number/item_long_threshold

	# get %file hash from supplied parameters
	my %file = %{shift @_};

	# verify that referenced file path exists
	if (-e $file{'file_path'}) {
		my $itemHash = $file{'file_hash'}; # file hash/item identifier
		my $gpgKey = $file{'author_key'}; # author's fingerprint

		my $isTextart = 0; # if textart, need extra formatting
		my $isSurvey = 0; # if survey, need extra formatting
		my $isTooLong = 0; # if survey, need extra formatting

		my $alias; # stores author's alias / name
		my $isAdmin = 0; # author is admin? (needs extra styles)

		my $itemType = '';

		my $isSigned; # is signed by user (also if it's a pubkey)
		if ($gpgKey) { # if there's a gpg key, it's signed
			$isSigned = 1;
		} else {
			$isSigned = 0;
		}

		# get formatted/post-processed message for this item
		my $message = GetItemMessage($file{'file_hash'}, $file{'file_path'});

		# WriteLog($message);

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
				if ($thisTag eq 'toolong') {
					$isTooLong = 1; # set $isTooLong to 1 if 'survey' tag is present
				}
			}
		}

		if ($isTooLong && exists($file{'trim_long_text'}) && $file{'trim_long_text'}) {
			my $itemLongThreshold = GetConfig('number/item_long_threshold') || 1024;

			if (length($message) > $itemLongThreshold) {
				$message = substr($message, 0, $itemLongThreshold) . "\n" . '[ Long message has been trimmed ]';
				# if item is long, trim it
			}
		}

		if ($file{'item_type'}) {
			$itemType = $file{'item_type'};
		} else {
			$itemType = 'txt';
		}

		if (!$file{'item_title'}) {
			#hack #todo
			$file{'item_title'} = 'Untitled';
			#$file{'item_title'} = '';
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

		# } elsif ($isSurvey) {
		# 	# if survey, format with text fields for answers
		# 	$message = SurveyForWeb($message);

		if ($isTextart) {
			# if textart, format with extra spacing to preserve character arrangement
			$message = TextartForWeb($message);
		} else {
			# if not textart, just escape html characters
			WriteLog('GetItemTemplate: calling FormatForWeb');
			$message = FormatForWeb($message);
		}

		#if (index($message, "<br>\n--\n<br>\n") > -1) {
		if (GetConfig('html/hide_dashdash_signatures')) {
			if (index($message, "<br>-- <br>") != -1) {
				$message =~ s/(.+)<br>-- <br>(.+)/$1<span class=advanced><br>\n-- <br>\n$2<\/span>/smi;
				# m = multi-line
				# s = multi-line
				# g = all instances
				# i = case-insensitive
			}
		}

		#if ($file{'expand_item_references'}) { #todo this also doesn't do anything
		#if ($file{'item_type'} eq 'image') { #todo this doesn't work
		if (0) {
			# >> \>\> #does not work
			$message =~ s/>>([a-f0-9]{40})/GetItemTemplateFromHash($1)/eg;
		} else {
			# if any references to other items, replace with link to item
			$message =~ s/([a-f0-9]{40})/GetItemHtmlLink($1)/eg;
			#$message =~ s/([a-f0-9]{40})/DBGetItemTitle($1)/eg;
		}

		if ($itemHash) {
			$message =~ s/\[\[([a-z]+)\]\]/GetItemVoteButtons($itemHash, $1)/ge;
		}

		WriteLog('GetItemTemplate: $message is: ' . $message);

		#hint GetHtmlFilename()
		#todo verify that the items exist before turning them into links,
		# so that we don't end up with broken links
#		$message =~ s/([a-f0-9]{40})/GetItemHtmlLink($1)/eg;
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
			# default template
			if (length($message) <= 140) {
				# for text 140 characters or fewer, use item-short.template
				$itemTemplate = GetTemplate("item/item-short.template");
			} else {
				$itemTemplate = GetTemplate("item/item.template");
			}
		}

		if (GetConfig('admin/js/enable')) {
			# <span class=expand></span>
			$itemTemplate = str_replace(
				'<span class=expand></span>',
				'<span class=expand>' .
					GetWidgetExpand(5, '$itemUrl') .
					'</span>',
				$itemTemplate
			);

			# $itemTemplate = AddAttributeToTag(
			# 	$itemTemplate,
			# 	'a href="/etc.html"', #todo this should link to item itself
			# 	'onclick',
			# 	"if (window.ShowAll && this.removeAttribute) { this.removeAttribute('onclick'); return ShowAll(this, this.parentElement.parentElement.parentElement.parentElement.parentElement); } else { return true; }"
			# );
		}

		my $authorUrl; # author's profile url
		my $authorAvatar; # author's avatar
		my $authorLink; # author's link

		if ($gpgKey) {
			# get author link for this gpg key
			$authorLink = GetAuthorLink($gpgKey);
		} else {
			# if no author, no $authorLink
			$authorLink = ''; #todo put it into GetItemTemplate() logic instead
		}
		$authorLink = trim($authorLink);
		my $permalinkTxt = $file{'file_path'};

		{
		    #todo still does not work perfectly, this
			# set up $permalinkTxt, which links to the .txt version of the file

			# strip the 'html/' prefix on the file's path, replace with /
			# todo relative links
			$permalinkTxt =~ s/$HTMLDIR\//\//;
			$permalinkTxt =~ s/^html\//\//;
		}

		# set up $permalinkHtml, which links to the html page for the item
		my $permalinkHtml = '/' . GetHtmlFilename($itemHash);
		#		my $permalinkHtml = '/' . substr($itemHash, 0, 2) . '/' . substr($itemHash, 2) . ".html";
		#		$permalinkTxt =~ s/^\.//;

		my $fileHash = GetFileHash($file{'file_path'}); # get file's hash
		my $fileHashShort = substr($fileHash, 0, 8) . '..';
		my $itemAnchor = substr($fileHash, 0, 8);
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
		my $addedTime = GetTimestampWidget(DBGetAddedTime($fileHash)); #todo optimize
		my $itemTitle = $file{'item_title'};

		if ($file{'item_title'}) {
			my $itemTitleTemplate = GetTemplate('item_title_link2.template');

			my $itemTitle = HtmlEscape($file{'item_title'});

			$itemTitleTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTitleTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;

			$itemTemplate =~ s/\$itemTitleTemplate/$itemTitleTemplate/g;
		} else {
			$itemTemplate =~ s/\$itemTitleTemplate//g;
		}

		my $itemText = '';
		my $itemClass = '';

		if ($itemType eq 'txt') {
			$itemText = $message; # output for item's message (formatted text)

			$itemClass = "txt";
			if ($isSigned) {
				# if item is signed, add "signed" css class
				$itemClass .= ' signed';
			}

			if ($isTextart) {
				# if item is textart, add "item-textart" css class
				#todo this may not be necessary anymore
				$itemClass .= ' item-textart';

				my $textartContainer = GetTemplate('item/container/textart.template');
				$textartContainer =~ s/\$message/$itemText/g;

				$itemText = $textartContainer;
			}

			if ($isAdmin) {
				# if item is signed by an admin, add "admin" css class
				$itemClass .= ' byadmin';

				my $adminContainer = GetTemplate('item/container/admin.template');

				my $colorAdmin = GetThemeColor('admin') || '#c00000';
				$adminContainer =~ s/\$colorAdmin/$colorAdmin/g;

				$adminContainer =~ s/\$message/$itemText/g;

				$itemText = $adminContainer;
			}
		} # $itemType eq 'txt'

		if (GetConfig('admin/image/enable') && $itemType eq 'image') {
			my $imageContainer = GetTemplate('item/container/image.template');

			my $imageUrl = "/thumb/thumb_800_$fileHash.gif"; #todo hardcoding no
			# my $imageUrl = "/thumb/thumb_420_$fileHash.gif"; #todo hardcoding no
			my $imageSmallUrl = "/thumb/thumb_42_$fileHash.gif"; #todo hardcoding no
			my $imageAlt = $itemTitle;

			# $imageSmallUrl is a smaller image, used in the "lowsrc" attribute for img tag

			$imageContainer =~ s/\$imageUrl/$imageUrl/g;
			$imageContainer =~ s/\$imageSmallUrl/$imageSmallUrl/g;
			$imageContainer =~ s/\$imageAlt/$imageAlt/g;

			$itemText = $imageContainer;

			$itemClass = "image";
		} # $itemType eq 'image'
		elsif ($itemType eq 'image') {
		    $itemText = 'itemType eq image, but images disabled';
			WriteLog('$itemType eq image, but images disabled');
		}

		my $replyLink = $permalinkHtml . '#reply'; #todo this doesn't need the url before #reply if it is on the item's page

		if (index($itemText, '$') > -1) {
			# this is a kludge, should be a better solution
			#$itemText = '<code>item text contained disallowed character</code>';
			$itemText =~ s/\$/%/g;
		}

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		if ($authorLink) {
			$itemTemplate =~ s/\$authorLink/[$authorLink]/g;
		} else {
			$itemTemplate =~ s/\$authorLink;//g;
			# if there is no authorlink needed,
			# get rid of the semicolon after the placeholder as well
		}
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHashShort/$fileHashShort/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;
		$itemTemplate =~ s/\$addedTime/$addedTime/g;
		$itemTemplate =~ s/\$replyLink/$replyLink/g;
		$itemTemplate =~ s/\$itemAnchor/$itemAnchor/g;

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
				my $quickVotesButtons = '';
				if (defined($file{'vote_return_to'}) && $file{'vote_return_to'}) {
					WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

					$quickVotesButtons = GetItemVoteButtons($file{'file_hash'}, 0, $file{'vote_return_to'}); #todo refactor to take vote totals directly
				} else {
					# WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

					$quickVotesButtons = GetItemVoteButtons($file{'file_hash'}); #todo refactor to take vote totals directly
				}

				my $quickVoteButtonGroup = GetTemplate('vote/votequick2.template');
				$quickVoteButtonGroup =~ s/\$quickVotesButtons/$quickVotesButtons/g;
	
				$itemTemplate =~ s/\$quickVoteButtonGroup/$quickVoteButtonGroup/;
				$itemTemplate =~ s/\$infoBox/$quickVoteButtonGroup/;
			} else {
				$itemTemplate =~ s/\$quickVoteButtonGroup//g;
			}
		} else {
			$itemTemplate =~ s/\$quickVoteButtonGroup//g;
		}

		my $itemFlagButton = '';
		if (defined($file{'vote_return_to'}) && $file{'vote_return_to'}) {
			WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemVoteButtons($file{'file_hash'}, 'all', $file{'vote_return_to'}); #todo refactor to take vote totals directly
		} else {
			# WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemVoteButtons($file{'file_hash'}, 'all'); #todo refactor to take vote totals directly
		}

		$itemTemplate =~ s/\$itemFlagButton/$itemFlagButton/g;

		WriteLog('GetItemTemplate() return $itemTemplate');

		return $itemTemplate;
	} else {
		WriteLog('GetItemTemplate() return empty string');

		return '';
	}
} #GetItemTemplate

sub GetPageFooter { # returns html for page footer
	WriteLog('GetPageFooter()');

	my $txtFooter = GetTemplate('htmlend.template');

	my $disclaimer = GetString('disclaimer');

	$txtFooter =~ s/\$disclaimer/$disclaimer/g;

	$txtFooter = FillThemeColors($txtFooter);

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/loading')) {
		$txtFooter = InjectJs2($txtFooter, 'after', '</html>', qw(loading_end));
	}

	if (GetConfig('html/back_to_top_button')) {
		# add back to top button to the bottom of the page, right before </body>
		my $backToTopTemplate = GetTemplate('html/back_to_top_button.template');
		$backToTopTemplate = FillThemeColors($backToTopTemplate);
		$txtFooter =~ s/\<\/body>/$backToTopTemplate<\/body>/i;

		$txtFooter = InjectJs2($txtFooter, 'after', '</html>', qw(back_to_top_button));
	}

	if (GetConfig('admin/ssi/enable') && GetConfig('admin/ssi/footer_stats')) {
		#footer stats inserted by ssi
		WriteLog('GetPageFooter: ssi footer conditions met!');
		# footer stats
		$txtFooter = str_replace(
			'</body>',
			GetTemplate('stats_footer_ssi.template') . '</body>',
			$txtFooter
		);
	} # ssi footer stats
	else {
		WriteLog('GetPageFooter: ssi footer conditions NOT met!');
	}


	return $txtFooter;
}

sub GetThemeColor { # returns theme color based on html/theme
	my $colorName = shift;
	chomp $colorName;

	$colorName = 'color/' . $colorName;

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

	#WriteLog('GetThemeAttribute(' . $attributeName . ')');

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

sub FillThemeColors { # $html ; fills in templated theme colors in provided html
	my $html = shift;
	chomp($html);

	my $colorPrimary = GetThemeColor('primary');
	$html =~ s/\$colorPrimary/$colorPrimary/g;

	my $colorSecondary = GetThemeColor('secondary');
	$html =~ s/\$colorSecondary/$colorSecondary/g;

	my $colorBackground = GetThemeColor('background');
	$html =~ s/\$colorBackground/$colorBackground/g;

	my $colorText = GetThemeColor('text');
	$html =~ s/\$colorText/$colorText/g;

	my $colorLink = GetThemeColor('link');
	$html =~ s/\$colorLink/$colorLink/g;

	my $colorVlink = GetThemeColor('vlink');
	$html =~ s/\$colorVlink/$colorVlink/g;

	my $colorInputBackground = GetThemeColor('input_background');
	$html =~ s/\$colorInputBackground/$colorInputBackground/g;

	my $colorInputText = GetThemeColor('input_text');
	$html =~ s/\$colorInputText/$colorInputText/g;

	my $colorRow0Bg = GetThemeColor('row_0');
	$html =~ s/\$colorRow0Bg/$colorRow0Bg/g;

	my $colorRow1Bg = GetThemeColor('row_1');
	$html =~ s/\$colorRow1Bg/$colorRow1Bg/g;

	my $colorTagNegative = GetThemeColor('tag_negative');
	$html =~ s/\$colorTagNegative/$colorTagNegative/g;

	my $colorTagPositive = GetThemeColor('tag_positive');
	$html =~ s/\$colorTagPositive/$colorTagPositive/g;

	my $colorHighlightAlert = GetThemeColor('highlight_alert');
	$html =~ s/\$colorHighlightAlert/$colorHighlightAlert/g;

	my $colorHighlightBeginner = GetThemeColor('highlight_beginner');
	$html =~ s/\$colorHighlightBeginner/$colorHighlightBeginner/g;

	my $colorHighlightAdvanced = GetThemeColor('highlight_advanced');
	$html =~ s/\$colorHighlightAdvanced/$colorHighlightAdvanced/g;

	my $colorWindow = GetThemeColor('window');
	$html =~ s/\$colorWindow/$colorWindow/g;

	return $html;
}

sub WriteMenuList { # writes config/list/menu based on site configuration
	#todo this function is not obvious, overrides obvious list/menu
	my @menu;

	push @menu, 'read';
	push @menu, 'write';

	#upload
	if (GetConfig('admin/php/enable') && GetConfig('admin/image/enable')) {
		# push @menu, 'art';
		push @menu, 'upload';
	}

	#profile
	if (GetConfig('admin/js/enable') || GetConfig('admin/php/enable')) {
		# one of these is required for profile to work
		push @menu, 'profile';
	} else {
		#todo make it disabled or something
		push @menu, 'profile';
	}
	push @menu, 'help';

	###

	my $menuList = join("\n", @menu);

	PutConfig('list/menu', $menuList);
	# PutConfig('list/menu_advanced', $menuList);

	GetConfig('list/menu', 'unmemo');
	# GetConfig('list/menu_advanced', 'uncache');
}

sub GetMenuFromList { # $listName, $templateName = 'menuitem.template'; returns html menu based on referenced list
# $listName is reference to a list in config/list, e.g. config/list/menu
# $separator is what is inserted between menu items

	WriteLog('GetMenuFromList: begin');

	state $wroteMenu;
	if (!$wroteMenu) {
		WriteMenuList();
		$wroteMenu = 1;
	}

	my $listName = shift;
	chomp $listName;
	if (!$listName) {
		WriteLog('GetMenuFromList: no $listName, returning');
		return;
	}

	my $templateName = shift;
	if (!$templateName) {
		$templateName = 'menuitem.template';
	}
	chomp $templateName;

	my $listText = GetConfig('list/' . $listName); #list/menu
	my @menuList = split("\n", $listText);

	my $menuItems = ''; # output html which will be returned

	foreach my $menuItem (@menuList) {
		my $menuItemName = $menuItem;
		if ($menuItemName) {
			my $menuItemUrl	= '/' . $menuItemName . '.html';

			# this avoids creating duplicate urls but currently breaks light mode
			# if ($menuItemName eq 'index') {
			# 	$menuItemUrl = '/';
			# }

			# capitalize caption
			my $menuItemCaption = uc(substr($menuItemName, 0, 1)) . substr($menuItemName, 1);

			if (GetConfig('html/emoji_menu')) {
				my $menuItemEmoji = GetString($menuItemName, 'emoji', 1);
				if ($menuItemEmoji) {
					$menuItemCaption = $menuItemEmoji;
				}
			}

			# add menu item to output
			$menuItems .= GetMenuItem($menuItemUrl, $menuItemCaption, $templateName);
		}
	}

	# return template we've built
	return $menuItems;
}

sub GetPageHeader { # $title, $titleHtml, $pageType ; returns html for page header
	my $title = shift; # page title
	my $titleHtml = shift; # formatted page title
	my $pageType = shift; # type of page

	if (!$pageType) {
		$pageType = 'default';
	}

	WriteLog("GetPageHeader($title, $titleHtml, $pageType)");

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
			$logoText = '';
		}
	}

	my $txtIndex = "";

	my $styleSheet = GetStylesheet();

	my $patternName = trim(GetConfig('header_pattern'));
	my $introText = trim(GetString('page_intro/' . $pageType));
	if (!$introText) {
		$introText = trim(GetString('page_intro/default'));
	}

	my $clock = '';
	if (GetConfig('html/clock')) {
		WriteLog('GetPageHeader: html/clock is enabled');
		my $currentTime = GetClockFormattedTime();
		if (GetConfig('admin/ssi/enable') && GetConfig('admin/ssi/clock_enhance')) {
			# ssi-enhanced clock
			# currently not compatible with javascript clock
			WriteLog('GetPageHeader: ssi is enabled');
			$clock = GetTemplate('widget/clock_ssi.template');
			$clock =~ s/\$currentTime/$currentTime/g;
		}
		else {
			# default clock
			$clock = GetTemplate('widget/clock.template');
			$clock =~ s/\$currentTime/$currentTime/;
		}
		#
#		$currentTime = trim($currentTime);
	} else {
		# the plus sign is to fill in the table cell
		# othrwise netscape will not paint its background color
		# and there will be a hole in the table
		$clock = '+';
	}

	WriteLog('GetPageHeader: $clock = ' . $clock);
	# Get the HTML page template
	my $htmlStart = GetTemplate('htmlstart.template');
	# and substitute $title with the title

	#top menu
						  
	my $identityLink = '<span id="signin"><a href="/profile.html">Profile</a></span> <span class="myid" id=myid></span> ';
#	my $noJsIndicator = '<noscript><a href="/profile.html">Profile</a></noscript>';
	#todo profile link should be color-underlined like other menus

	my $adminKey = GetAdminKey();

	my $topMenuTemplate = GetTemplate('topmenu2.template');
	if (GetConfig('admin/js/enable')) {
		$topMenuTemplate = AddAttributeToTag(
			$topMenuTemplate,
			'a href="/etc.html"',
			'onclick',
			"if (window.SetPrefs) { SetPrefs('show_advanced', 1); }; if (window.ShowAll) { return ShowAll(this); } else { return true; }"
		);
	}

	my $menuItems = GetMenuFromList('menu');
	my $menuItemsAdvanced = GetMenuFromList('menu_advanced');
	#todo move html to template

	my $selfLink = '/access.html';

	$topMenuTemplate =~ s/\$menuItemsAdvanced/$menuItemsAdvanced/g;
	$topMenuTemplate =~ s/\$menuItems/$menuItems/g;
	$topMenuTemplate =~ s/\$selfLink/$selfLink/g;
	$topMenuTemplate =~ s/\$clock/$clock/g;

	$htmlStart =~ s/\$topMenu/$topMenuTemplate/g;

	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$titleHtml/$titleHtml/g;
	$htmlStart =~ s/\$title/$title/g;

	$htmlStart =~ s/\$introText/$introText/g;

	if (GetConfig('logo_enabled')) {
		$htmlStart =~ s/\$logoText/$logoText/g;
	} else {
		$htmlStart =~ s/\$logoText//g;
	}

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/loading')) {
		$htmlStart = InjectJs2($htmlStart, 'after', '<body>', qw(loading_begin));
	}

	$htmlStart = FillThemeColors($htmlStart);

	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetTopItemsPage { # returns page with top items listing
	WriteLog("GetTopItemsPage()");

	my $htmlOutput = ''; # stores the html

	my $title = 'Topics';
	my $titleHtml = 'Topics';

	$htmlOutput = GetPageHeader($title, $titleHtml, 'read'); # <html><head>...</head><body>
	$htmlOutput .= GetTemplate('maincontent.template'); # where "skip to main content" goes

	my @topItems = DBGetTopItems(); # get top items from db

	my $itemCount = scalar(@topItems);

	if ($itemCount) {
	# at least one item returned

		my $itemListingWrapper = GetTemplate('item_listing_wrapper2.template');

		my $itemListings = '';

		my $rowBgColor = ''; # stores current value of alternating row color
		my $colorRow0Bg = GetThemeColor('row_0'); # color 0
		my $colorRow1Bg = GetThemeColor('row_1'); # color 1

		while (@topItems) {
			my $itemTemplate = GetTemplate('item_listing.template');
			# it's ok to do this every time because GetTemplate() already stores it in a static
			# alternative is to store it in another variable above

			#alternate row color
			if ($rowBgColor eq $colorRow0Bg) {
				$rowBgColor = $colorRow1Bg;
			} else {
				$rowBgColor = $colorRow0Bg;
			}

			my $itemRef = shift @topItems; # reference to hash containing item
			my %item = %{$itemRef}; # hash containing item data

			my $itemKey = $item{'file_hash'};
			my $itemScore = $item{'item_score'};
			my $authorKey = $item{'author_key'};

			my $itemLastTouch = DBGetItemLatestAction($itemKey);

			my $itemTitle = $item{'item_title'};
			if (trim($itemTitle) eq '') {
				# if title is empty, use the item's hash
				# $itemTitle = '(' . $itemKey . ')';
				$itemTitle = 'Untitled';
			}
			$itemTitle = HtmlEscape($itemTitle);

			my $itemLink = GetHtmlFilename($itemKey);

			my $authorAvatar;
			if ($authorKey) {
#				$authorAvatar = GetPlainAvatar($authorKey);
				my $authorLink = GetAuthorLink($authorKey, 1);
				if ($authorLink) {
					$authorAvatar = 'by ' . GetAuthorLink($authorKey, 1);
				} else {
					$authorAvatar = '';
				}
			} else {
				$authorAvatar = '';
			}

			$itemLastTouch = GetTimestampWidget($itemLastTouch);

			# populate item template
			$itemTemplate =~ s/\$link/$itemLink/g;
			$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTemplate =~ s/\$itemScore/$itemScore/g;
			$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
			$itemTemplate =~ s/\$itemLastTouch/$itemLastTouch/g;
			$itemTemplate =~ s/\$rowBgColor/$rowBgColor/g;

			# add to main html
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
			'Top Approved Threads',
			'<a class=beginner href="/write.html">New Topic</a><br>', #todo templatify
			$columnHeadings,
			$itemListings,
			$statusText
		);

		$htmlOutput .= $itemListingWrapper;
	} else {
	# no items returned, use 'no items' template
		$htmlOutput .= GetTemplate('item/no_items.template');
	}

	$htmlOutput .= GetPageFooter(); # </body></html>

	if (GetConfig('admin/js/enable')) {
		# add necessary js
		$htmlOutput = InjectJs($htmlOutput, qw(settings voting timestamp profile avatar utils));
		$htmlOutput =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$htmlOutput =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;

		# $htmlOutput = InjectJs($htmlOutput, qw(settings));
	}

	return $htmlOutput;
} #GetTopItemsPage

sub GetStatsTable {
	my $templateName = shift;
	if (!$templateName) {
		$templateName = 'stats.template';
	}

	state $itemsIndexed; $itemsIndexed = $itemsIndexed || DBGetItemCount();
	my $authorCount = DBGetAuthorCount();

	my $adminId = GetAdminKey();
	my $adminUsername = GetAlias(GetAdminKey());
	my $adminLink = GetAuthorLink($adminId);

	my $serverId = GetServerKey();
	my $serverLink = GetAuthorLink($serverId);

	my $versionFull = GetMyVersion();
	my $versionShort = substr($versionFull, 0, 8);

	my $lastUpdateTime = GetConfig('system/last_update_time');
	$lastUpdateTime = GetTimestampWidget($lastUpdateTime);

	my $lastBuildTime = GetConfig('admin/build_end');
	if (!defined($lastBuildTime) || !$lastBuildTime) {
		$lastBuildTime = 0;
	}

	###

	my $statsTable = GetTemplate($templateName);

	if ($adminId) {
		if ($adminUsername eq 'Operator' && $templateName eq 'stats-horizontal.template') {
			# harmless hack
			$statsTable =~ s/\<span class=beginner>Operator: <\/span>\$admin/$adminLink/;
		} else {
			$statsTable =~ s/\$admin/$adminLink/;
		}
	} else {
		$statsTable =~ s/\$admin/(Not defined)/;
	}

	if ($serverId) {
		$statsTable =~ s/\$server/$serverLink/;
	} else {
		$statsTable =~ s/\$server/(Not defined)/;
	}

	if (!defined($lastUpdateTime) || !$lastUpdateTime) {
		$lastUpdateTime = 0;
	}

	$statsTable =~ s/\$lastUpdateTime/$lastUpdateTime/;

	# count total number of files
	my $filesTotal = 0;

	my $filesTxt = GetCache('count_txt') || trim(`find $TXTDIR -name \\\*.txt | wc -l`);
	PutCache('count_txt', $filesTxt);
	$filesTotal += $filesTxt;

	if (GetConfig('admin/image/enable')) {
		my $filesImage =  GetCache('count_image') || trim(`find $IMAGEDIR -name \\\*.png -o -name \\\*.jpg -o -name \\\*.gif -o -name \\\*.bmp -o -name \\\*.jfif -o -name \\\*.webp -o -name \\\*.svg | wc -l`);
		PutCache('count_image', $filesImage);
		$filesTotal += $filesImage;
	}

	my $chainLogLength = 0;
	if (GetConfig('admin/logging/write_chain_log')) {
		$chainLogLength = `wc -l html/chain.log`;
	}

	#todo optimize
	#todo config/admin/upload/allow_files

	$lastBuildTime = GetTimestampWidget($lastBuildTime);
	$statsTable =~ s/\$lastBuildTime/$lastBuildTime/;

	$statsTable =~ s/\$versionFull/$versionFull/;
	$statsTable =~ s/\$versionShort/$versionShort/;
	$statsTable =~ s/\$itemsIndexed/$itemsIndexed/;
	$statsTable =~ s/\$authorCount/$authorCount/;
	$statsTable =~ s/\$filesTotal/$filesTotal/;
	$statsTable =~ s/\$chainLogLength/$chainLogLength/;

	return $statsTable;
}

sub GetStatsPage { # returns html for stats page
	my $statsPage;

	$statsPage = GetPageHeader('Stats', 'Stats', 'stats');

	my $statsTable = GetStatsTable();
	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	$statsPage = InjectJs($statsPage, qw(settings avatar timestamp pingback profile));

	return $statsPage;
}

sub EnableJsDebug { # $scriptTemplate ; enables javascript debug mode
# works by uncommenting any lines which begin with //alert('DEBUG:
	state $debugType;
	if (!$debugType) {
		$debugType = GetConfig('admin/js/debug');
		chomp $debugType;
		$debugType = trim($debugType);
	}

	my $scriptTemplate = shift;

	WriteLog('EnableJsDebug: $debugType = ' . $debugType);

	if ($debugType eq 'console.log') {
		$scriptTemplate =~ s/\/\/alert\('DEBUG:/console.log('DEBUG:/gi;
	} else {
		$scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/gi;
	}

	return $scriptTemplate;
}

sub InjectJs { # $html, @scriptNames ; inject js template(s) before </body> ;
	my $html = shift;     # html we're going to inject into

	if (!GetConfig('admin/js/enable')) {
		# if js is disabled globally, abort

		WriteLog("InjectJs: WARNING: InjectJs() called, but admin/js/enable is false");

		return $html;
	}

	my @scriptNames = @_; # array of names of script templates (minus the .js suffix)

	my $scriptsText = '';  # will contain all the js we want to inject
	my $scriptsComma = ''; # separator between scripts, will be set to \n\n after first script

	my %scriptsDone = ();  # hash to keep track of scripts we've already injected, to avoid duplicates

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/fresh')) {
		# if fresh_js is enabled, automatically add it
		#todo move this upwards, shouldn't be decided here
		push @scriptNames, 'fresh';
	}

	if (GetConfig('admin/force_profile')) {
		# if force_profile is enabled, automatically add it
		#todo move this upwards, shouldn't be decided here

		push @scriptNames, 'force_profile';
	}

	if (GetConfig('admin/js/dragging')) {
		push @scriptNames, 'dragging'; 
	}

	#output list of all the scripts we're about to include
	my $scriptNamesList = join(' ', @scriptNames);

	# loop through all the scripts
	foreach my $script (@scriptNames) {
		if ($script eq 'clock') {
			my $clockFormat = GetConfig('html/clock_format');
			if ($clockFormat eq 'epoch' || $clockFormat eq 'union' || $clockFormat eq '24hour') {
				$script = 'clock/' . $clockFormat;
			}
		}

		if ($script eq 'translit') {
			if (!GetConfig('admin/js/translit')) {
				WriteLog('InjectJs: warning: translit requested, but admin/js/translit is off');
				next;
			}
		}

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

		my $scriptTemplate = GetTemplate("js/$script.js");

		if (!$scriptTemplate) {
			WriteLog("InjectJs: WARNING: Missing script contents for $script");
		}

		if ($script eq 'voting') {
			# for voting.js we need to fill in some theme colors
			my $colorSuccessVoteUnsigned = GetThemeColor('success_vote_unsigned');
			my $colorSuccessVoteSigned = GetThemeColor('success_vote_signed');

			$scriptTemplate =~ s/\$colorSuccessVoteUnsigned/$colorSuccessVoteUnsigned/g;
			$scriptTemplate =~ s/\$colorSuccessVoteSigned/$colorSuccessVoteSigned/g;
		}

		if ($script eq 'puzzle') {
			# for voting.js we need to fill in some theme colors
			my $puzzlePrefix = GetConfig('puzzle/prefix');;
			my $puzzleCycleLimit = GetConfig('puzzle/cycle_limit');

			$scriptTemplate =~ s/var lookingFor = '1337';/var lookingFor = '$puzzlePrefix';/g;
			$scriptTemplate =~ s/var cycleLimit = 1000000;/var cycleLimit = $puzzleCycleLimit;/g;
		}

		if ($script eq 'profile') {
			# for profile.js we need to fill in current admin id
			my $currentAdminId = GetAdminKey() || '-';

			$scriptTemplate =~ s/\$currentAdminId/$currentAdminId/g;
		}

		#if ($script eq 'settings' || $script eq 'loading_begin') {
		if (
				$script eq 'settings' ||
				$script eq 'timestamp'
		) {
			# for settings.js we also need to fill in some theme colors
			my $colorHighlightAlert = GetThemeColor('highlight_alert');
			my $colorHighlightAdvanced = GetThemeColor('highlight_advanced');
			my $colorHighlightBeginner = GetThemeColor('highlight_beginner');

			$scriptTemplate =~ s/\$colorHighlightAlert/$colorHighlightAlert/g;
			$scriptTemplate =~ s/\$colorHighlightAdvanced/$colorHighlightAdvanced/g;
			$scriptTemplate =~ s/\$colorHighlightBeginner/$colorHighlightBeginner/g;

			my $colorRecentTimestamp = GetThemeColor('recent_timestamp');
			if ($colorRecentTimestamp) {
				$scriptTemplate =~ s/\$colorRecentTimestamp/$colorRecentTimestamp/g;
			} else {
				$colorRecentTimestamp = '#808000';
				$scriptTemplate =~ s/\$colorRecentTimestamp/$colorRecentTimestamp/g;
			}
		}

		if (index($scriptTemplate, '>') > -1) {
			# warning here if script content contains > character, which is incompatible with mosaic's html comment syntax
			WriteLog('InjectJs(): warning: Inject script "' . $script . '" contains > character');
		}

		if (GetConfig('admin/js/debug')) {
			#uncomment all javascript debug alert statements
			#and replace them with confirm()'s which stop on no/cancel
			#
			# $scriptTemplate =~ s/\/\/alert\('DEBUG:/alert('DEBUG:/g;
			# $scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=confirm('DEBUG:/g;

			#$scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/g;
			$scriptTemplate = EnableJsDebug($scriptTemplate);
		}

		# add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	# get the wrapper, i.e. <script>$javascript</script>
	my $scriptInject = GetTemplate('html/utils/scriptinject.template');
	# fill in the wrapper with our scripts from above
	$scriptInject =~ s/\$javascript/$scriptsText/g; #todo why is this /g ??

	$scriptInject = '<!-- InjectJs: ' . $scriptNamesList . ' -->' . "\n\n" . $scriptInject;

	if (index($html, '</body>') > -1) {
		# replace it into html, right before the closing </body> tag
		$html =~ s/<\/body>/$scriptInject<\/body>/;
	} else {
		# if there was no </body> tag, just append at the end
		$html .= "\n\n" . $scriptInject;
		WriteLog('InjectJs(): warning: $html does not contain </body>');
	}

	return $html;
}

sub InjectJs2 { # $html, $injectMode, $htmlTag, @scriptNames, ; inject js template(s) before </body> ;
# todo, once i figure out how to pass an array and/or need this in perl:
# to copy php version
# $injectMode: before, after, append
# $htmlTag: e.g. </body>, only used with before/after
# if $htmlTag is not found, does fall back to append
	my $html = shift;     # html we're going to inject into

	if (!GetConfig('admin/js/enable')) {
		return $html;
	}

	my $injectMode = shift;
	my $htmlTag = shift;

	my @scriptNames = @_; # array of names of script templates (minus the .js suffix)

	my $scriptsText = '';  # will contain all the js we want to inject
	my $scriptsComma = ''; # separator between scripts, will be set to \n\n after first script

	my %scriptsDone = ();  # hash to keep track of scripts we've already injected, to avoid duplicates

	if (GetConfig('html/clock')) {
		# if clock is enabled, automatically add its js
		push @scriptNames, 'clock';
	}

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/fresh')) {
		# if clock is enabled, automatically add it
		push @scriptNames, 'fresh';
	}

	if (GetConfig('admin/force_profile')) {
		# if force_profile is enabled, automatically add it
		push @scriptNames, 'force_profile';
	}

	#output list of all the scripts we're about to include
	my $scriptNamesList = join(' ', @scriptNames);

	# loop through all the scripts
	foreach my $script (@scriptNames) {
		if ($script eq 'clock') {
			my $clockFormat = GetConfig('html/clock_format');
			if ($clockFormat eq 'epoch' || $clockFormat eq 'union' || $clockFormat eq '24hour') {
				$script = 'clock/' . $clockFormat;
			}
		}

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

		my $scriptTemplate = GetTemplate("js/$script.js");

		if (!$scriptTemplate) {
			WriteLog("InjectJs: WARNING: Missing script contents for $script");
		}

		if ($script eq 'voting') {
			# for voting.js we need to fill in some theme colors
			my $colorSuccessVoteUnsigned = GetThemeColor('success_vote_unsigned');
			my $colorSuccessVoteSigned = GetThemeColor('success_vote_signed');

			$scriptTemplate =~ s/\$colorSuccessVoteUnsigned/$colorSuccessVoteUnsigned/g;
			$scriptTemplate =~ s/\$colorSuccessVoteSigned/$colorSuccessVoteSigned/g;
		}

		if ($script eq 'settings') {
			# for settings.js we also need to fill in some theme colors
			my $colorHighlightAdvanced = GetThemeColor('highlight_advanced');
			my $colorHighlightBeginner = GetThemeColor('highlight_beginner');

			$scriptTemplate =~ s/\$colorHighlightAdvanced/$colorHighlightAdvanced/g;
			$scriptTemplate =~ s/\$colorHighlightBeginner/$colorHighlightBeginner/g;
		}

		if (index($scriptTemplate, '>') > -1) {
			# warning here if script content contains > character, which is incompatible with mosaic's html comment syntax
			WriteLog('InjectJs(): warning: Inject script "' . $script . '" contains > character');
		}

		if (GetConfig('admin/js/debug')) {
			#uncomment all javascript debug alert statements
			#and replace them with confirm()'s which stop on no/cancel
			#
			# $scriptTemplate =~ s/\/\/alert\('DEBUG:/alert('DEBUG:/g;
			# $scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=confirm('DEBUG:/g;

			#$scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/g;
			$scriptTemplate = EnableJsDebug($scriptTemplate);

		}

		# add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	# get the wrapper, i.e. <script>$javascript</script>
	my $scriptInject = GetTemplate('html/utils/scriptinject.template');
	# fill in the wrapper with our scripts from above
	$scriptInject =~ s/\$javascript/$scriptsText/g; #todo why is this /g ??

	$scriptInject = '<!-- InjectJs2: ' . $scriptNamesList . ' -->' . "\n\n" . $scriptInject;

	if ($injectMode ne 'append' && index($html, $htmlTag) > -1) {
		# replace it into html, right before the closing </body> tag
		if ($injectMode eq 'before') {
			#$html = str_replace($htmlTag, $scriptInject . $htmlTag, $html);
			$html =~ s/$htmlTag/$scriptInject$htmlTag/;
		} else {
			#$html = str_replace($htmlTag, $htmlTag . $scriptInject, $html);
			$html =~ s/$htmlTag/$htmlTag$scriptInject/;
		}
	} else {
		# if there was no </body> tag, just append at the end
		if ($injectMode ne 'append') {
			WriteLog('InjectJs: warning: $html does not contain $htmlTag, falling back to append mode');
		}
		$html .= "\n" . $scriptInject;
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
		my $authorLastSeen = $author{'last_seen'};
		my $authorItemCount = $author{'item_count'};
		my $authorAvatar = GetHtmlAvatar($authorKey) || $authorKey;

		my $authorVoteButtons = GetItemVoteButtons($authorKey, 'author');

		if (!$authorVoteButtons) {
			$authorVoteButtons = '-';
		}

		my $authorLink = GetAuthorLink($authorKey) || '(blank)';

#		my $authorFriendKey = $authorFriend->{'author_key'};

		my $authorItemTemplate = GetTemplate('author_listing.template');
		#todo don't need to do this every time
#
		if ($authorLastSeen) {
			$authorLastSeen = GetTimestampWidget($authorLastSeen);
		}
		#$authorLastSeen = GetSecondsHtml(GetTime() - $authorLastSeen) . ' ago';

		$authorItemTemplate =~ s/\$authorLink/$authorLink/g; #todo $authorLink can sometimes be uninitialized here, #bug
		$authorItemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
		$authorItemTemplate =~ s/\$authorScore/$authorScore/g;
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

	$txtIndex = InjectJs($txtIndex, qw(settings avatar timestamp profile voting));

	return $txtIndex;
} # GetScoreboardPage()

sub GetAuthorInfoBox {
	my $authorKey = shift;
	chomp $authorKey;

	if (!$authorKey) {
		return '';
	}

	my $authorInfoTemplate = GetTemplate('author_info.template');

	my $authorAliasHtml = GetAlias($authorKey);
	my $authorAvatarHtml = GetAvatar($authorKey);
	my $authorImportance = 1;
	my $authorScore = DBGetAuthorScore($authorKey) || 0;
	my $itemCount = DBGetAuthorItemCount($authorKey);
	my $authorDescription = '';
	my $authorLastSeen = DBGetAuthorLastSeen($authorKey) || 0;

	my $publicKeyHash = DBGetAuthorPublicKeyHash($authorKey);
	my $publicKeyHashHtml = '';
	if (defined($publicKeyHash) && IsSha1($publicKeyHash)) {
		$publicKeyHashHtml = GetItemHtmlLink($publicKeyHash);
	} else {
		$publicKeyHashHtml = '*';
	}
	my $authorMessageLink = GetItemHtmlLink($publicKeyHash, 'Contact Them', '#reply');

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

		my $descText = '<b>Admin.</b>';
		my $adminContainer = GetTemplate('item/container/admin.template');
		my $colorAdmin = GetThemeColor('admin') || '#c00000';
		$adminContainer =~ s/\$colorAdmin/$colorAdmin/g;
		$adminContainer =~ s/\$message/$descText/g;

		$authorDescription = $adminContainer;
	}

	if ($authorDescription) {
		$authorDescription .= '<br>';
	}
	$authorDescription .= GetItemVotesSummary($publicKeyHash);

	my $profileVoteButtons = GetItemVoteButtons($publicKeyHash, 'pubkey');

	$authorLastSeen = GetTimestampWidget($authorLastSeen);

	if (!$authorDescription) {
		$authorDescription = '*';
	}

	if (!$publicKeyHash) {
		$publicKeyHash = '*';
	}

	if (IsAdmin($authorKey)) {
		$authorInfoTemplate =~ s/<p>This page about author listed below.<\/p>/<p>Note: This user is system operator.<\/p>/;
	}
	$authorInfoTemplate =~ s/\$avatar/$authorAvatarHtml/;
	$authorInfoTemplate =~ s/\$authorName/$authorAliasHtml/;
	$authorInfoTemplate =~ s/\$fingerprint/$authorKey/g;
	$authorInfoTemplate =~ s/\$importance/$authorImportance/;
	$authorInfoTemplate =~ s/\$authorScore/$authorScore/;
	$authorInfoTemplate =~ s/\$itemCount/$itemCount/;
	$authorInfoTemplate =~ s/\$authorDescription/$authorDescription/;
	$authorInfoTemplate =~ s/\$authorLastSeen/$authorLastSeen/g;
	$authorInfoTemplate =~ s/\$profileVoteButtons/$profileVoteButtons/g;
	if ($publicKeyHashHtml) {
		$authorInfoTemplate =~ s/\$publicKeyHash/$publicKeyHashHtml/g;
	} else {
		$authorInfoTemplate =~ s/\$publicKeyHash/*/g;
	}
	if ($authorMessageLink) {
		$authorInfoTemplate =~ s/\$authorMessageLink/$authorMessageLink/g;
	} else {
		$authorInfoTemplate =~ s/\$authorMessageLink/*/g;
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
		$authorFriends = '*';
	}

	# wrap list of friends in wrapper
	my $authorFriendsWrapper = GetTemplate('author/author_friends.template');
	$authorFriendsWrapper =~ s/\$authorFriendsList/$authorFriends/;

	# insert list of friends into authorinfo template
	$authorInfoTemplate =~ s/\$authorFriends/$authorFriendsWrapper/;

	return $authorInfoTemplate;
} # GetAuthorInfoBox()

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
		#$pageType can be 'author', 'tag'

		if ($pageType eq 'author') {
			# AUTHOR PAGE ##############################################################
			
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

		if ($pageType eq 'tag') { #/tag/
			# TAG PAGE ##############################################################
						
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

	# GENERATE PAGE ######

	my $txtIndex = ""; # contains html output

	# this will hold the title of the page
	if (!$title) {
		$title = GetConfig('home_title');
	}

	chomp $title;
	$title = HtmlEscape($title);

	my $htmlStart = GetPageHeader($title, $titleHtml, 'read_' . $pageType);

	if ($pageType eq 'tag') {
		# fill in tag placeholder at top of page
		# this is where it says, "this page shows all items with tag $tagSelected

		$htmlStart =~ s/\$tagSelected/$pageParam/;
		# $pageParam is the chosen tag for this page
	}

	$txtIndex .= $htmlStart;

	#todo
	#<span class="replies">last reply at [unixtime]</span>
	#javascript foreach span class=replies { get time after "last reply at" and compare to "last visited" cookie

	my $needUploadJs = 0;
	if ($pageType eq 'tag') {
		# add tag buttons with selected tag emphasized
		$txtIndex .= GetTagLinks($pageParam);

		if ($pageParam eq 'image') {
			$txtIndex .= GetUploadWindow();
			$needUploadJs = 1;
		}
	}

	$txtIndex .= GetTemplate('maincontent.template');

	if ($pageType eq 'author') {
		# author info box
		$txtIndex .= GetAuthorInfoBox($authorKey);
	}

	my $itemComma = '';

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		WriteLog("DBAddItemPage (1)");
		DBAddItemPage($row->{'file_hash'}, $pageType, $pageParam);

		if ($file && -e $file) {
			my $itemHash = $row->{'file_hash'};

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
			my $messageCacheName = "./cache/" . GetMyCacheVersion() . "/message/$itemHash";
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

			my $itemTemplate = '';
			if ($message) {
#				$row->{'show_quick_vote'} = 1;
				$row->{'trim_long_text'} = 1;

				WriteLog('GetReadPage: GetItemTemplate($row)');

				$itemTemplate = GetItemTemplate($row); # GetReadPage()
			} else {
				$itemTemplate = '<p>Problem decoding message</p>';
				WriteLog('Something happened and there is no $message where I expected it... Oh well, moving on.');
			}

			if ($itemComma eq '') {
				$itemComma = '<br><hr size=7>';
			} else {
				$itemTemplate = $itemComma . $itemTemplate;
			}

			$txtIndex .= $itemTemplate;
		}
	}

	# Close html
	$txtIndex .= GetPageFooter();

	if ($pageType eq 'author') {
		# for author page, add itsyou.js, which will tell the user if the profile is theirs
		$txtIndex = InjectJs($txtIndex, qw(itsyou settings timestamp voting utils profile));
	} else {
		if ($needUploadJs) {
			$txtIndex = InjectJs($txtIndex, qw(settings voting timestamp utils profile upload));
		} else {
			$txtIndex = InjectJs($txtIndex, qw(settings voting timestamp utils profile));
		}
	}

	if (GetConfig('admin/js/enable')) {
		$txtIndex =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$txtIndex =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}

	return $txtIndex;
} # GetReadPage()

sub GetIndexPage { # returns html for an index page, given an array of hash-refs containing item information
	# Called from WriteIndexPages() and generate.pl
	# Should probably be replaced with GetReadPage()

	my $filesArrayReference = shift; # array of hash refs which contains items
	my @files = @$filesArrayReference; # de-reference
	my $currentPageNumber = shift; # for pagination links, determines which one is bolded

	my $html = ""; # html output

	my $pageTitle = '';
	if ($currentPageNumber) {
		$pageTitle = 'Index, page ' . $currentPageNumber;
	} else {
		$pageTitle = 'Index';
	}

	#header
	$html .= GetPageHeader($pageTitle, $pageTitle, 'item_list');

	# no pagination links at the top now that we have tag buttons
	#
	# if (defined($currentPageNumber)) {
	# 	#pagination links
	# 	$html .= GetPageLinks($currentPageNumber);
	# }

	# put tag selector at top of page
	$html .= GetTagLinks();

	$html .= '<p>';
	$html .= GetTemplate('maincontent.template');

	my $itemList = ''; # the "filling" part of the page, with all the items templated
	my $itemComma = ''; # separator between items

	foreach my $row (@files) { # loop through each file
		my $file = $row->{'file_path'};

		if ($file && -e $file) { # file exists
			my $itemHash = $row->{'file_hash'};

			DBAddItemPage($itemHash, 'index', $currentPageNumber);

			my $gpgKey = $row->{'author_key'};
			my $isSigned;
			if ($gpgKey) {
				$isSigned = 1;
			} else {
				$isSigned = 0;
			}
			my $alias = '';
			my $isAdmin = 0;

			my $message;
			if (CacheExists("message/$itemHash")) {
				$message = GetCache("message/$itemHash");
			} else {
				$message = GetFile($file);
			}

			$row->{'vote_buttons'} = 1;
			$row->{'show_vote_summary'} = 1;
			$row->{'display_full_hash'} = 0;
			$row->{'trim_long_text'} = 0;

			my $itemTemplate;
			$itemTemplate = GetItemTemplate($row); # GetIndexPage()

			$itemList = $itemList . $itemComma . $itemTemplate;

			if ($itemComma eq '') {
				$itemComma = '<hr><br>';
				# $itemComma = '<p>';
			}
		}
	}

	$html .= $itemList;
	$html .= '<p>';

	if (defined($currentPageNumber)) {
		$html .= GetPageLinks($currentPageNumber);
	}

	# Close html
	$html .= GetPageFooter();
	$html = InjectJs($html, qw(settings avatar voting profile timestamp));

	return $html;
} # GetIndexPage()

sub GetMenuItem { # $address, $caption; returns html snippet for a menu item (used for both top and footer menus)
	my $address = shift;
	my $caption = shift;

	# if (!-e "$HTMLDIR/$address") {
	#	#don't make a menu item if file doesn't exist
	# 	return '';
	# }

	my $templateName = shift;
	if (!$templateName) {
		$templateName = 'menuitem.template';
	}
	chomp $templateName;

	my $menuItem = '';
	$menuItem = GetTemplate($templateName);

	# my $color = GetThemeColor('link');
	# my $colorSourceHash = md5_hex($caption);
	# my $menuColorMode = GetThemeAttribute('menu_color_mode') ? 1 : 0;
	# for (my $colorSelectorI = 0; $colorSelectorI < 6; $colorSelectorI++) {
	# 	my $char = substr($colorSourceHash, $colorSelectorI, 1);
	# 	if (!$menuColorMode) {
	# 		if ($char eq 'd' || $char eq 'e' || $char eq 'f') {
	# 			$char = 'c';
	# 		}
	# 	}
	# 	if ($menuColorMode) {
	# 		if ($char eq '0' || $char eq '1' || $char eq '2') {
	# 			$char = '3';
	# 		}
	# 	}
	# 	$color .= $char;
	# }

	# my $firstLetter = substr($caption, 0, 1);
	# $caption = substr($caption, 1);

	#my $color = substr(md5_hex($caption), 0, 6);

	$menuItem =~ s/\$address/$address/g;
	$menuItem =~ s/\$caption/$caption/g;
	# $menuItem =~ s/\$color/$color/g;
	# $menuItem =~ s/\$firstLetter/$firstLetter/g;

	return $menuItem;
} # GetMenuItem()

sub WriteIndexPages { # writes the queue pages (index0-n.html)
	my $pageLimit = GetConfig('page_limit');
	if (!$pageLimit) {
		$pageLimit = 250;
	}
	#my $pageThreshold = 5; #todo

	#my $whereClause = "','||tags_list||',' LIKE '%,approve,%'";

	#my $itemCount = DBGetItemCount($whereClause);
	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	if (GetConfig('admin/html/index_pages_limit')) {
		if ($itemCount > GetConfig('admin/html/index_pages_limit')) {
			$itemCount = GetConfig('admin/html/index_pages_limit');
		}
	}

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
			my $percent = (($i + 1) / $lastPage) * 100;
			WriteMessage("*** WriteIndexPages: " . ($i+1) . "/$lastPage ($percent %) ");

			my %queryParams;
			my $offset = $i * $pageLimit;

			# $queryParams{'where_clause'} = "WHERE item_type = 'text' AND IFNULL(parent_count, 0) = 0";

			# this code prevents the last page from being largely empty
			# it moves the offset back so that the last page is the same
			# number of items as the others.
			# the downside is that when the page links are item numbers
			# the link for last page may not match the items on the page
			#
			# if ($overlapPage && $lastPage > $overlapPage && $i > $overlapPage) {
			# 	$offset = $offset - ($itemCount % $pageLimit);
			# }

			$queryParams{'limit_clause'} = "LIMIT $pageLimit OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
			# if ($whereClause) {
			# 	$queryParams{'where_clause'} = $whereClause;
			# }

			my @ft = DBGetItemList(\%queryParams);

			my $indexPage;
			if ($lastPage > 1) {
				$indexPage = GetIndexPage(\@ft, $i);
			} else {
				$indexPage = GetIndexPage(\@ft);
			}

			PutHtmlFile("index$i.html", $indexPage);
			if ($i == 0) {
				PutHtmlFile("compost.html", $indexPage);
			}
		}
	} else {
		my $indexPage = GetPageHeader(GetConfig('home_title'), GetConfig('home_title'), 'home_empty');

#		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';

		#todo this should be in template
		my $infoMessage = '<p>It looks like there is nothing to display here.</p><p><a href="/write.html">Would you like to write something?</a></p>';

		$indexPage .= GetWindowTemplate('No Items', '', '', $infoMessage, 'Ready');

		$indexPage .= GetPageFooter();

		$indexPage = InjectJs($indexPage, qw(profile settings avatar));

		PutHtmlFile("index0.html", $indexPage);
		PutHtmlFile("compost.html", $indexPage);
	}
}

sub GetLighttpdConfig {
	my $conf = GetTemplate('lighttpd/lighttpd.conf.template');
	print $conf;
	
#	my $pwd = `pwd`;
	my $pwd = cwd();
	chomp $pwd; # get rid of tailing newline
	
	my $docRoot = $pwd . '/' . 'html' . '/';
	my $serverPort = GetConfig('admin/lighttpd/port') || 2784;
	my $errorFilePrefix = $docRoot . 'error/error-';
	
	$conf =~ s/\$serverDocumentRoot/$docRoot/;
	$conf =~ s/\$serverPort/$serverPort/;
	$conf =~ s/\$errorFilePrefix/$errorFilePrefix/;

	if (GetConfig('admin/php/enable')) {
		my $phpConf = GetTemplate('lighttpd/lighttpd_php.conf.template');

		my $phpCgiPath = `which php-cgi`;
        chomp($phpCgiPath);

		if ($phpCgiPath) {
    		$phpConf =~ s/\/bin\/php-cgi/$phpCgiPath/g;
        } else {
            WriteLog('GetLighttpdConfig: warning: php enabled with lighttpd, but php-cgi missing');
        }
		
		WriteLog('$phpConf beg =====');
		WriteLog($phpConf);
		WriteLog('$phpConf end =====');
		
		$conf .= "\n" . $phpConf;

		my $rewriteSetting = GetConfig('admin/php/rewrite');
		if ($rewriteSetting) {
			if ($rewriteSetting eq 'all') {
				my $phpRewriteAllConf = GetTemplate('lighttpd/lighttpd_php_rewrite_all.conf.template');
				$conf .= "\n" . $phpRewriteAllConf;
			}
			if ($rewriteSetting eq 'query') {
				my $phpRewriteQueryConf = GetTemplate('lighttpd/lighttpd_php_rewrite_query.conf.template');
				$conf .= "\n" . $phpRewriteQueryConf;
			}
		}
	}
	
	if (GetConfig('admin/ssi/enable')) {
		my $ssiConf = GetTemplate('lighttpd/lighttpd_ssi.conf.template');

		WriteLog('$ssiConf beg =====');
		WriteLog($ssiConf);
		WriteLog('$ssiConf end =====');

		$conf .= "\n" . $ssiConf;
	}
	if (GetConfig('admin/http_auth/enable')) {
		my $basicAuthConf = GetTemplate('lighttpd/lighttpd_basic_auth.conf.template');

		WriteLog('$basicAuthConf beg =====');
		WriteLog($basicAuthConf);
		WriteLog('$basicAuthConf end =====');

		$conf .= "\n" . $basicAuthConf;
	}
	
	return $conf;
} # GetLighttpdConfig()

sub MakeJsTestPages {
	my $jsTestPage = GetTemplate('js/test.js');
	PutHtmlFile("jstest.html", $jsTestPage);

	my $jsTest2Page = GetTemplate('js/test2.js');
	#	$jsTest2Page = InjectJs($jsTest2Page, qw(sha512.js));
	PutHtmlFile("jstest2.html", $jsTest2Page);

	my $jsTest3Page = GetTemplate('js/test3.js');
	PutHtmlFile("jstest3.html", $jsTest3Page);

	my $jsTest4Page = GetTemplate('js/test4.js');
	PutHtmlFile("jstest4.html", $jsTest4Page);


	my $jsTest1 = GetTemplate('test/jstest1/jstest1.template');
	$jsTest1 = InjectJs($jsTest1, qw(jstest1));
	PutHtmlFile("jstest1.html", $jsTest1);

	my $jsTest2 = GetTemplate('test/jstest1/jstest2.template');
	$jsTest2 = InjectJs($jsTest2, qw(jstest2));
	PutHtmlFile("jstest2.html", $jsTest2);
}

sub MakeSimplePage { # given page name, makes page
	my $pageName = shift;
	if (!$pageName) {
		return;
	}
	chomp $pageName;
	if (!$pageName =~ m/^[a-z]+$/) {
		return;
	}

	my $html = '';

	$html .= GetPageHeader(ucfirst($pageName), ucfirst($pageName), $pageName);
	$html .= GetTemplate('maincontent.template');

	my $pageContent = GetTemplate("page/$pageName.template");
	my $contentWindow = GetWindowTemplate(
		ucfirst($pageName),
		'', #menubar
		'', #columns
		$pageContent,
		'' # statusbar
	);
	$html .= $contentWindow;
	$html .= GetPageFooter();
	$html = InjectJs($html, qw(avatar settings profile utils));

	if (GetConfig('admin/js/enable')) {
		$html =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$html =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}

	PutHtmlFile("$pageName.html", $html);

	if ($pageName eq 'welcome') {
		PutHtmlFile("index.html", $html);
	}
}


sub MakeSummaryPages { # generates and writes all "summary" and "static" pages StaticPages
# write, add event, stats, profile management, preferences, post ok, action/vote, action/event
# js files, 
	WriteLog('MakeSummaryPages() BEGIN');

	WriteIndexPages(); #todo factor this out.

	PutHtmlFile("test.html", GetTemplate('test.template'));
	PutHtmlFile("keyboard.html", GetTemplate('keyboard/keyboard.template'));
	PutHtmlFile("keyboard_netscape.html", GetTemplate('keyboard/keyboard_netscape.template'));
	PutHtmlFile("keyboard_android.html", GetTemplate('keyboard/keyboard_a.template'));

	PutHtmlFile("frame.html", GetTemplate('keyboard/keyboard_frame.template'));
	PutHtmlFile("frame2.html", GetTemplate('keyboard/keyboard_frame2.template'));
	PutHtmlFile("frame3.html", GetTemplate('keyboard/keyboard_frame3.template'));

	#PutHtmlFile("cache.manifest", GetTemplate('js/cache.manifest.template'));

	MakeJsTestPages();

	# Submit page
	my $submitPage = GetWritePage();
	PutHtmlFile("write.html", $submitPage);

	if (GetConfig('admin/php/enable')) {
		# create write_post.html for longer messages if admin/php/enable
		
		$submitPage =~ s/method=get/method=post/g;
		if (index(lc($submitPage), 'method=post') == -1) {
			$submitPage =~ s/\<form /<form method=post /g;
		}
		if (index(lc($submitPage), 'method=post') == -1) {
			$submitPage =~ s/\<form/<form method=post /g;
		}
		$submitPage =~ s/please click here/you're in the right place/g;
		PutHtmlFile("write_post.html", $submitPage);
	}

	# Upload page
	my $uploadPage = GetUploadPage();
	PutHtmlFile("upload.html", $uploadPage);

	# Search page
	my $searchPage = GetSearchPage();
	PutHtmlFile("search.html", $searchPage);

	# Add Event page
	my $eventAddPage = GetEventAddPage();
	PutHtmlFile("event.html", $eventAddPage);

	# Add Event page
	my $eventsPage = GetEventsPage();
	PutHtmlFile("events.html", $eventsPage);

	# Add Event page
	my $authorsPage = GetScoreboardPage();
	PutHtmlFile("authors.html", $authorsPage);

	my $topItemsPage = GetTopItemsPage();
	PutHtmlFile('read.html', $topItemsPage);

	my $tagsPage = GetTagsPage('Tags', 'Tags', '');
	PutHtmlFile("tags.html", $tagsPage);

	PutStatsPages();
	#
	# { # clock test page
	# 	my $clockTest = '<form name=frmTopMenu>' . GetTemplate('widget/clock.template') . '</form>';
	# 	my $clockTestPage = '<html><body>';
	# 	$clockTestPage .= $clockTest;
	# 	$clockTestPage .= '</body></html>';
	# 	$clockTestPage = InjectJs($clockTestPage, qw(clock));
	# 	PutHtmlFile("clock.html", $clockTestPage);
	# }

	{
		my $fourOhFourPage = GetDialogPage('404'); #GetTemplate('404.template');
		if (GetConfig('html/clock')) {
			$fourOhFourPage = InjectJs($fourOhFourPage, qw(clock fresh)); #todo this causes duplicate clock script
		}
		PutHtmlFile("404.html", $fourOhFourPage);
		PutHtmlFile("error/error-404.html", $fourOhFourPage);
	}

	{
		my $accessDeniedPage = GetDialogPage('401'); #GetTemplate('401.template');
		PutHtmlFile("error/error-401.html", $accessDeniedPage);
	}



	# Profile page
	my $profilePage = GetProfilePage();
	PutHtmlFile("profile.html", $profilePage);

	# Settings page
	my $settingsPage = GetSettingsPage();
	PutHtmlFile("settings.html", $settingsPage);

	# Access page
	my $accessPage = GetAccessPage();
	PutHtmlFile("access.html", $accessPage);

	# More page
	my $etcPage = GetEtcPage();
	PutHtmlFile("etc.html", $etcPage);

	# Target page for the submit page
	my $postPage = GetPageHeader("Thank You", "Thank You", 'post');
#	$postPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;
	$postPage .= GetTemplate('maincontent.template');
	my $postTemplate = GetTemplate('page/post.template');
	$postPage .= $postTemplate;
	$postPage .= GetPageFooter();
	$postPage = InjectJs($postPage, qw(settings avatar post));
	if (GetConfig('admin/js/enable')) {
		$postPage =~ s/<body /<body onload="makeRefLink();" /;
		$postPage =~ s/<body>/<body onload="makeRefLink();">/;
	}
	WriteLog('MakeSummaryPages: ' . "$HTMLDIR/post.html");
	PutHtmlFile("post.html", $postPage);
	
	
	# Ok page
	my $okPage;
	$okPage .= GetPageHeader('OK', 'OK', 'default');
	my $windowContents = GetTemplate('action_ok.template');
	$okPage .= GetWindowTemplate('Data Received', '', '', $windowContents, 'Ready');
	$okPage .= GetPageFooter();
	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;
	$okPage = InjectJs($okPage, qw(settings));
	PutHtmlFile("action/event.html", $okPage);

	MakeSimplePage('manual'); # manual.html
	MakeSimplePage('help'); # help.html
	MakeSimplePage('welcome'); # welcome.html
	MakeSimplePage('manual_advanced'); # manual_advanced.html
	MakeSimplePage('manual_tokens'); # manual_tokens.html

	# Blank page
	PutHtmlFile("blank.html", "");


	# Zalgo javascript
	PutHtmlFile("zalgo.js", GetTemplate('js/lib/zalgo.js'));


	if (!-e "$HTMLDIR/openpgp.js" || !-e "$HTMLDIR/openpgp.worker.js") {
		# OpenPGP javascript
		PutHtmlFile("openpgp.js", GetTemplate('js/lib/openpgp.js'));
		PutHtmlFile("openpgp.worker.js", GetTemplate('js/lib/openpgp.worker.js'));
	}

	PutHtmlFile("sha512.js", GetTemplate('js/sha512.js'));


	if (GetConfig('admin/php/enable')) {
	#if php/enabled, then use post.php instead of post.html
	#todo add rewrites for this
	#rewrites have been added for this, so it's commented out for now, but could still be an option in the future
#		$cryptoJsTemplate =~ s/\/post\.html/\/post.php/;
	}
	#PutHtmlFile("crypto.js", $cryptoJsTemplate);

	my $crypto2JsTemplate = GetTemplate('js/crypto2.js');
	if (GetConfig('admin/js/debug')) {
		#$crypto2JsTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/g;
		$crypto2JsTemplate = EnableJsDebug($crypto2JsTemplate);
	}
	my $algoSelectMode = GetConfig('admin/gpg/algo_select_mode');
	if ($algoSelectMode) {
		if ($algoSelectMode eq '512' || $algoSelectMode eq 'random' || $algoSelectMode eq 'max') {
			$crypto2JsTemplate = str_replace('var algoSelectMode = 0;', "var algoSelectMode = '$algoSelectMode'", $crypto2JsTemplate);
		}
	}
	PutHtmlFile("crypto2.js", $crypto2JsTemplate);

	# Write avatar javascript
	my $avatarJsTemplate = GetTemplate('js/avatar.js');
	if (GetConfig('admin/js/debug')) {
		# $avatarJsTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/g;
		$avatarJsTemplate = EnableJsDebug($avatarJsTemplate);

	}
	PutHtmlFile("avatar.js", $avatarJsTemplate);

	# Write settings javascript
	#PutHtmlFile("settings.js", GetTemplate('js/settings.js'));
	PutHtmlFile("prefstest.html", GetTemplate('js/prefstest.template'));

	if (GetConfig('admin/php/enable')) {
		my $postPhpTemplate = GetTemplate('php/post.php');
		PutFile($PHPDIR . '/post.php', $postPhpTemplate);

		my $test2PhpTemplate = GetTemplate('php/test2.php');
		PutFile($PHPDIR . '/test2.php', $test2PhpTemplate);

		my $adminPhpTemplate = GetTemplate('php/config.php');
		PutFile($PHPDIR . '/config.php', $adminPhpTemplate);

		my $testPhpTemplate = GetTemplate('php/test.php');
		PutFile($PHPDIR . '/test.php', $testPhpTemplate);

		my $writePhpTemplate = GetTemplate('php/write.php');
		PutFile($PHPDIR . '/write.php', $writePhpTemplate);

		my $uploadPhpTemplate = GetTemplate('php/upload.php');
		PutFile($PHPDIR . '/upload.php', $uploadPhpTemplate);

		my $searchPhpTemplate = GetTemplate('php/search.php');
		PutFile($PHPDIR . '/search.php', $searchPhpTemplate);

		my $cookiePhpTemplate = GetTemplate('php/cookie.php');
		PutFile($PHPDIR . '/cookie.php', $cookiePhpTemplate);

		my $cookieTestPhpTemplate = GetTemplate('php/cookietest.php');
		PutFile($PHPDIR . '/cookietest.php', $cookieTestPhpTemplate);

		my $utilsPhpTemplate = GetTemplate('php/utils.php');
        $utilsPhpTemplate =~ s/\$scriptDirPlaceholderForTemplating/$SCRIPTDIR/g;
		PutFile($PHPDIR . '/utils.php', $utilsPhpTemplate);

		my $routePhpTemplate = GetTemplate('php/route.php');
		PutFile($PHPDIR . '/route.php', $routePhpTemplate);
	}

	{
		# .htaccess file for Apache
		my $HtaccessTemplate = GetTemplate('htaccess/htaccess.template');

		# here, we inject the contents of 401.template into .htaccess
		# this is a kludge until i figure out how to do it properly
		# 401.template should not contain any " characters
		#
		my $text401 = GetTemplate('401.template');
		$text401 =~ s/\n//g;
		$text401 = '"' . $text401 . '"';
		$HtaccessTemplate =~ s/\/error\/error-401\.html/$text401/g;

		if (GetConfig('admin/php/enable')) {
			$HtaccessTemplate .= "\n" . GetTemplate('htaccess/htaccess_php.template');

			my $rewriteSetting = GetConfig('admin/php/rewrite');
			if ($rewriteSetting) {
				if ($rewriteSetting eq 'all') {
					$HtaccessTemplate .= "\n" . GetTemplate('htaccess/htaccess_php_rewrite_all.template');
				}
				if ($rewriteSetting eq 'query') {
					$HtaccessTemplate .= "\n" . GetTemplate('htaccess/htaccess_php_rewrite_query.template');
				}
			}
		}

		if (GetConfig('admin/http_auth/enable')) {
			my $HtpasswdTemplate .= GetConfig('admin/http_auth/htpasswd');
			my $HtaccessHttpAuthTemplate = GetTemplate('htaccess/htaccess_htpasswd.template');

			if ($HtpasswdTemplate & $HtaccessHttpAuthTemplate) {
				PutFile("$HTMLDIR/.htpasswd", $HtpasswdTemplate);
				chmod 0644, "$HTMLDIR/.htpasswd";

				$HtaccessHttpAuthTemplate =~ s/\.htpasswd/$HTMLDIR\/\.htpasswd/;

				my $errorDocumentRoot = "$HTMLDIR/error/";
				$HtaccessHttpAuthTemplate =~ s/\$errorDocumentRoot/$errorDocumentRoot/g;
				#todo this currently has a one-account template
				#todo add generating of template for both lighttpd and htaccess

				$HtaccessTemplate .= "\n" . $HtaccessHttpAuthTemplate;
			}
		}

		if (GetConfig('admin/ssi/enable')) {
			my $ssiConf = GetTemplate('htaccess/htaccess_ssi.template');

			$HtaccessTemplate .= "\n" . $ssiConf;
		}

		PutFile("$HTMLDIR/.htaccess", $HtaccessTemplate);
	}

	PutHtmlFile("favicon.ico", '');

	{
		# p.gif
		WriteLog('making p.gif');

		if (!-e './config/template/p.gif.template') {
			if (-e 'default/template/p.gif.template') {
				copy('default/template/p.gif.template', 'config/template/p.gif.template');
			}
		}

		if (-e 'config/template/p.gif.template') {
			copy('config/template/p.gif.template', $HTMLDIR . '/p.gif');
		}
	}

	WriteLog('MakeSummaryPages() END');
}

sub GetUploadWindow { # upload window for upload page
	my $uploadForm = GetTemplate('form/upload.template');
	if (GetConfig('admin/js/enable')) {
		# $uploadForm = AddAttributeToTag($uploadForm, 'input name=uploaded_file', 'onchange', "if (document.upload && document.upload.submit && document.upload.submit.value == 'Upload') { document.upload.submit.click(); }");
		# this caused back button breaking
		$uploadForm = AddAttributeToTag($uploadForm, 'input name=uploaded_file', 'onchange', "UploadedFileOnChange(this)");
		$uploadForm = AddAttributeToTag($uploadForm, 'input name=submit', 'onclick', "this.value='Meditate...';");
	}
	my $allowFiles = GetConfig('admin/image/allow_files');
	$uploadForm =~ s/\$allowFiles/$allowFiles/gms;
	my $uploadWindow = GetWindowTemplate('Upload', '', '', $uploadForm, '');
	return $uploadWindow;
} # GetUploadWindow()

sub GetSearchWindow { # search window for search page
	my $searchForm = GetTemplate('form/search.template');
	my $searchWindow = GetWindowTemplate('Public Search', '', '', $searchForm, '');
	return $searchWindow;
} # GetSearchWindow()

sub GetWriteForm { # returns write form (for composing text message)
	my $writeForm = GetTemplate('form/write/write.template');
	WriteLog('GetWriteForm()');

	if (GetConfig('admin/js/enable')) {
		WriteLog('GetWriteForm: js is on, adding write_js.template');
		my $writeJs = GetTemplate('form/write/write_js.template');
		$writeForm =~ s/\$writeJs/$writeJs/g;
	}
	else {
		WriteLog('GetWriteForm: js is off, removing $writeJs');
		$writeForm =~ s/\$writeJs//g;
	}

	if (GetConfig('admin/php/enable')) {
		my $writeLongMessage = GetTemplate('form/write/long_message.template');
		if ($writeLongMessage) {
			my $targetElement = '<span id=writeintro>';
			$writeForm = str_replace($targetElement, $targetElement . $writeLongMessage, $writeForm);
		}

		if (GetConfig('admin/js/enable')) {
			$writeForm = AddAttributeToTag(
				$writeForm,
				'a href="/etc.html"', #todo this should link to item itself
				'onclick',
				"if (window.ShowAll && this.removeAttribute) { if (this.style) { this.style.display = 'none'; } return ShowAll(this, this.parentElement.parentElement); } else { return true; }"
			);
		}

		## changing the form target is no longer necessary thanks to mod_rewrite
		## this code may have to be reused later when we want to adapt to an environment
		## without mod_rewrite

		#if php module is enabled, change the form target to post.php
		#		my $postHtml = 'post.html';
		# on a separate line because
		# putting it into the regex would require escaping the period,
		# and searching for "post.html" in the codebase would not find this line

		#		$submitForm =~ s/$postHtml/post.php/;

		# this is how autosave would work
		# $submitForm =~ s/\<textarea/<textarea onkeyup="if (this.length > 2) { document.forms['compose'].action='\/post2.php'; }" /;
	}

	my $initText = '';
	#
	# # these are not present in the template
	# $writeForm =~ s/\$extraFields/poop/g;
	$writeForm =~ s/\$initText/$initText/g;

	if (GetConfig('admin/js/enable')) {
		# $replyForm = AddAttributeToTag($replyForm, 'textarea', 'style', 'background-color: red important!; border: 10pt solid red; width: 1000px;');
		# $replyForm = AddAttributeToTag($replyForm, 'textarea', 'badse', 'ternefojf adfa');

		# onchange="if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }"
		# onkeyup="if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }"
		# onkeydown="if (window.translitKey) { translitKey(event, this); } else { return true; }"
		$writeForm = AddAttributeToTag($writeForm, 'textarea', 'onchange', "if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }");
		$writeForm = AddAttributeToTag($writeForm, 'textarea', 'onkeyup', "if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }");

		if (GetConfig('admin/js/translit')) {
			$writeForm = AddAttributeToTag($writeForm, 'textarea', 'onkeydown', 'if (window.translitKey) { translitKey(event, this); } else { return true; }');
		}
		#$writeForm = AddAttributeToTag($writeForm, 'a href="/frame.html"', 'onclick', 'if (window.showKeyboard) { return showKeyboard(); }');
	}


	return $writeForm;
} # GetWriteForm()

sub GetUploadPage { # returns html for upload page
	my $html = '';
	my $title = 'Upload';

	if (GetConfig('admin/php/enable')) {
		$html .= GetPageHeader($title, $title, 'upload');
		$html .= GetTemplate('maincontent.template');
		$html .= GetUploadWindow();
		$html .= GetPageFooter();

		if (GetConfig('admin/js/enable')) {
			$html = InjectJs($html, qw(settings avatar profile upload));
		}
	} else {
		$html .= GetPageHeader($title, $title, 'upload');
		$html .= GetTemplate('maincontent.template');
		$html .= GetWindowTemplate($title, '', '', '<p>Upload feature is not available. Apologies.</p>');
		$html .= GetPageFooter();
		if (GetConfig('admin/js/enable')) {
			$html = InjectJs($html, qw(settings avatar profile));
		}
	}

	return $html;
} # GetUploadPage()

sub GetSearchPage { # returns html for search page
	my $html = '';
	my $title = 'Search';

	$html .= GetPageHeader($title, $title, 'search');
	$html .= GetTemplate('maincontent.template');
	$html .= GetSearchWindow();
	$html .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		$html = InjectJs($html, qw(settings avatar profile puzzle));
		$html =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$html =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}
	return $html;
} # GetSearchPage()

sub GetWritePage { # returns html for write page
	# $writePageHtml stores html page output
	my $writePageHtml = "";

	my $title = "Write";
	my $titleHtml = "Write";

	my $itemCount = DBGetItemCount();
	my $itemLimit = GetConfig('number/item_limit');
	if (!$itemLimit) {
		$itemLimit = 9000;
	}

	$writePageHtml = GetPageHeader($title, $titleHtml, 'write');
	$writePageHtml .= GetTemplate('maincontent.template');

	my $writeForm = GetWriteForm();
	$writePageHtml .= $writeForm;

	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
		my $itemCounts = GetTemplate('form/itemcount.template');
		$itemCounts =~ s/\$itemCount/$itemCount/g;
		$itemCounts =~ s/\$itemLimit/$itemLimit/g;
	}

	$writePageHtml .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		# $writePageHtml = str_replace(
		# 	'<span id=spanInputOptions></span>',
		# 	'<span id=spanInputOptions>
		# 		<noscript>More input options available with JavaScript</noscript>
		# 	</span>',
		# 	$writePageHtml
		# );
		# I decided against this approach
		# Because displaying the links with appendChild()
		# would exclude many browsers who would otherwise support keyboard

		my @js = qw(settings avatar write profile utils timestamp);
		if (GetConfig('admin/php/enable')) {
			push @js, 'write_php';
		}
		if (GetConfig('admin/token/puzzle')) {
			push @js, 'puzzle';
			# push @js, 'puzzle', 'sha512';
		}
		if (GetConfig('admin/js/translit')) {
			push @js, 'translit';
		}

		$writePageHtml = InjectJs($writePageHtml, @js);
	}

	if (GetConfig('admin/js/enable')) {
		# add call to WriteOnload() to page
		$writePageHtml = AddAttributeToTag(
			$writePageHtml,
			'body',
			'onload',
			'if (window.OnLoadEverything) { OnLoadEverything(); }'
		);
	}

	return $writePageHtml;
} # GetWritePage()


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

		my $brcAddressForm = GetTemplate('form/brc_address.template');
		$eventAddForm =~ s/\$brcAddressForm/$brcAddressForm/;
	} else {
		$eventAddForm =~ s/\$brcLocation//g;
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

	$txtIndex = InjectJs($txtIndex, qw(settings avatar event_add profile));

	my $colorRow0Bg = GetThemeColor('row_0');
	my $colorRow1Bg = GetThemeColor('row_1');

	$txtIndex =~ s/\$colorRow0Bg/$colorRow0Bg/g;
	$txtIndex =~ s/\$colorRow1Bg/$colorRow1Bg/g;

	return $txtIndex;
}

sub GetProfilePage { # returns profile page (allows sign in/out)
	my $txtIndex = "";
	my $title = "Profile";
	my $titleHtml = "Profile";

	if (GetConfig('admin/js/enable') || GetConfig('admin/php/enable')) {
		$txtIndex = GetPageHeader($title, $titleHtml, 'identity');
		$txtIndex .= GetTemplate('maincontent.template');

		my $profileWindowContents = GetTemplate('form/profile.template');

		if (GetConfig('admin/gpg/use_gpg2')) {
			my $gpg2Choices = GetTemplate('gpg2.choices.template');
			$profileWindowContents =~ s/\$gpg2Algochoices/$gpg2Choices/;
		} else {
			$profileWindowContents =~ s/\$gpg2Algochoices//;
		}

		my $profileWindow = GetWindowTemplate(
			'Profile',
			'',
	#		'<a class=advanced href="/gpg.html">Signatures</a>',
			'',
			$profileWindowContents,
			''
		);
		$txtIndex .= $profileWindow;
		$txtIndex .= GetPageFooter();

		if (GetConfig('admin/js/enable')) {
			$txtIndex = InjectJs($txtIndex, qw(settings utils profile timestamp));

			# these two lines are different, regex is hard sometimes
			$txtIndex =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /;
			$txtIndex =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/;
		} else {
			# js is disabled
		}
	} else {
		$txtIndex = GetPageHeader($title, $titleHtml, 'identity');
		$txtIndex .= GetTemplate('maincontent.template');

		my $profileWindowContents = GetTemplate('form/profile_no.template');
		my $profileWindow = GetWindowTemplate(
			'Profile',
			'',
			#		'<a class=advanced href="/gpg.html">Signatures</a>',
			'',
			$profileWindowContents,
			''
		);

		$txtIndex .= $profileWindow;
		$txtIndex .= GetPageFooter();
	}

	# this is an alternative way of including the scripts, replaced by javascript-based way
	# ProfileOnLoad has the alternative way, but this way works too, and may have some unknown benefits
	#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
} # GetProfilePage()

sub GetAccessPage { # returns html for accessibility mode page, /access.html
	my $html = '';

	my $title = 'Access';

	$html = GetPageHeader($title, $title, 'access');
	$html .= GetTemplate('maincontent.template');
	my $accessTemplate = GetTemplate('access.template');
	$accessTemplate = GetWindowTemplate('Select Accessibility Mode', '', '', $accessTemplate, '');
	$html .= $accessTemplate;
	$html .= GetPageFooter();

	return $html;
}

sub GetSettingsPage { # returns html for settings page (/settings.html)
	my $txtIndex = "";

	my $title = "Settings";
	my $titleHtml = "Settings";

	$txtIndex = GetPageHeader($title, $titleHtml, 'settings');

	$txtIndex .= GetTemplate('maincontent.template');

	my $settingsTemplate = GetTemplate('form/settings.template');
	$txtIndex .= $settingsTemplate;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(settings avatar profile timestamp pingback));
	if (GetConfig('admin/js/enable')) {
		$txtIndex =~ s/<body /<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }" /i;
		$txtIndex =~ s/<body>/<body onload="if (window.OnLoadEverything) { OnLoadEverything(); }">/i;
	}

	return $txtIndex;
} # GetSettingsPage()

sub GetEtcPage { # returns html for etc page (/etc.html)
	my $txtIndex = "";

	my $title = "More";
	my $titleHtml = "More";

	$txtIndex = GetPageHeader($title, $titleHtml, 'etc');

	$txtIndex .= GetTemplate('maincontent.template');

	my $menuItems = GetMenuFromList('menu', 'menuitem-p.template');
	$menuItems .= GetMenuFromList('menu_advanced', 'menuitem-p.template');

	my $etcPageContent = GetTemplate('etc.template');

	$etcPageContent =~ s/\$etcMenuItems/$menuItems/;

	my $etcPageWindow = GetWindowTemplate('More', '', '', $etcPageContent, '');

	$txtIndex .= $etcPageWindow;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(settings avatar profile));

#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	# if (GetConfig('admin/js/enable')) {
	#	$txtIndex =~ s/<body /<body onload="SettingsOnload();" /;
	# }

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

	my $myHost = GetConfig('admin/rss_host');

	my $baseUrl = 'http://' . $myHost . '/';

	my $feedTitle = GetConfig('home_title');
	my $feedLink = GetConfig('admin/my_domain'); # default = http://localhost:2784/
	my $feedDescription = GetString('site_description');
	my $aboutUrl = $baseUrl;
	
	my $feedPubDate = GetTime();
	$feedPubDate = localtime($feedPubDate);
	#%a, %d %b %Y %H:%M +:%S %Z
	
	if (!$feedLink) {
		$feedLink = $myHost;
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

		if (IsFileDeleted(0, $fileHash)) {
			WriteLog("generate.pl: IsFileDeleted() returned true, skipping");

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
		my $itemLink = 'http://' . $myHost . '/' . GetHtmlFilename($fileHash);
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
	#todo refactor to be a call to GetItemPage
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

	$txtPageHtml = InjectJs($txtPageHtml, qw(settings avatar));

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

		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");
		
		system("zip -q $HTMLDIR/index.sqlite3.zip.tmp cache/" . GetMyCacheVersion() . "/index.sqlite3");
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

	$dataPageContents = $dataPageContents;

	my $dataPageWindow = GetWindowTemplate('Data', '', '', $dataPageContents, 'Ready');

	$dataPage .= $dataPageWindow;

	$dataPage .= GetPageFooter();

	$dataPage = InjectJs($dataPage, qw(settings avatar profile));

	PutHtmlFile("data.html", $dataPage);
}

sub GetItemPageFromHash {
#todo unfinished

	my $fileHash = shift;
	chomp $fileHash;

	WriteLog("GetItemPageFromHash($fileHash)");

	# get item list using DBGetItemList()
	# #todo clean this up a little, perhaps crete DBGetItem()
	my @files = DBGetItemList({'where_clause' => "WHERE file_hash = '$fileHash'"});

	if (scalar(@files)) {
		my $file = $files[0];

		WriteLog('GetItemPageFromHash: my $filePage = GetItemPage($file = "' . $file . '")');
		my $filePage = GetItemPage($file);

		return $filePage;
	} else {
		WriteLog("pages.pl: \@files loop: warning: Asked to index file $fileHash, but it is not in the database! Returning.");
		return '';
	}
}

sub GetItemTemplateFromHash {
#todo unfinished
	my $fileHash = shift;
	chomp $fileHash;

	WriteLog("GetItemTemplateFromHash($fileHash)");

	# get item list using DBGetItemList()
	# #todo clean this up a little, perhaps crete DBGetItem()
	my @files = DBGetItemList({'where_clause' => "WHERE file_hash = '$fileHash'"});

	if (scalar(@files)) {
		my $file = $files[0];

		WriteLog('GetItemTemplateFromHash: my $itemPage = GetItemTemplate($file = "' . $file . '")');
		my $itemPage = GetItemTemplate($file);

		return $itemPage;
	} # scalar(@files)
	else {
		WriteLog('GetItemTemplateFromHash: warning: sanity check failed');
		return '';
	} #
} # DBGetItemTemplateFromHash()

sub PutStatsPages {
	my $statsPage = GetStatsPage();
	PutHtmlFile("stats.html", $statsPage);

	my $statsFooter = GetWindowTemplate(
		'Site Statistics*',
		'',
		'',
		GetStatsTable('stats-horizontal.template'),
		''
	);
	PutHtmlFile("stats-footer.html", $statsFooter);
}

sub MakePage { # $pageType, $pageParam, $priority ; make a page and write it into $HTMLDIR directory; $pageType, $pageParam
	# $pageType = author, item, tags, etc.
	# $pageParam = author_id, item_hash, etc.
	my $pageType = shift;
	my $pageParam = shift;
	my $priority = shift;

	if (!$priority) {
		$priority = 0;
	}

	WriteLog('MakePage: lazy_page_generation: ' . GetConfig('admin/pages/lazy_page_generation') . '; $priority: ' . $priority);

	#todo sanity checks

	WriteLog('MakePage(' . $pageType . ', ' . $pageParam . ')');

	WriteMessage('MakePage(' . $pageType . ', ' . $pageParam . ')');

	# tag page, get the tag name from $pageParam
	if ($pageType eq 'tag') {
		my $tagName = $pageParam;
		my $targetPath = "top/$tagName.html";

		if (GetConfig('admin/pages/lazy_page_generation') && !$priority) {
			WriteLog('MakePage: tag: lazy is on, removing instead');
			RemoveHtmlFile($targetPath);
		} else {
			WriteLog("MakePage: tag: $tagName");
			my $tagPage = GetReadPage('tag', $tagName);
			PutHtmlFile($targetPath, $tagPage);
			if ($tagName eq 'image') {
				PutHtmlFile("art.html", $tagPage);
			}
		}
	}
	#
	# author page, get author's id from $pageParam
	elsif ($pageType eq 'author') {
		my $authorKey = $pageParam;
		my $targetPath = "author/$authorKey/index.html";

		if (GetConfig('admin/pages/lazy_page_generation') && !$priority) {
			WriteLog('MakePage: author: lazy is on, removing instead');
			RemoveHtmlFile($targetPath);
		} else {
			WriteLog('MakePage: author: ' . $authorKey);
			my $authorPage = GetReadPage('author', $authorKey);
			if (!-e "$HTMLDIR/author/$authorKey") {
				mkdir ("$HTMLDIR/author/$authorKey");
			}
			PutHtmlFile($targetPath, $authorPage);
		}
	}
	#
	# if $pageType eq item, generate that item's page
	elsif ($pageType eq 'item') {
		# get the item's hash from the param field
		my $fileHash = $pageParam;

		# get item page's path #todo refactor this into a function
		#my $targetPath = $HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
		my $targetPath = GetHtmlFilename($fileHash);

		if (GetConfig('admin/pages/lazy_page_generation') && !$priority) {
			WriteLog('MakePage: item: lazy is on, removing instead');
			RemoveHtmlFile($targetPath);
			return;
		}

		# get item list using DBGetItemList()
		# #todo clean this up a little, perhaps crete DBGetItem()
		my @files = DBGetItemList({'where_clause' => "WHERE file_hash LIKE '$fileHash%'"});

		if (scalar(@files)) {
			my $file = $files[0];

			# create a subdir for the first 2 characters of its hash if it doesn't exist already
			if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2))) {
				mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2)));
			}
			if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2))) {
				mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)));
			}

			# get the page for this item and write it
			WriteLog('MakePage: my $filePage = GetItemPage($file = "' . $file . '")');
			my $filePage = GetItemPage($file);
			WriteLog('PutHtmlFile($targetPath = ' . $targetPath . ', $filePage = ' . $filePage . ')');
			PutHtmlFile($targetPath, $filePage);
		} else {
			WriteLog("pages.pl: item page: warning: Asked to index file $fileHash, but it is not in the database! Returning.");
		}
	} #item page

	elsif ($pageType eq 'tags') { #tags page
		my $tagsPage = GetTagsPage('Tags', 'Tags', '');
		PutHtmlFile("tags.html", $tagsPage);

		my $votesPage = GetTagsPage('Votes', 'Votes', 'ORDER BY vote_value');
		PutHtmlFile("votes.html", $votesPage);

		my $tagsHorizontal = GetTagLinks();
		PutHtmlFile('tags-horizontal.html', $tagsHorizontal);
	}
	#
	# events page
	elsif ($pageType eq 'events') {
		my $eventsPage = GetEventsPage();
		PutHtmlFile("events.html", $eventsPage);
	}
	#
	# scores page
	elsif ($pageType eq 'scores') {
		my $scoresPage = GetScoreboardPage();
		PutHtmlFile("authors.html", $scoresPage);
	}
	#
	# topitems page
	elsif ($pageType eq 'read') {
		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile("read.html", $topItemsPage);

		if (GetConfig('home_page') eq 'read') {
			PutHtmlFile("index.html", $topItemsPage);
		}
	}
	#
	# stats page
	elsif ($pageType eq 'stats') {
		PutStatsPages();
	}
	#
	# index pages (queue)
	elsif ($pageType eq 'index') {
		WriteIndexPages();
	}
	#
	# rss feed
	elsif ($pageType eq 'rss') {
		#todo break out into own module and/or auto-generate rss for all relevant pages

		my %queryParams;

		$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
		my @rssFiles = DBGetItemList(\%queryParams);

		PutFile("$HTMLDIR/rss.xml", GetRssFile(@rssFiles));
	}
	#
	# summary pages
	elsif ($pageType eq 'summary') {
		MakeSummaryPages();
	}
}

sub BuildTouchedPages { # $timeLimit, $startTime ; builds pages returned by DBGetTouchedPages();
# DBGetTouchedPages() means select * from task where priority > 0

	my $timeLimit = shift;
	if (!$timeLimit) {
		$timeLimit = 0;
	}
	my $startTime = shift;
	if (!$startTime) {
		$startTime = 0;
	}

	my $pagesLimit = GetConfig('admin/update/limit_page');
	if (!$pagesLimit) {
		WriteLog("WARNING: config/admin/update/limit_page missing!");
		$pagesLimit = 1000;
	}

	my $pagesProcessed = 0;

	# get a list of pages that have been touched since the last git_flow
	# this is from the task table
	my $touchedPages = DBGetTouchedPages($pagesLimit);

	if ($touchedPages) { #todo actually check it's an array reference or something?
		# de-reference array of touched pages
		my @touchedPagesArray = @$touchedPages;

		# write number of touched pages to log
		WriteLog('scalar(@touchedPagesArray) = ' . scalar(@touchedPagesArray));

		# this part will refresh any pages that have been "touched"
		# in this case, 'touch' means when an item that affects the page
		# is updated or added
		foreach my $page (@touchedPagesArray) {
			if ($timeLimit && $startTime && ((time() - $startTime) > $timeLimit)) {
				WriteMessage("BuildTouchedPages: Time limit reached, exiting loop");
				WriteMessage("BuildTouchedPages: " . time() . " - $startTime > $timeLimit");
				last;
			}

			$pagesProcessed++;
			#	if ($pagesProcessed > $pagesLimit) {
			#		WriteLog("Will not finish processing pages, as limit of $pagesLimit has been reached");
			#		last;
			#	}
			#	if ((GetTime2() - $startTime) > $timeLimit) {
			#		WriteLog("Time limit reached, exiting loop");
			#		last;
			#	}

			# dereference @pageArray and get the 3 items in it
			my @pageArray = @$page;
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
	} # $touchedPages
	else {
		WriteLog('BuildTouchedPages: warning: $touchedPages was false, and thus not an array reference.');
		return 0;
	}

	return $pagesProcessed;
} # BuildTouchedPages

while (my $arg1 = shift) {
	# go through all the arguments one at a time
	if ($arg1) {
		if ($arg1 eq '--theme') {
			print ("recognized token --theme");
			my $themeArg = shift;
			chomp $themeArg;
			GetConfig('html/theme', 'override', $themeArg);
		}
		elsif (IsItem($arg1)) {
			print ("recognized item identifier\n");
			MakePage('item', $arg1, 1);
		}
		elsif (IsFingerprint($arg1)) {
			print ("recognized author fingerprint\n");
			MakePage('author', $arg1, 1);
		}
		elsif (substr($arg1, 0, 1) eq '#') {
			#todo sanity checks here
			print ("recognized hash tag $arg1\n");
			MakePage('tag', substr($arg1, 1), 1);
		}
		elsif ($arg1 eq '--summary' || $arg1 eq '-s') {
			print ("recognized --summary\n");
			MakeSummaryPages();
		}
		elsif ($arg1 eq '--index' || $arg1 eq '-i') {
			print ("recognized --index\n");
			WriteIndexPages();
		}
		elsif ($arg1 eq '--all' || $arg1 eq '-i') {
			print ("recognized --all\n");
			BuildTouchedPages();
		}
		else {
			print ("Available arguments:\n");
			print ("--summary or -s for all summary pages\n");
			print ("--index or -i for all index pages\n");
			print ("item id for one item's page\n");
			print ("author fingerprint for one item's page\n");
			print ("#tag for one tag's page\n");
		}
	}
}

1;
