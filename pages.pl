#!/usr/bin/perl -T

# pages.pl
# to do with html page generation

use strict;
use warnings;
use utf8;
use 5.010;

my @foundArgs;
while (my $argFound = shift) {
	push @foundArgs, $argFound;
}

#use warnings FATAL => 'all';
#
# $SIG{__WARN__} = sub {
# 	if (open (my $fileHandle, ">>", 'log/log.log')) {
# 		say $fileHandle "\n" . time() . " ";
# 		say $fileHandle @_;
# 		say $fileHandle "\n";
# 		close $fileHandle;
# 	}
#
# 	if (-e 'config/admin/debug') {
# 		die `This program does not tolerate warnings like: @_`;
# 	}
# };

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime ceil);
use Data::Dumper;
use File::Copy;
# use File::Copy qw(copy);
use Cwd qw(cwd);

require './utils.pl';
require './makepage.pl';
#
#my $SCRIPTDIR = cwd();
#if ($SCRIPTDIR =~ m/^([a-z\/_0-9]+)$/) {
#	# $SCRIPTDIR can't have spaces at this time
#	# this sanity check is restrictive
#	$SCRIPTDIR = $1;
#} else {
#	die('pages.pl: warning: $SCRIPTDIR sanity check failed');
#}

#use List::Uniq ':all';

#use Acme::RandomEmoji qw(random_emoji);

##todo
#if (!-e "$HTMLDIR/index.html") {
#	WriteLog('pages.pl: warning: index.html was missing!');
#	# this is a last-resort fallback for missing index.html file
#	# this should never be triggered, but sometimes is ...
#	if (-e "$HTMLDIR/welcome.html") {
#		WriteLog('pages.pl: warning: index.html was missing, replacing with welcome.html!');
#		rename("$HTMLDIR/welcome.html", "$HTMLDIR/index.html");
#	}
#}

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

			$windowContents = GetTemplate('html/404.template');

			#todo choose random item from list/looking_for
			my $lookingFor = 'mittens';
			$windowContents =~ s/looking for mittens/looking for $lookingFor/;

			my $pageTemplate;
			$pageTemplate = '';

			$pageTemplate .= GetPageHeader($pageTitle, $pageTitle, '404'); #GetTemplate('html/htmlstart.template');
			$pageTemplate .= GetTemplate('html/maincontent.template');
			$pageTemplate .= GetWindowTemplate($windowContents, $pageTitle);
			#: $windowTitle, $windowMenubar, $columnHeadings, $windowBody, $windowStatus
			$pageTemplate .= GetPageFooter();

			# settings.js provides ui consistency with other pages
			$pageTemplate = InjectJs($pageTemplate, qw(settings profile));

			return $pageTemplate;
		}
		if ($pageName eq '401') {
			$pageTitle = '401 Welcome to Access Denied';

			$windowContents = GetTemplate('html/401.template');

			my $pageTemplate;
			$pageTemplate = '';

			$pageTemplate .= GetPageHeader($pageTitle, $pageTitle, '401'); #GetTemplate('html/htmlstart.template');
			$pageTemplate .= GetTemplate('html/maincontent.template');
			$pageTemplate .= GetWindowTemplate($windowContents, $pageTitle);
			$pageTemplate .= GetPageFooter();

			return $pageTemplate;
		}
		if ($pageName eq 'ok') {
		}
	}
} # GetDialogPage()

sub RenderLink {
	my $url = shift;
	my $title = shift;

	#todo sanity, template, etc.

	return '<a href="' . $url . '">' . $title . '</a>';
} # RenderLink()

sub RenderField {
	my $fieldName = shift;
	my $fieldValue = shift;

	if ($fieldName eq 'last_seen') {
		$fieldValue = GetTimestampWidget($fieldValue);
	}

	if ($fieldName eq 'author_key') {
		$fieldValue = GetAuthorLink($fieldValue);
	}

	if ($fieldName eq 'vote_value') {
		my $link = "/top/" . $fieldValue . ".html";
		$fieldValue = RenderLink($link, $fieldValue);
	}
	
	return $fieldValue;
} # RenderField()

sub GetQueryAsDialog { # $query, $title, $columns
	my $query = shift;
	my $title = shift;
	my $columns = shift;

	my @result = SqliteQueryHashRef($query);

	return GetResultSetAsDialog(\@result, $title, $columns);
}

sub GetResultSetAsDialog { # \@result, $title, $columns
# \@result is an array of hash references
# ATTENTION: the first member of the array is the list of columns in correct order
# this list of columns is used if $columns is not specified

	my $resultRef = shift;
	my @result = @{$resultRef};

	my $title = shift;
	my $columns = shift;

	my $colorRow0Bg = GetThemeColor('row_0');
	my $colorRow1Bg = GetThemeColor('row_1');

	my $rowBgColor = $colorRow0Bg;

	#todo sanity;

	my $columnsRef = shift @result;
	my @columnsArray = @{$columnsRef};

	if (!$columns) {
		$columns = join(',', @columnsArray);
	}

	if (@result) {
		my $content = '';

		foreach my $row (@result) {
			$content .= '<tr bgcolor="' . $rowBgColor . '">';
			foreach my $column (split(',', $columns)) {
				$content .= '<td>';
				$content .= RenderField($column, $row->{$column});
				$content .= '</td>';
			}
			$content .= '</tr>';

			if ($rowBgColor eq $colorRow0Bg) {
				$rowBgColor = $colorRow1Bg;
			} else {
				$rowBgColor = $colorRow0Bg;
			}
		}

		return GetWindowTemplate($content, $title, $columns);
	} else {
		return GetWindowTemplate('No results.');
	}
} # GetQueryAsDialog()

#PutHtmlFile('thankyou.html', GetQueryAsDialog('SELECT * FROM item_flat', 'item_name,item_title,tags_list', 'gracias'));

sub GetStylesheet { # returns style template based on config
	state $styleSheet;
	if ($styleSheet) {
		return $styleSheet;
	}

	my $style = GetTemplate('css/default.css');
	# baseline style

	if (GetConfig('html/avatar_icons')) {
		$style .= "\n" . GetTemplate('css/avatar.css');
		# add style for color avatars if that's the setting
	}

	if (GetConfig('admin/js/dragging')) {
		$style .= "\n" . GetTemplate('css/dragging.css');
	}

	if (GetThemeAttribute('additional.css')) {
		$style .= "\n" . GetThemeAttribute('additional.css');
	}

	$styleSheet = $style;

	return $styleSheet;
}

sub GetAuthorLink { # $fingerprint, $showPlain ; returns avatar'ed link for an author id
	my $fingerprint = shift; # author's fingerprint
	my $showPlain = shift; # 1 to display avatar without colors

	# sanitize $showPlain
	if (!$showPlain) {
		$showPlain = 0;
	} else {
		$showPlain = 1;
	}

	# verify $fingerprint is valid
	if (!IsFingerprint($fingerprint)) {
		WriteLog('GetAuthorLink: warning: sanity check failed on $fingerprint = ' . $fingerprint);
		return '';
	}

	my $authorUrl = "/author/$fingerprint/index.html";

	my $authorAvatar = '';
	if ($showPlain) {
		$authorAvatar = GetAvatar($fingerprint);
	} else {
		$authorAvatar = GetAvatar($fingerprint);
	}

	my $authorLink = GetTemplate('html/authorlink.template');

	$authorAvatar = trim($authorAvatar);

	$authorLink =~ s/\$authorUrl/$authorUrl/g;
	$authorLink =~ s/\$authorAvatar/$authorAvatar/g;

	return $authorLink;
} # GetAuthorLink()

sub GetPageLink { # returns one pagination link as html, used by GetPageLinks
	my $pageNumber = shift;
	my $itemCount = shift;

	my $pageLimit = GetConfig('html/page_limit');

	if (!$pageLimit) {
		WriteLog('GetPageLink: warning: $pageLimit was FALSE, setting to sane 25');
		$pageLimit = 25;
	}

	my $pageStart = $pageNumber * $pageLimit;
	my $pageEnd = $pageNumber * $pageLimit + $pageLimit;
	if ($pageEnd > $itemCount) {
		$pageEnd = $itemCount - 1;
	}
	my $pageCaption = $pageStart . '-' . $pageEnd;

	state $pageLinkTemplate;
	if (!defined($pageLinkTemplate)) {
		$pageLinkTemplate = GetTemplate('html/pagelink.template');
	}

	my $pageLink = $pageLinkTemplate;
	$pageLink =~ s/\$pageName/$pageCaption/;

	$pageLink =~ s/\$pageNumber/$pageNumber/;

	return $pageLink;
}

sub GetWindowTemplate { # body title headings status menu ; returns html
# calls GetWindowTemplate2()
	my %param = ();

	$param{'body'} = shift;
	$param{'title'} = shift;
	$param{'headings'} = shift;
	$param{'status'} =  shift;
	$param{'menu'} = shift;

	if (!$param{'title'}) {
		WriteLog('GetWindowTemplate: warning: untitled window');
		my ($package, $filename, $line) = caller;
		WriteLog('GetWindowTemplate: caller: ' . $package . ',' . $filename . ', ' . $line);
		$param{'title'} = 'Untitled';
	}

	return GetWindowTemplate2(\%param);
} # GetWindowTemplate()

sub GetWindowTemplate2 { # \%paramHash ; returns window template
	my $paramHashRef = shift;
	my %param = %$paramHashRef;

	#return GetWindowTemplate ($param{'body'}, $param{'title'}, $param{'headings'}, $param{'status'}, $param{'menu'});

# returns template for html-table-based-"window"

	# $windowBody
	# what goes inside the biggest table cell in the middle
	# it is wrapped in <tr><td>...</td></tr> if does not contain "<tr"

	# $windowTitle = title bar, typically at the top of the window

	# $columnHeadings = column headings,
	# in format: col1,col2,col3
	# rendered as: <tr><td>col1</td><td>col2</td><td>col3</td>
	# each column name can contain html, e.g. link to sort by that column

	# $windowStatus
	# thing typically at the bottom of the window, as html

	# $windowMenubar
	# thing typically at the top of the window, as html

	# NOT IMPLEMENTED $windowId = if set, id=foo parameter is added to top-level tag

	my $windowBody = $param{'body'};
	my $windowTitle = $param{'title'};
	my $columnHeadings = $param{'headings'};
	my $windowStatus =  $param{'status'};
	my $windowMenubarContent = $param{'menu'};

	my $contentColumnCount = 1;
	# stores number of columns if they exist
	# if no columns, remains at 0
	# whether there are columns or not determines:
	# * column headers are added or no?
	# * colspan= in non-column cells

	# base template
	my $windowTemplate = GetTemplate('html/window/standard.template');

	# titlebar, if there is a title
	my $showButtons = GetConfig('html/window_titlebar_buttons'); # titlebar hide and skip buttons; #todo GetConfig('titlebar_with_button');
	if ($windowTitle) {
		if ($showButtons) {
			my $btnCloseCaption = '{-}'; # needs to match one other place in utils.js #collapseButton
			my $windowTitlebar = GetTemplate('html/window/titlebar_with_button.template');
			$windowTitlebar =~ s/\$windowTitle/$windowTitle/g;
			$windowTemplate =~ s/\$windowTitlebar/$windowTitlebar/g;
			$windowTemplate =~ s/\$btnCloseCaption/$btnCloseCaption/g;
			#$contentColumnCount = 2;
		} else {
			my $windowTitlebar = GetTemplate('html/window/titlebar.template');
			$windowTitlebar =~ s/\$windowTitle/$windowTitle/g;
			$windowTemplate =~ s/\$windowTitlebar/$windowTitlebar/g;
		}
	} else {
		$windowTemplate =~ s/\$windowTitlebar//g;
	}

	# menubar, if there is menubar content
	if ($windowMenubarContent) {
		my $windowMenubar = GetTemplate('html/window/menubar.template');
		$windowMenubar =~ s/\$windowMenubarContent/$windowMenubarContent/;

		$windowTemplate =~ s/\$windowMenubar/$windowMenubar/g;
	} else {
		$windowTemplate =~ s/\$windowMenubar//g;
	}

	# column headings
	if ($columnHeadings) {
		my $windowHeaderTemplate = GetTemplate('html/window/header_wrapper.template');
		my $windowHeaderColumns = '';
		my @columnsArray = split(',', $columnHeadings);

		my $printedColumnsCount = 0;
		foreach my $columnCaption (@columnsArray) {
			$printedColumnsCount++;
			my $columnHeaderTemplate = GetTemplate('html/window/header_column.template');
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
	}

	# main window content, aka body
	if ($windowBody) {
		if (index(lc($windowBody), '<tr') == -1) {
			if ($contentColumnCount > 1) {
				#todo templatize?
				$windowBody = '<tr class=content><td colspan=$contentColumnCount>' . $windowBody . '</td></tr>';
			} else {
				$windowBody = '<tr class=content><td>' . $windowBody . '</td></tr>';
			}
		} else {
			$windowBody = '<tbody class=content>' . str_replace('$contentColumnCount', $contentColumnCount, $windowBody) . '</tbody>';
		}

		$windowTemplate =~ s/\$windowBody/$windowBody/g;
	} else {
		$windowTemplate =~ s/\$windowBody//g;
	}

	# statusbar
	if ($windowStatus) {
		my $windowStatusTemplate = GetTemplate('html/window/status.template');
		$windowBody = str_replace('$contentColumnCount', $contentColumnCount, $windowBody);
		$windowStatusTemplate =~ s/\$windowStatus/$windowStatus/g;
		$windowTemplate =~ s/\$windowStatus/$windowStatusTemplate/g;
	} else {
		$windowTemplate =~ s/\$windowStatus//g;
	}

	# fill in column counts if necessary
	if ($contentColumnCount && $contentColumnCount != 1) {
		$windowTemplate =~ s/\$contentColumnCount/$contentColumnCount/g;
	} else {
		$windowTemplate =~ s/\ colspan=\$contentColumnCount//g;
	}

	if ($showButtons) {
		my $windowGuid = md5_hex($windowTemplate);
		if (defined($param{'guid'})) {
			if ($param{'guid'} =~ m/^[0-9a-f]{8}$/) {
				$windowGuid = $param{'guid'};
			} else {
				WriteLog('GetWindowTemplate2: warning: $param{guid} failed sanity check');
			}
		}

		my $itemEndAnchor = substr($windowGuid, 0, 8);
		WriteLog('GetWindowTemplate2: length($windowTemplate) = ' . length($windowTemplate) . '; $windowGuid = ' . $windowGuid);
		$windowTemplate =~ s/\$itemEndAnchor/$itemEndAnchor/g;
		$windowTemplate .= "<a name=$itemEndAnchor></a>";
	}

	return $windowTemplate;
} # GetWindowTemplate2()

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

	my $pageLimit = GetConfig('html/page_limit'); # number of items per page

	if (!$pageLimit) {
		WriteLog('GetPageLink: warning: $pageLimit was FALSE, setting to sane 25');
		$pageLimit = 25;
	}

	my $itemCount = DBGetItemCount(); # item count

	if (!$itemCount) {
		WriteLog('GetPageLink: warning: $itemCount was FALSE, sanity check failed');
		return '';
	}

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

		my $frame = GetTemplate('html/pagination.template');

		$frame =~ s/\$paginationLinks/$pageLinks/;

		$pageLinks = $frame;

		# up to this point, we are building the in-memory template for the pagination links
		# once it is stored in $pageLinks, which is a static ("state") variable,
		# GetPageLinks() returns at the top, and does not reach here.
		return GetPageLinks($currentPageNumber);
	}
}
#
#sub GetEventsPage { # returns html for events page
#	WriteLog('GetEventsPage()');
#
#	my $txtPage = '';
#
#	my $title = 'Upcoming Events';
#	my $titleHtml = 'Upcoming Events';
#
#	$txtPage = GetPageHeader($title, $titleHtml, 'events');
#
#	$txtPage .= GetTemplate('html/maincontent.template');
#
#	my @eventsArray = DBGetEvents();
#
#	my $eventsItemsList = '';
#
#	my $rowBgColor = '';
#	my $colorRow0Bg = GetThemeColor('row_0');
#	my $colorRow1Bg = GetThemeColor('row_1');
#
#	while (@eventsArray) {
#		my $event = shift @eventsArray;
#
#		#alternating row colors hack
#		if ($rowBgColor eq $colorRow0Bg) {
#			$rowBgColor = $colorRow1Bg;
#		} else {
#			$rowBgColor = $colorRow0Bg;
#		}
#
#		my $eventItemHash = $event->{'file_hash'};
#		my $eventTitle =  $event->{'event_title'};
#		my $eventTime = $event->{'event_time'};
#		my $eventDuration = $event->{'event_duration'};
#		my $eventItemLink = GetItemHtmlLink($eventItemHash);
#		my $eventItemAuthor = $event->{'author_key'};
#
#		if (!$eventTitle) {
#			$eventTitle = 'Untitled';
#		}
#
#		if ($eventTitle) {
#			$eventTitle = HtmlEscape($eventTitle);
#			$eventTitle = '<a href="' . GetHtmlFilename($eventItemHash) . '">' . $eventTitle . '</a>'; #todo templatify
#		}
#
#		if (!$eventItemAuthor) {
#			$eventItemAuthor = '';
#		} else {
#			$eventItemAuthor = 'Author: ' . $eventItemAuthor . '<br>'; #todo templatify
#		}
#
#		my $eventTimeUntil = $eventTime + $eventDuration;
##		my $eventTimeUntil = $eventTime - GetTime();
##		if ($eventTimeUntil > 0) {
##			$eventTimeUntil = 'in ' . GetSecondsHtml($eventTimeUntil);
##		} else {
##			$eventTimeUntil = $eventTimeUntil * -1;
##			$eventTimeUntil = GetSecondsHtml($eventTimeUntil) . ' ago';
##		}
#
#		if ($eventTime) {
##			$eventTime = EpochToHuman($eventTime);
#		} else {
#			$eventTime = '(no time)';
#		}
#
#		if ($eventDuration) {
#			$eventDuration = GetSecondsHtml($eventDuration);
#		} else {
#			$eventDuration = '(no duration)';
#		}
#
#		my $eventVoteButtons = GetItemTagButtons($eventItemHash, 'event');
#
#		my $eventItem = GetTemplate('event/event_item2.template');
#
#		$eventTime = GetTimestampWidget($eventTime);
#		$eventTimeUntil = GetTimestampWidget($eventTimeUntil);
#
#		$eventItem =~ s/\$eventTitle/$eventTitle/;
#		$eventItem =~ s/\$eventTime/$eventTime/;
#		$eventItem =~ s/\$eventTimeUntil/$eventTimeUntil/;
#		$eventItem =~ s/\$eventDuration/$eventDuration/;
#		$eventItem =~ s/\$eventItemLink/$eventItemLink/;
#		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
#		$eventItem =~ s/\$eventItemAuthor/$eventItemAuthor/;
#		$eventItem =~ s/\$voteButtons/$eventVoteButtons/;
#		$eventItem =~ s/\$rowBgColor/$rowBgColor/;
#
#		$eventsItemsList .= $eventItem;
#	}
#
#	my $eventsList = GetTemplate('event/event_list2.template');
#
#	$eventsList =~ s/\$eventsList/$eventsItemsList/;
#
#	$txtPage .= $eventsList;
#
#	$txtPage .= GetPageFooter();
#
#	$txtPage = InjectJs($txtPage, qw(settings avatar timestamp voting profile));
#
#	return $txtPage;
#
#}

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

	my $voteItemsWrapper = GetTemplate('html/tag_wrapper.template');

	my $voteItems = '';

	my $voteItemTemplateTemplate = GetTemplate('html/tag.template');
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
		# $voteItems = GetTemplate('html/tag_listing_empty.template');
	}

	$voteItemsWrapper =~ s/\$tagLinks/$voteItems/g;

	return $voteItemsWrapper;
} # GetTagLinks()

sub GetQueryPage {
	my $pageName = shift;
	#todo sanity

	my $html = '';

	my $query = GetConfig('query/' . $pageName);

	if ($query) {
		$html .= GetPageHeader($pageName, $pageName, $pageName);
		$html .= GetTemplate('html/maincontent.template');
		$html .= GetQueryAsDialog($query, $pageName);
		$html .= GetPageFooter();
		return $html;
	} else {
		#todo
	}
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

	$txtIndex .= GetTemplate('html/maincontent.template');

	my $voteCounts;
	$voteCounts = DBGetVoteCounts($orderBy);

	my @voteCountsArray = @{$voteCounts};

	my $voteItemsWrapper = GetTemplate('html/tag_listing_wrapper.template');

	my $voteItems = '';

	my $voteItemTemplate = GetTemplate('html/tag_listing.template');
	while (@voteCountsArray) {
		my $voteItemOutput = $voteItemTemplate;

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

		$voteItemOutput =~ s/\$link/$voteItemLink/g;
		$voteItemOutput =~ s/\$tagName/$tagName/g;
		$voteItemOutput =~ s/\$tagCount/$tagCount/g;
		$voteItemOutput =~ s/\$tagInfo/$tagInfo/g;

		$voteItems .= $voteItemOutput;
	}

	if (!$voteItems) {
		$voteItems = GetTemplate('html/tag_listing_empty.template');
	}

	$voteItemsWrapper =~ s/\$tagListings/$voteItems/g;

	$txtIndex .= $voteItemsWrapper;

	$txtIndex .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar profile utils fresh));
	}

	return $txtIndex;
} # GetTagsPage

require './item_page.pl';

sub GetReplyForm { # $replyTo ; returns reply form for specified item
	my $replyTo = shift;
	chomp $replyTo;

	if (!$replyTo || !IsItem($replyTo)) {
		WriteLog('GetReplyForm: warning: sanity check failed');
		return '';
	}

	WriteLog('GetReplyForm: $replyTo = ' . $replyTo);

	my $replyTag = GetTemplate('html/replytag.template');
	my $replyForm = GetTemplate('form/write/reply.template');

	$replyTag =~ s/\$parentPost/$replyTo/g;
	$replyForm =~ s/\$replyTo/$replyTo/g;

	if (GetConfig('admin/php/enable') && !GetConfig('admin/php/rewrite')) {
		$replyForm =~ s/\/post\.html/\/post.php/g;
	}

	if (GetConfig('admin/js/enable')) {
		$replyForm = AddAttributeToTag(
			$replyForm,
			'input id=btnSendReply',
			'onclick',
#			"this.value='Meditate...';if(window.writeSubmit){return writeSubmit(this);}"
			"this.value = 'Meditate...'; if (window.writeSubmit) { setTimeout('writeSubmit();', 1); return true; } else { return true; }"
		);

		#todo the return value can be changed from false to true to issue two submissions, one signed and one not
		#		Use this line instead for improved delivery, but duplicate messages
		#			#todo merge the duplicates server-side
		#			"this.value = 'Meditate...'; if (window.writeSubmit) { setTimeout('writeSubmit();', 1); return false; } else { return true; }"


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
	} # GetConfig('admin/js/enable')

	$replyForm = GetWindowTemplate($replyForm, 'Reply');

	return $replyForm;
} # GetReplyForm();

sub GetItemHtmlLink { # $hash, [link caption], [#anchor] ; returns <a href=...
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

sub GetItemTagsSummary { # returns html with list of tags applied to item, and their counts
	my $fileHash = shift;

	if (!IsItem($fileHash)) {
		WriteLog('GetItemTagsSummary: warning: sanity check failed');
		return '';
	}

	WriteLog("GetItemTagsSummary($fileHash)");
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

sub GetWidgetExpand { # $parentCount, $url ; gets "More" button widget GetExpandWidget #more
	my $parentCount = shift; # how many levels of parents to go up
	# for example, for <table><tr><td><a>here it would be 3 layers instead of 1
	# accepts integers 1-10

	my $url = shift;
	# url to point the link to after the expand happens

	if (!$parentCount || !$url) {
		WriteLog('GetWidgetExpand: warning: sanity check failed');
		return '(More)';
	}

	my $widgetTemplate = GetTemplate('html/widget/more_button.template');

	if ($widgetTemplate) {
		# <a href="/etc.html">More</a>
		WriteLog('GetWidgetExpand: got template ok, going to fill it in');
		$widgetTemplate = str_replace('/etc.html', $url, $widgetTemplate);

		if (GetConfig('admin/js/enable')) {
			my $jsTemplate = "if (window.ShowAll && this.removeAttribute) { if (this.style) { this.style.display = 'none'; } return ShowAll(this, this.parentElement); } else { return true; }";
			if (
				$parentCount > 10 ||
				$parentCount < 1 ||
				!($parentCount =~ /\\D/)
			) {
				WriteLog('GetWidgetExpand: warning: $parentCount sanity check failed');
				if (GetConfig('admin/debug')) {
					return '(More2)';
				} else {
					return '';
				}
			} else {
				# adjust number of times it says ".parentElement"
				$jsTemplate = str_replace('.parentElement', str_repeat('.parentElement', $parentCount), $jsTemplate);
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
		return '(More3)';
	}

	return $widgetTemplate;
} # GetWidgetExpand() @16019xxxxx

sub GetQuickVoteButtonGroup {
	my $fileHash = shift;
	my $returnTo = shift;

	my $quickVotesButtons = '';
	if ($returnTo) {
		WriteLog('GetQuickVoteButtonGroup: $returnTo = ' . $returnTo);
		$quickVotesButtons = GetItemTagButtons($fileHash, $returnTo); #todo refactor to take vote totals directly
	} else {
		$quickVotesButtons = GetItemTagButtons($fileHash); #todo refactor to take vote totals directly
	}

	my $quickVoteButtonGroup = GetTemplate('vote/votequick2.template');
	$quickVoteButtonGroup =~ s/\$quickVotesButtons/$quickVotesButtons/g;

	return $quickVoteButtonGroup;
}

sub FormatMessage {
	my $message = shift;
	my %file = %{shift @_}; #todo should be better formatted
	#todo sanity checks

	if ($file{'remove_token'}) {
		my $removeToken = $file{'remove_token'};
		$message =~ s/$removeToken//g;
		$message = trim($message);
	}

	my $isTextart = 0;
	my $isSurvey = 0;
	my $isTooLong = 0;

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
	} else {
		# if not textart, just escape html characters
		WriteLog('FormatMessage: calling FormatForWeb');
		$message = FormatForWeb($message);
	}

	return $message;
}

#sub GetItemTemplate {
#	my %file = %{shift @_}; #todo should be better formatted
#
#	if (
#		defined($file{'file_hash'}) &&
#		defined($file{'item_type'})
#	) {
#		WriteLog('GetItemTemplate: sanity check passed, defined($file{file_path}');
#
#		if ($file{'item_type'} eq 'txt') {
#			my $message = GetItemDetokenedMessage($file{'file_hash'});
#			$message = FormatMessage($message, \%file);
#		}
#
#		my $itemTemplate = '';
#		{
#			my %windowParams;
#			$windowParams{'body'} = GetTemplate('html/item/item.template'); # GetItemTemplate()
#			$windowParams{'title'} = HtmlEscape($file{'item_title'});
#			$windowParams{'guid'} = substr(sha1_hex($file{'file_hash'}), 0, 8);
#
#			$windowParams{'body'} =~ s/\$itemText/$message/;
#
#			{
#				my $statusBar = '';
#
#				$statusBar .= GetItemHtmlLink($file{'file_hash'}, GetTimestampWidget($file{'add_timestamp'}));
#				$statusBar .= '; ';
#
#				$statusBar .= '<span class=advanced>';
#				$statusBar .= substr($file{'file_hash'}, 0, 8);
#				$statusBar .= '; ';
#				$statusBar .= '</span>';
#
#				if ($file{'author_key'}) {
#					$statusBar .= trim(GetAuthorLink($file{'author_key'}));
#					$statusBar .= '; ';
#				}
#
#				WriteLog('GetItemTemplate: ' . $file{'file_hash'} . ': $file{child_count} = ' . $file{'child_count'});
#
#				if ($file{'child_count'}) {
#					$statusBar .= '<a href="' . GetHtmlFilename($file{'file_hash'}) . '#reply">';
#					if ($file{'child_count'}) {
#						$statusBar .= 'reply(' . $file{'child_count'} . ')';
#					} else {
#						$statusBar .= 'reply';
#					}
#					$statusBar .= '</a>; ';
#				}
#
#				$statusBar .= GetItemTagButtons($file{'file_hash'}, 'all');
#				$windowParams{'status'} = $statusBar;
#			}
#
#			$windowParams{'content'} = $message;
#
#			$itemTemplate = GetWindowTemplate2(\%windowParams);
#		}
#		return $itemTemplate;
#
#	} else {
#		WriteLog('GetItemTemplate: sanity check FAILED, defined($file{file_path}');
#		return '';
#	}
#} # GetItemTemplate()

sub GetItemTemplate2 { # returns HTML for outputting one item
	WriteLog("GetItemTemplate2() begin");

	# %file(hash for each file)
	# file_path = file path including filename
	# file_hash = git's hash of the file's contents
	# author_key = gpg key of author (if any)
	# add_timestamp = time file was added as unix_time
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
		my $message = GetItemDetokenedMessage($file{'file_hash'}, $file{'file_path'});

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
				$message = substr($message, 0, $itemLongThreshold) . "\n" . '[...]';
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

			#todo there is a #bug here, but it is less significant than the majority of cases
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
			WriteLog('GetItemTemplate2: calling FormatForWeb');
			$message = FormatForWeb($message);
		}

		#if (index($message, "<br>\n--\n<br>\n") > -1) {
		if (GetConfig('html/hide_dashdash_signatures')) { # -- \n
			if (index($message, "<br>-- <br>") != -1) {
				$message =~ s/(.+)<br>-- <br>(.+)/$1<span class=admin><br>\n-- <br>\n$2<\/span>/smi;
				# /s = single-line (changes behavior of . metacharacter to match newlines)
				# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
				# /i = case-insensitive
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
			# what this does is replace [[example]] with
			# tag buttons for all the tags contained in
			# tagset/example
			$message =~ s/\[\[([a-z]+)\]\]/GetItemTagButtons($itemHash, $1)/ge;
			# REGEX cheatsheet
			# ================
			# /s = single-line (changes behavior of . metacharacter to match newlines)
			# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
			# /g = global (all instances)
			# /i = case-insensitive
			# /e = eval
		}

		WriteLog('GetItemTemplate2: $message is: ' . $message);

		#hint GetHtmlFilename()
		#todo verify that the items exist before turning them into links,
		# so that we don't end up with broken links
		# can be done here or in the function (return original text if no item)?
		#$message =~ s/([a-f0-9]{40})/GetItemHtmlLink($1)/eg;
		#$message =~ s/([a-f0-9]{40})/GetItemTemplateFromHash($1)/eg;

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
		my $fileHash = GetFileHash($file{'file_path'}); # get file's hash


		# initialize $itemTemplate for storing item output
		my $itemTemplate = '';
		{
			#return GetWindowTemplate ($param{'body'}, $param{'title'}, $param{'headings'}, $param{'status'}, $param{'menu'});
			my %windowParams;
			$windowParams{'body'} = GetTemplate('html/item/item.template'); # GetItemTemplate2()
			$windowParams{'title'} = HtmlEscape($file{'item_title'});
			$windowParams{'guid'} = substr(sha1_hex($file{'file_hash'}), 0, 8);
			# $windowParams{'headings'} = 'haedigns';

			{
				my $statusBar = GetTemplate("item/status_bar.template");

				my $fileHashShort = substr($fileHash, 0, 8);
				$statusBar =~ s/\$fileHashShort/$fileHashShort/g;

				if ($gpgKey) {
					# get author link for this gpg key
					my $authorLink = trim(GetAuthorLink($gpgKey));
					$statusBar =~ s/\$authorLink/$authorLink/g;
				} else {
					# if no author, no $authorLink
					$statusBar =~ s/\$authorLink;//g;
				}

				$windowParams{'status'} = $statusBar;
			}

			if (defined($file{'show_quick_vote'})) {
				$windowParams{'menu'} = GetQuickVoteButtonGroup($file{'file_hash'}, $file{'vote_return_to'});
			}

			$itemTemplate = GetWindowTemplate2(\%windowParams);
			$itemTemplate .= '<replies></replies>';
		}

		# $itemTemplate = str_replace(
		# 	'<span class=more></span>',
		# 	GetWidgetExpand(2, '#'),
		# 	$itemTemplate
		# );#todo fix broken
#
#		my $widgetExpandPlaceholder = '<span class=expand></span>';
#		if (index($itemTemplate, $widgetExpandPlaceholder) != -1) {
#			WriteLog('GetItemTemplate: $widgetExpandPlaceholder found in item: ' . $widgetExpandPlaceholder);
#
#			if (GetConfig('admin/js/enable')) {
#				# js on, insert widget
#
#				my $widgetExpand = GetWidgetExpand(5, GetHtmlFilename($itemHash));
#				$itemTemplate = str_replace(
#					'<span class=expand></span>',
#					'<span class=expand>' .	$widgetExpand .	'</span>',
#					$itemTemplate
#				);
#
#				# $itemTemplate = AddAttributeToTag(
#				# 	$itemTemplate,
#				# 	'a href="/etc.html"', #todo this should link to item itself
#				# 	'onclick',
#				# 	"if (window.ShowAll && this.removeAttribute) { this.removeAttribute('onclick'); return ShowAll(this, this.parentElement.parentElement.parentElement.parentElement.parentElement); } else { return true; }"
#				# );
#			} else {
#				# js off, remove placeholder for widget
#				$itemTemplate = str_replace($widgetExpandPlaceholder, '', $itemTemplate);
#			}
#		} # $widgetExpandPlaceholder

		my $authorUrl; # author's profile url
		my $authorAvatar; # author's avatar
		my $permalinkTxt = $file{'file_path'};

		{
		    #todo still does not work perfectly, this
			# set up $permalinkTxt, which links to the .txt version of the file

			# strip the 'html/' prefix on the file's path, replace with /
			#todo relative links
            my $HTMLDIR = GetDir('html');
			$permalinkTxt =~ s/$HTMLDIR\//\//;
			$permalinkTxt =~ s/^html\//\//;
		}

		# set up $permalinkHtml, which links to the html page for the item
		my $permalinkHtml = '/' . GetHtmlFilename($itemHash);
		#		my $permalinkHtml = '/' . substr($itemHash, 0, 2) . '/' . substr($itemHash, 2) . ".html";
		#		$permalinkTxt =~ s/^\.//;

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

		{ #todo refactor this to not have title in the template
			if ($file{'item_title'}) {
				my $itemTitle = HtmlEscape($file{'item_title'});
				$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			} else {
				$itemTemplate =~ s/\$itemTitle/Untitled/g;
			}
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

				my $textartContainer = GetTemplate('html/item/container/textart.template');
				$textartContainer =~ s/\$message/$itemText/g;

				$itemText = $textartContainer;
			}

			if ($isAdmin) {
				# if item is signed by an admin, add "admin" css class
				$itemClass .= ' byadmin';

				my $adminContainer = GetTemplate('html/item/container/admin.template');

				my $colorAdmin = GetThemeColor('admin') || '#c00000';
				$adminContainer =~ s/\$colorAdmin/$colorAdmin/g;

				$adminContainer =~ s/\$message/$itemText/g;

				$itemText = $adminContainer;
			} # $isAdmin
		} # $itemType eq 'txt'

		if ($itemType eq 'image') {
			if (GetConfig('admin/image/enable')) {
				my $imageContainer = GetTemplate('html/item/container/image.template');

				my $imageUrl = "/thumb/thumb_800_$fileHash.gif"; #todo hardcoding no
				# my $imageUrl = "/thumb/thumb_420_$fileHash.gif"; #todo hardcoding no
				my $imageSmallUrl = "/thumb/thumb_42_$fileHash.gif"; #todo hardcoding no
				my $imageAlt = $itemTitle;

				# $imageSmallUrl is a smaller image, used in the "lowsrc" attribute for img tag

				$imageContainer =~ s/\$imageUrl/$imageUrl/g;
				$imageContainer =~ s/\$imageSmallUrl/$imageSmallUrl/g;
				$imageContainer =~ s/\$imageAlt/$imageAlt/g;

				$itemText = $imageContainer;

				$itemClass = 'image';
			} else {
				$itemText = 'itemType eq image, but images disabled';
				WriteLog('$itemType eq image, but images disabled');
			}
		} # $itemType eq 'image'

		my $replyLink = $permalinkHtml . '#reply'; #todo this doesn't need the url before #reply if it is on the item's page

		if (index($itemText, '$') > -1) {
			# this is a kludge, should be a better solution
			#$itemText = '<code>item text contained disallowed character</code>';
			$itemText =~ s/\$/%/g;
		}

		$itemTemplate =~ s/\$borderColor/$borderColor/g;
		$itemTemplate =~ s/\$itemClass/$itemClass/g;
		$itemTemplate =~ s/\$itemName/$itemName/g;
		$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
		$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
		$itemTemplate =~ s/\$itemText/$itemText/g;
		$itemTemplate =~ s/\$fileHash/$fileHash/g;
		$itemTemplate =~ s/\$addedTime/$addedTime/g;
		$itemTemplate =~ s/\$replyLink/$replyLink/g;
		$itemTemplate =~ s/\$itemAnchor/$itemAnchor/g;

		if ($replyCount) {
			$itemTemplate =~ s/\$replyCount/$replyCount/g;
		} else {
			$itemTemplate =~ s/\$replyCount/0/g;
		}

		# if show_vote_summary is set, show a count of all the tags the item has
		if ($file{'show_vote_summary'}) {
			#this displays the vote summary (tags applied and counts)
			my %voteTotals = DBGetItemVoteTotals($file{'file_hash'});
			my $votesSummary = '';
			foreach my $voteTag (keys %voteTotals) {
				#todo templatize this
				$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
			}
			if ($votesSummary) {
				$votesSummary .= '<br>';
				#todo templatize
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
		} else {
			$itemTemplate =~ s/\$votesSummary//g;
		}

		my $itemFlagButton = '';
		if (defined($file{'vote_return_to'}) && $file{'vote_return_to'}) {
			WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemTagButtons($file{'file_hash'}, 'all', $file{'vote_return_to'}); #todo refactor to take vote totals directly
		} else {
			# WriteLog('GetItemTemplate: $file{\'vote_return_to\'} = ' . $file{'vote_return_to'});

			$itemFlagButton = GetItemTagButtons($file{'file_hash'}, 'all'); #todo refactor to take vote totals directly
		}

		$itemTemplate =~ s/\$itemFlagButton/$itemFlagButton/g;

		WriteLog('GetItemTemplate: return $itemTemplate');

		return $itemTemplate;
	} else {
		WriteLog('GetItemTemplate: warning: return empty string');
		return '';
	}
} # GetItemTemplate2()

sub GetPageFooter { # returns html for page footer
	WriteLog('GetPageFooter()');

	my $txtFooter = GetTemplate('html/htmlend.template');

	my $disclaimer = GetString('disclaimer');

	$txtFooter =~ s/\$disclaimer/$disclaimer/g;

	$txtFooter = FillThemeColors($txtFooter);

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/loading')) {
		$txtFooter = InjectJs2($txtFooter, 'after', '</html>', qw(loading_end));
	}

	if (GetConfig('html/back_to_top_button')) {
		# add back to top button to the bottom of the page, right before </body>
		my $backToTopTemplate = GetTemplate('html/widget/back_to_top_button.template');
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

	if (!defined($color) || $color eq '') {
		$color = '#00ff00';
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

	my $themeName = GetConfig('html/theme');
	if (substr($themeName, 0, 6) eq 'theme.') {
		# compatibility
		if (length($themeName) > 6) {
			$themeName = substr($themeName, 6);
		}
	}

	if (!ConfigKeyValid("theme/$themeName")) {
		WriteLog('GetThemeAttribute: warning: ConfigKeyValid("theme/$themeName") was false');
		$themeName = 'chicago';
	}

	my $attributePath = 'theme/' . $themeName . '/' . $attributeName;

	#todo sanity checks

	my $attributeValue = GetConfig($attributePath) || '';
	WriteLog('GetThemeAttribute: ' . $attributeName . ' -> ' . $attributePath . ' -> ' . $attributeValue);

	return trim($attributeValue);
} # GetThemeAttribute()

sub FillThemeColors { # $html ; fills in templated theme colors in provided html
	my $html = shift;
	chomp($html);

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
	#
	# my $colorWindow = GetThemeColor('window');
	# $html =~ s/\$colorWindow/$colorWindow/g;

	my $colorDialogHeading = GetThemeColor('dialog_heading');
	$html =~ s/\$colorDialogHeading/$colorDialogHeading/g;

	my @colors = qw(primary secondary background text link vlink window);
	for my $color (@colors) {
		#todo my @array1 = map ucfirst, @array;
		my $templateToken = '$color' . ucfirst($color);
		$html = str_replace($templateToken, GetThemeColor($color), $html);
	}
	# there are two issues with replacing below with above
	# a) searching for template token in code wouldn't find this section
	# b)
	# my $colorPrimary = GetThemeColor('primary');
	# $html =~ s/\$colorPrimary/$colorPrimary/g;
	#
	# my $colorSecondary = GetThemeColor('secondary');
	# $html =~ s/\$colorSecondary/$colorSecondary/g;
	#
	# my $colorBackground = GetThemeColor('background');
	# $html =~ s/\$colorBackground/$colorBackground/g;
	#
	# my $colorText = GetThemeColor('text');
	# $html =~ s/\$colorText/$colorText/g;
	#
	# my $colorLink = GetThemeColor('link');
	# $html =~ s/\$colorLink/$colorLink/g;
	#
	# my $colorVlink = GetThemeColor('vlink');
	# $html =~ s/\$colorVlink/$colorVlink/g;

	return $html;
} # FillThemeColors()

sub WriteMenuList { # writes config/list/menu based on site configuration
	#todo this function is not obvious, overrides obvious list/menu
	my @menu;

	push @menu, 'read';
	push @menu, 'write';

	if (GetConfig('admin/php/quickchat')) {
		push @menu, 'chat';
	}

	#upload
	if (GetConfig('admin/php/enable') && GetConfig('admin/upload/enable')) {
		# push @menu, 'art';
		push @menu, 'upload';
	}

	#push @menu, 'stats';
#
#	#profile
#	if (GetConfig('admin/js/enable') || GetConfig('admin/php/enable')) {
#		# one of these is required for profile to work
#		push @menu, 'profile';
#	} else {
#		#todo make it disabled or something
#		push @menu, 'profile';
#	}
	push @menu, 'help';

	###

	my $menuList = join("\n", @menu);

	PutConfig('list/menu', $menuList);
	# PutConfig('list/menu_advanced', $menuList);

	GetConfig('list/menu', 'unmemo');
	# GetConfig('list/menu_advanced', 'unmemo');
} # WriteMenuList()

sub GetMenuFromList { # $listName, $templateName = 'html/menuitem.template'; returns html menu based on referenced list
# $listName is reference to a list in config/list, e.g. config/list/menu
# $separator is what is inserted between menu items

	state $wroteMenu;
	if (!$wroteMenu) {
		WriteMenuList();
		$wroteMenu = 1;
	}

	my $listName = shift;
	chomp $listName;
	if (!$listName) {
		WriteLog('GetMenuFromList: warning: $listName failed sanity check');
		return;
	}

	my $templateName = shift;
	if (!$templateName) {
		$templateName = 'html/menuitem.template';
	}
	chomp $templateName;

	WriteLog('GetMenuFromList: $listName = ' . $listName . ', $templateName = ' . $templateName);

	my $listText = GetConfig('list/' . $listName); #list/menu
	$listText = str_replace(' ', "\n", $listText);
	$listText = str_replace("\n\n", "\n", $listText);
	my @menuList = split("\n", $listText);

	my $menuItems = ''; # output html which will be returned

	foreach my $menuItem (@menuList) {
		my $menuItemName = $menuItem;
		if ($menuItemName) {
			my $menuItemUrl = '/' . $menuItemName . '.html';
			# capitalize caption
			my $menuItemCaption = uc(substr($menuItemName, 0, 1)) . substr($menuItemName, 1);

			if ($listName eq 'menu_tag') {
				$menuItemUrl = '/top/' . $menuItemName . '.html';
				$menuItemCaption = '#' . $menuItemName;
			}

			# this avoids creating duplicate urls but currently breaks light mode
			# if ($menuItemName eq 'index') {
			# 	$menuItemUrl = '/';
			# }

			# add menu item to output
			$menuItems .= GetMenuItem($menuItemUrl, $menuItemCaption, $templateName);
		}
	}

	# return template we've built
	return $menuItems;
} # GetMenuFromList()

sub GetClockWidget {
	my $clock = '';
	if (GetConfig('html/clock')) {
		WriteLog('GetPageHeader: html/clock is enabled');
		my $currentTime = GetClockFormattedTime();
		if (GetConfig('admin/ssi/enable') && GetConfig('admin/ssi/clock_enhance')) {
			# ssi-enhanced clock
			# currently not compatible with javascript clock
			WriteLog('GetPageHeader: ssi is enabled');
			$clock = GetTemplate('html/widget/clock_ssi.template');
			$clock =~ s/\$currentTime/$currentTime/g;
		}
		else {
			# default clock
			$clock = GetTemplate('html/widget/clock.template');
			$clock =~ s/\$currentTime/$currentTime/;

			my $sizeConfig = GetConfig('html/clock_format');
			if ($sizeConfig eq '24hour') {
				$sizeConfig = 6;
			} elsif ($sizeConfig eq 'epoch') {
				$sizeConfig = 11;
			} elsif ($sizeConfig eq 'union') {
				$sizeConfig = 15;
			} else {
				$sizeConfig = 15;
			}
			if ($sizeConfig) {
				$clock = str_replace('size=15', "size=$sizeConfig", $clock);
			}
		}
		#
#		$currentTime = trim($currentTime);
	} else {
		# the plus sign is to fill in the table cell
		# othrwise netscape will not paint its background color
		# and there will be a hole in the table
		$clock = '+';
	}

	WriteLog('GetClockWidget: $clock = ' . $clock);

	return $clock;
}

sub GetMenuTemplate { # returns menubar
	my $topMenuTemplate = GetTemplate('html/topmenu2.template');
	if (GetConfig('admin/js/enable')) {
		$topMenuTemplate = AddAttributeToTag(
			$topMenuTemplate,
			'a href="/etc.html"',
			'onclick',
			"if (window.ShowAll) { ShowAll(this); } if (window.DraggingInit) { DraggingInit(0); } return false;"
		); # &pi;
	}

	my $selfLink = '/access.html';
	my $menuItems = GetMenuFromList('menu');
	my $menuItemsTag = GetMenuFromList('menu_tag');
	my $menuItemsAdvanced = GetMenuFromList('menu_advanced');

	$topMenuTemplate =~ s/\$menuItemsAdvanced/$menuItemsAdvanced/g;
	$topMenuTemplate =~ s/\$menuItemsTag/$menuItemsTag/g;
	$topMenuTemplate =~ s/\$menuItems/$menuItems/g;
	$topMenuTemplate =~ s/\$selfLink/$selfLink/g;

	if (GetConfig('html/clock')) {
		my $clockTemplate = GetClockWidget();
		$topMenuTemplate = '<form action="/stats.html" name=frmTopMenu>' . $topMenuTemplate . '</form>';
		$topMenuTemplate =~ s/<span id=spnClock><\/span>/$clockTemplate/g;
	}

	return $topMenuTemplate;
} # GetMenuTemplate()

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

	my $txtIndex = "";
	my $styleSheet = GetStylesheet();

	my $patternName = trim(GetConfig('header_pattern'));
	my $introText = trim(GetString('page_intro/' . $pageType));
	if (!$introText) {
		$introText = trim(GetString('page_intro/default'));
	}

	# Get the HTML page template
	my $htmlStart = GetTemplate('html/htmlstart.template');
	# and substitute $title with the title

	if (GetConfig('admin/offline/enable')) {
		$htmlStart = AddAttributeToTag(
			$htmlStart,
			'html',
			'manifest',
			'/cache.manifest'
		);
	}

	#top menu
						  
	my $identityLink = '<span id="signin"><a href="/profile.html">Go to profile</a></span> <span class="myid" id=myid></span> ';
#	my $noJsIndicator = '<noscript><a href="/profile.html">Profile</a></noscript>';
	#todo profile link should be color-underlined like other menus
	{
		if (GetConfig('logo_enabled')) {
			state $logoText;
			if (!defined($logoText)) {
				$logoText = GetConfig('logo_text');
				if (!$logoText) {
					$logoText = '';
				}
			}
			my $logoTemplate = GetWindowTemplate('<a href="/" class=logo>Home</a>', $logoText);
			$htmlStart .= $logoTemplate;
		}
	}

	my $topMenuTemplate = GetMenuTemplate();

	if ($pageType ne 'item') {
		$htmlStart =~ s/\$topMenu/$topMenuTemplate/g;
	} else {
		$htmlStart =~ s/\$topMenu//g;
	}

	$htmlStart =~ s/\$styleSheet/$styleSheet/g;
	$htmlStart =~ s/\$titleHtml/$titleHtml/g;
	$htmlStart =~ s/\$title/$title/g;

	$htmlStart =~ s/\$introText/$introText/g;

	if (GetConfig('admin/js/enable') && GetConfig('admin/js/loading')) {
		$htmlStart = InjectJs2($htmlStart, 'after', '<body>', qw(loading_begin));
	}

	$htmlStart = FillThemeColors($htmlStart);

	$txtIndex .= $htmlStart;

	return $txtIndex;
}

sub GetItemListing { # returns listing of items based on topic
	my $htmlOutput = '';

	my @topItems;

	my $fileHash = shift;
	my $title = 'Welcome, Guest!';

	if (!$fileHash) {
		$fileHash = 'top';
	}

	if ($fileHash eq 'top') {
		@topItems = DBGetTopItems(); # get top items from db
	} else {
		@topItems = DBGetItemReplies($fileHash);
		$title = 'Replies';
	}

	if (!@topItems) {
		WriteLog('GetItemListing: warning @topItems missing, sanity check failed');
		return '';
	}

	my $itemCount = scalar(@topItems);

	if ($itemCount) {
	# at least one item returned

		my $itemListingWrapper = GetTemplate('html/item_listing_wrapper2.template');

		my $itemListings = '';

		my $rowBgColor = ''; # stores current value of alternating row color
		my $colorRow0Bg = GetThemeColor('row_0'); # color 0
		my $colorRow1Bg = GetThemeColor('row_1'); # color 1

		while (@topItems) {
			my $itemTemplate = GetTemplate('html/item_listing.template');
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

			my $itemLastTouch = DBGetItemLatestAction($itemKey); #todo add to itemfields

			my $itemTitle = $item{'item_title'};
			if (trim($itemTitle) eq '') {
				# if title is empty, use the item's hash
				# $itemTitle = '(' . $itemKey . ')';
				$itemTitle = 'Untitled';
			}
			$itemTitle = HtmlEscape($itemTitle);

			my $itemLink = '/'.GetHtmlFilename($itemKey); #todo this is a bandaid

			my $authorAvatar;
			if ($authorKey) {
#				$authorAvatar = GetPlainAvatar($authorKey);
				my $authorLink = GetAuthorLink($authorKey, 1);
				if ($authorLink) {
					$authorAvatar = GetAuthorLink($authorKey, 1);
#					$authorAvatar = 'by ' . GetAuthorLink($authorKey, 1);
				} else {
					$authorAvatar = 'Unsigned';
				}
			} else {
				$authorAvatar = 'Unsigned';
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

		my $columnHeadings = 'title,author,activity';

		$itemListingWrapper = GetWindowTemplate(
			$itemListings,
			$title,
			$columnHeadings,
			$statusText
		);

		$htmlOutput .= $itemListingWrapper;
	} else {
	# no items returned, use 'no items' template
		$htmlOutput .= GetWindowTemplate(GetTemplate('html/item/no_items.template'), 'Welcome, Guest!');
		#todo add menu?
	}

	return $htmlOutput;
} # GetItemListing()

sub GetTopItemsPage { # returns page with top items listing
	WriteLog("GetTopItemsPage()");

	my $htmlOutput = ''; # stores the html

	my $title = 'Topics';
	my $titleHtml = 'Topics';

	$htmlOutput = GetPageHeader($title, $titleHtml, 'read'); # <html><head>...</head><body>
	$htmlOutput .= GetTemplate('html/maincontent.template'); # where "skip to main content" goes

	$htmlOutput .= GetItemListing('top');

	$htmlOutput .= GetPageFooter(); # </body></html>

	if (GetConfig('admin/js/enable')) {
		# add necessary js
		$htmlOutput = InjectJs($htmlOutput, qw(settings voting timestamp profile avatar utils));
	}

	return $htmlOutput;
} #GetTopItemsPage

sub GetItemPrefixPage { # $prefix ; returns page with items matching specified prefix
	WriteLog("GetItemPrefixPage()");

	my $prefix = shift;
	if (!IsItemPrefix($prefix)) {
		WriteLog('GetItemPrefixPage: warning: $prefix sanity check failed');
		return '';
	}

	WriteLog('GetItemPrefixPage: $prefix = ' . $prefix);

	my $htmlOutput = ''; # stores the html

	my $title = 'Items matching ' . $prefix;
	my $titleHtml = 'Items matching ' . $prefix;

	$htmlOutput = GetPageHeader($title, $titleHtml, 'prefix'); # <html><head>...</head><body>
	$htmlOutput .= GetTemplate('html/maincontent.template'); # where "skip to main content" goes

	my @topItems = DBGetItemsByPrefix($prefix); # get top items from db

	my $itemCount = scalar(@topItems);

	WriteLog('GetItemPrefixPage: $itemCount = ' . $itemCount);

	if ($itemCount) {
	# at least one item returned
		my $itemListingWrapper = GetTemplate('html/item_listing_wrapper2.template');

		my $itemListings = '';

		my $rowBgColor = ''; # stores current value of alternating row color
		my $colorRow0Bg = GetThemeColor('row_0'); # color 0
		my $colorRow1Bg = GetThemeColor('row_1'); # color 1

		if (scalar(@topItems)) {
			WriteLog('GetItemPrefixPage: scalar(@topItems) was true');
		} else {
			WriteLog('GetItemPrefixPage: warning: scalar(@topItems) was false');
		}

		while (@topItems) {
			my $itemTemplate = GetTemplate('html/item_listing.template');
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

			my $itemLastTouch = DBGetItemLatestAction($itemKey); #todo add to itemfields

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
					$authorAvatar = GetAuthorLink($authorKey, 1);
#					$authorAvatar = 'by ' . GetAuthorLink($authorKey, 1);
				} else {
					$authorAvatar = 'Unsigned';
				}
			} else {
				$authorAvatar = 'Unsigned';
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
		my $columnHeadings = 'title,author,activity';

		$itemListingWrapper = GetWindowTemplate(
			$itemListings,
			'Items prefixed ' . $prefix,
			$columnHeadings,
			$statusText,
			''
		);

		$htmlOutput .= $itemListingWrapper;
	} else {
	# no items returned, use 'no items' template
		$htmlOutput .= GetTemplate('html/item/no_items.template');
	}

	$htmlOutput .= GetPageFooter(); # </body></html>

	if (GetConfig('admin/js/enable')) {
		# add necessary js
		$htmlOutput = InjectJs($htmlOutput, qw(settings voting timestamp profile avatar utils));
	}

	return $htmlOutput;
} # GetItemPrefixPage()

sub GetStatsTable {
	my $templateName = shift;
	if (!$templateName) {
		$templateName = 'html/stats.template';
	}

	state $itemsIndexed; $itemsIndexed = $itemsIndexed || DBGetItemCount();
	my $authorCount = DBGetAuthorCount();

#	my $adminId = GetRootAdminKey();
#	my $adminUsername = GetAlias($adminId);
#	my $adminLink = GetAuthorLink($adminId);

	my $adminId = '';#GetRootAdminKey();
	my $adminUsername = '';#GetAlias($adminId);
	my $adminLink = '';#GetAuthorLink($adminId);

	my $serverId = '';#GetServerKey();
	my $serverLink = GetAuthorLink($serverId);

	my $versionFull = GetMyVersion();
	my $versionShort = substr($versionFull, 0, 8);

	UpdateUpdateTime();
	my $lastUpdateTime = GetCache('system/last_update_time');
	$lastUpdateTime = GetTimestampWidget($lastUpdateTime);

	my $lastBuildTime = GetConfig('admin/build_end');
	if (!defined($lastBuildTime) || !$lastBuildTime) {
		$lastBuildTime = 0;
	}

	###

	my $statsTable = GetTemplate($templateName);

	if ($adminId) {
		if ($adminUsername eq 'Operator' && $templateName eq 'html/stats-horizontal.template') {
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
	WriteLog('GetStatsTable: $filesTotal = 0');

	my $TXTDIR = GetDir('txt');

	if ($TXTDIR =~ m/^([^\s]+)$/) { #security #taint
		$TXTDIR = $1;
		my $findResult = `find $TXTDIR -name \\\*.txt | wc -l`;
		if ($findResult =~ m/(.+)/) { #todo add actual check of some kind
			$findResult = $1;
			my $filesTxt = trim($findResult); #todo cache GetCache('count_txt')
			PutCache('count_txt', $filesTxt);
			WriteLog('GetStatsTable: $filesTotal (' . $filesTotal . ') += $filesTxt (' . $filesTxt . ');');
			$filesTotal += $filesTxt;
		}
	} else {
		WriteLog('GetStatsTable: warning: sanity check failed: $TXTDIR contains space');
	}

	if (GetConfig('admin/image/enable')) {
		my $IMAGEDIR = GetDir('image');
		if ($IMAGEDIR =~ m/^([^\s]+)$/) { #security #taint
			$IMAGEDIR = $1;
			my $imagesFindResults = `find $IMAGEDIR -name \\\*.png -o -name \\\*.jpg -o -name \\\*.gif -o -name \\\*.bmp -o -name \\\*.jfif -o -name \\\*.webp -o -name \\\*.svg | wc -l`;
			chomp $imagesFindResults;
			if ($imagesFindResults =~ m/^[0-9]+$/) {
				my $filesImage =  GetCache('count_image') || trim($imagesFindResults);
				PutCache('count_image', $filesImage);
				WriteLog('GetStatsTable: $filesTotal (' . $filesTotal . ') += $filesImage (' . $filesImage . ');');
				$filesTotal += $filesImage;
			} else {
				WriteLog('GetStatsTable: warning: sanity check failed getting image count');
			}
		} else {
			WriteLog('GetStatsTable: warning: sanity check failed: $IMAGEDIR contains space');
		}
	}

	my $chainLogLength = 0;
	if (GetConfig('admin/logging/write_chain_log')) {
		$chainLogLength = `wc -l html/chain.log`;
	}

	if (abs($itemsIndexed - $filesTotal) > 3) {
		$statsTable = str_replace('<p id=diagnostics></p>', '<p id=diagnostics><font color=orange><b>Check engine!</b></font></p>', $statsTable);
	}

	my $tagsTotal = DBGetTagCount();
	if (!$tagsTotal) {
		WriteLog('GetStatsTable: warning: $tagsTotal was false');
		$tagsTotal = 0;
	}

	#todo optimize
	#todo config/admin/upload/allow_files

	$lastBuildTime = GetTimestampWidget($lastBuildTime);
	$statsTable =~ s/\$lastBuildTime/$lastBuildTime/;

	$statsTable =~ s/\$tagsTotal/$tagsTotal/;
	$statsTable =~ s/\$versionFull/$versionFull/;
	$statsTable =~ s/\$versionShort/$versionShort/;
	$statsTable =~ s/\$itemsIndexed/$itemsIndexed/;
	$statsTable =~ s/\$authorCount/$authorCount/;
	$statsTable =~ s/\$filesTotal/$filesTotal/;
	$statsTable =~ s/\$chainLogLength/$chainLogLength/;

	if ($templateName eq 'html/stats.template') {
		$statsTable = GetWindowTemplate($statsTable, 'Stats');
		#todo remove this once other template is fixed
	}

	return $statsTable;
}

sub GetStatsPage { # returns html for stats page
	my $statsPage;

	$statsPage = GetPageHeader('Stats', 'Stats', 'stats');

	$statsPage .= GetTemplate('html/maincontent.template');
	my $statsTable = GetStatsTable();
	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	$statsPage = InjectJs($statsPage, qw(utils settings avatar timestamp pingback profile));

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
	}
	elsif ($debugType eq 'document.title') {
		$scriptTemplate =~ s/\/\/alert\('DEBUG:/document.title=('DEBUG:/gi;
	}
	else {
		$scriptTemplate =~ s/\/\/alert\('DEBUG:/if(!window.dbgoff)dbgoff=!confirm('DEBUG:/gi;
	}

	return $scriptTemplate;
} # EnableJsDebug()

sub InjectJs { # $html, @scriptNames ; inject js template(s) before </body> ;
	my $html = shift;     # html we're going to inject into

	if (!$html || trim($html) eq '') {
		WriteLog('InjectJs: warning: $html is missing, returning');
		return '';
	}

	if (!GetConfig('admin/js/enable')) {
		# if js is disabled globally, abort
		WriteLog('InjectJs: warning: InjectJs() called when admin/js/enable is false');
		return $html;
	}

	my @scriptNames = @_; # array of names of script templates (minus the .js suffix)
	my $scriptsText = '';  # will contain all the js we want to inject
	my $scriptsComma = ''; # separator between scripts, will be set to \n\n after first script
	my %scriptsDone = ();  # hash to keep track of scripts we've already injected, to avoid duplicates

	if (in_array('settings', @scriptNames)) {
		if (GetConfig('admin/js/enable') && GetConfig('admin/js/fresh')) {
			# if fresh_js is enabled, automatically add it
			#todo move this upwards, shouldn't be decided here
			push @scriptNames, 'fresh';
		}

		if (GetConfig('admin/js/dragging')) {
			push @scriptNames, 'dragging';
		}
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

		my $scriptTemplate = GetScriptTemplate("$script");
		# add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	my $needOnload = 0; # remember if we need to add <body onload attribute later
	{
		# if script we are injecting contains "OnLoadEverything",
		# we will need to add it to the <body onload attribute later
		if (index($scriptsText, 'OnLoadEverything') != -1) {
			$needOnload = 1;
		}
	}

	# get the wrapper, i.e. <script>$javascript</script>
	my $scriptInject = GetTemplate('html/utils/scriptinject.template');
	# fill in the wrapper with our scripts from above
	$scriptInject =~ s/\$javascript/$scriptsText/g; #todo why is this /g ??

	$scriptInject = "\n" . '<!-- InjectJs: ' . $scriptNamesList . ' -->' . "\n\n" . $scriptInject;

	if (index($html, '</body>') > -1) {
		# replace it into html, right before the closing </body> tag
		$html =~ s/<\/body>/$scriptInject<\/body>/;
	} else {
		# if there was no </body> tag, just append at the end
		$html .= "\n\n" . $scriptInject;
		WriteLog('InjectJs(): warning: $html does not contain </body>');
	}

	if ($needOnload) {
		# remember, we need to add <body onload event
		if ($html =~ m/<body.*?onload.*?>/i) {
			# <body already has onload, forget about it
		} else {
			if (index($html, '<body') != -1) {
				# add onload attribute to body tag
				$html = AddAttributeToTag(
					$html,
					'body',
					'onload',
					'if (window.OnLoadEverything) { OnLoadEverything(); }'
				);
				$html = AddAttributeToTag(
					$html,
					'body',
					'onclick',
					"if (event.target && (event.target.tagName == 'A') && !(event.target.onclick)) { ShowPreNavigateNotification(); }"
				);
			} else {
				WriteLog('InjectJs(): warning: wanted to $html does not contain <body');
			}
		}
	}

	my $needOnUnload = 1;
	if ($needOnUnload) {
		# remember, we need to add <body onunload event
		if ($html =~ m/<body.*?onbeforeunload.*?>/i) {
			# <body already has onunload, forget about it
		} else {
			if (index($html, '<body') != -1) {
				# add onload attribute to body tag
				$html = AddAttributeToTag(
					$html,
					'body',
					'onbeforeunload',
					'if (window.ShowPreNavigateNotification){ ShowPreNavigateNotification();}'
#					'if (window.OnUnloadEverything) { OnUnloadEverything(); }'
				);
			} else {
				WriteLog('InjectJs(): warning: wanted to $html does not contain <body');
			}
		}
	}

	return $html;
} # InjectJs()

sub GetScriptTemplate { # $script ; returns script for name
# default/template/js/$script.js
# config/template/js/$script.js
# fills in theme colors and server-side settings
	my $script = shift;

	#todo sanity

	my $scriptTemplate = GetTemplate("js/$script.js");

	if (!$scriptTemplate) {
		WriteLog("InjectJs: WARNING: Missing script contents for $script");
	}

	if ($script eq 'fresh') {
		#todo this should work for all admins, not just root
		# for profile.js we need to fill in current admin id
		if (GetConfig('admin/dev/fresh_reload')) {
			$scriptTemplate =~ s/freshUserWantsReload = 0/freshUserWantsReload = 1/g;
		}
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

		WriteLog('InjectJs: puzzle: $puzzlePrefix = ' . $puzzlePrefix);
		WriteLog('InjectJs: puzzle: $puzzleCycleLimit = ' . $puzzleCycleLimit);

		$scriptTemplate =~ s/var lookingFor = '1337';/var lookingFor = '$puzzlePrefix';/g;
		$scriptTemplate =~ s/var cycleLimit = 1000000;/var cycleLimit = $puzzleCycleLimit;/g;
	}

	if ($script eq 'profile') {
		#todo this should work for all admins, not just root
		# for profile.js we need to fill in current admin id
		my $currentAdminId = '';#GetRootAdminKey() || '-';
		#todo this whole thing should change to include non-root admins
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
		WriteLog('GetScriptTemplate: warning: Inject script "' . $script . '" contains > character');
	}

	if (GetConfig('admin/js/debug')) {
		#uncomment all javascript debug alert statements
		#and replace them with confirm()'s which stop on no/cancel
		$scriptTemplate = EnableJsDebug($scriptTemplate);
	}

	return $scriptTemplate;
}

sub InjectJs2 { # $html, $injectMode, $htmlTag, @scriptNames, ; inject js template(s) before </body> ;
#todo, once i figure out how to pass an array and/or need this in perl:
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

	if (in_array('settings', @scriptNames)) {
		if (GetConfig('html/clock')) {
			# if clock is enabled, automatically add its js
			push @scriptNames, 'clock';
		}
		if (GetConfig('admin/js/fresh')) {
			# if clock is enabled, automatically add it
			push @scriptNames, 'fresh';
		}
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

		my $scriptTemplate = GetScriptTemplate($script);

		# add to the snowball of javascript
		$scriptsText .= $scriptTemplate;
	}

	# get the wrapper, i.e. <script>$javascript</script>
	my $scriptInject = GetTemplate('html/utils/scriptinject.template');
	# fill in the wrapper with our scripts from above
	$scriptInject =~ s/\$javascript/$scriptsText/g; #todo why is this /g ??

	$scriptInject = "\n" . '<!-- InjectJs2: ' . $scriptNamesList . ' -->' . "\n\n" . $scriptInject;

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

sub GetTopAuthorsWindow {
	WriteLog('GetTopAuthorsWindow() begin');

	my @topAuthors = DBGetTopAuthors();
	my $authorListings = '';

	while (@topAuthors) {
		# get the friend's key
		my $authorRef = shift @topAuthors;
		my %author = %{$authorRef};

		my $authorKey = $author{'author_key'};
		my $authorAlias = $author{'author_alias'};
		my $authorLastSeen = $author{'last_seen'};
		my $authorItemCount = $author{'item_count'};
		my $authorAvatar = GetHtmlAvatar($authorKey) || $authorKey;

		my $authorLink = GetAuthorLink($authorKey) || '(blank)';
#		my $authorFriendKey = $authorFriend->{'author_key'};
		my $authorItemTemplate = GetTemplate('html/author_listing.template');
#
		if ($authorLastSeen) {
			$authorLastSeen = GetTimestampWidget($authorLastSeen);
		} else {
			$authorLastSeen = '(unknown)';
		}
		if (!$authorLastSeen) {
			$authorLastSeen = '*';
		}
		#$authorLastSeen = GetSecondsHtml(GetTime() - $authorLastSeen) . ' ago';

		$authorItemTemplate =~ s/\$authorLink/$authorLink/g; #todo $authorLink can sometimes be uninitialized here, #bug
		$authorItemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
		$authorItemTemplate =~ s/\$authorLastSeen/$authorLastSeen/g;
		$authorItemTemplate =~ s/\$authorItemCount/$authorItemCount/g;
		$authorItemTemplate =~ s/\$authorKey/$authorKey/g;

		$authorListings .= $authorItemTemplate;
	}

	my $window = GetWindowTemplate($authorListings, 'Authors', 'name,seen', '', '');

	return $window;
} # GetTopAuthorsWindow()

sub GetAuthorsPage {
	WriteLog('GetAuthorsPage() begin');

	my $html = '';
	my $title = 'Authors';
	$html .= GetPageHeader($title, $title, 'scoreboard');
	$html .= GetTemplate('html/maincontent.template');

	$html .= GetTopAuthorsWindow();

	$html .= GetPageFooter();
	$html = InjectJs($html, qw(utils settings avatar timestamp profile voting));
	return $html;
}

sub GetAuthorInfoBox {
	my $authorKey = shift;
	chomp $authorKey;

	if (!$authorKey) {
		return '';
	}

	my $authorInfoTemplate = GetTemplate('html/author_info.template');
	$authorInfoTemplate = FillThemeColors($authorInfoTemplate);

	my $authorAliasHtml = GetAlias($authorKey);
	my $authorAvatarHtml = GetAvatar($authorKey);
	my $authorImportance = 1;
	my $authorScore = '';#DBGetAuthorScore($authorKey) || 0;
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

	if (IsAdmin($authorKey)) {
		if ($authorDescription) {
			$authorDescription .= '<br>';
		}

		my $descText = '<b>Admin.</b>';
		my $adminContainer = GetTemplate('html/item/container/admin.template');
		my $colorAdmin = GetThemeColor('admin') || '#c00000';
		$adminContainer =~ s/\$colorAdmin/$colorAdmin/g;
		$adminContainer =~ s/\$message/$descText/g;

		$authorDescription = $adminContainer;
	}

	if ($authorDescription) {
		$authorDescription .= '<br>';
	}
	$authorDescription .= GetItemTagsSummary($publicKeyHash);

	my $profileVoteButtons = GetItemTagButtons($publicKeyHash, 'pubkey');

	$authorLastSeen = GetTimestampWidget($authorLastSeen) || '*';

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
			#$queryParams{'join_clause'} = "JOIN vote ON (item_flat.file_hash = vote.file_hash)";
			#$queryParams{'group_by_clause'} = "GROUP BY vote.file_hash";
			#$queryParams{'where_clause'} = "WHERE vote.vote_value = '$tagName'";
			$queryParams{'where_clause'} = "WHERE ','||tags_list||',' LIKE '%,$tagName,%' AND item_score > 0";
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

	$txtIndex .= GetTemplate('html/maincontent.template');
	if ($pageType eq 'author') {
		# author info box
		$txtIndex .= GetAuthorInfoBox($authorKey);
	}
	my $itemComma = '';

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		WriteLog('GetReadPage: calling DBAddItemPage (1)');
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

			my $alias;
			my $isAdmin = 0;
			my $message;
			my $messageCacheName = GetMessageCacheName($itemHash);

			WriteLog('GetReadPage: $row->{file_hash} = ' . $row->{'file_hash'});
			if ($gpgKey) {
				WriteLog('GetReadPage: $message = GetFile('.$messageCacheName.')');
				$message = GetFile($messageCacheName);
			} else {
				WriteLog('GetReadPage: $message = GetFile('.$file.')');
				$message = GetFile($file);
			}
			if (!$message) {
				WriteLog('GetReadPage: warning: $message is false!');
			} else {
				WriteLog('GetReadPage: $message is true!');
			}

			#$message = FormatForWeb($message);
			my $signedCss = "";
			if ($isSigned) {
				if (IsAdmin($gpgKey)) {
					$isAdmin = 1;
				}
				if ($isAdmin) {
					$signedCss = "signed admin";
				} else {
					$signedCss = "signed";
				}
			} # $isSigned

			#todo $alias = GetAlias($gpgKey);

			$alias = HtmlEscape($alias);

			my $itemTemplate = '';
			if ($message) {
#				$row->{'show_quick_vote'} = 1;
				$row->{'trim_long_text'} = 1;

				WriteLog('GetReadPage: GetItemTemplate2($row)');

				$itemTemplate = GetItemTemplate2($row); # GetReadPage()
			}
			else {
				$itemTemplate = GetItemTemplate2($row); # GetReadPage()
				WriteLog('GetReadPage: warning: missing $message');
			}

			if ($itemComma eq '') {
				$itemComma = '<br><hr size=7>';
			} else {
				$itemTemplate = $itemComma . $itemTemplate;
			}

			$txtIndex .= $itemTemplate;
		} # $file
		else {
			WriteLog('GetReadPage: warning: file not found, $file = ' . $file);
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

	return $txtIndex;
} # GetReadPage()

sub GetItemListHtml { # @files(array of hashes) ; takes @files, returns html list
	my $filesArrayReference = shift; # array of hash refs which contains items
	if (!$filesArrayReference) {
		WriteLog('GetItemList: warning: sanity check failed, missing $filesArrayReference');
		return 'problem getting item list, my apologies. (1)';
	}
	my @files = @$filesArrayReference; # de-reference
	if (!scalar(@files)) {
		WriteLog('GetItemList: warning: sanity check failed, missing @files');
		return 'problem getting item list, my apologies. (2)';
	}

	my $itemList = '';
	my $itemComma = '';

	my $itemListTemplate = '<span class=itemList>$itemList</span>'; #todo templatize

	foreach my $row (@files) { # loop through each file
		my $file = $row->{'file_path'};

		if ($file && -e $file) { # file exists
			my $itemHash = $row->{'file_hash'};

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
			$itemTemplate = GetItemTemplate2($row); # GetIndexPage()

			$itemList = $itemList . $itemComma . $itemTemplate;

			if ($itemComma eq '') {
				$itemComma = '<hr><br>';
				# $itemComma = '<p>';
			}
		}
	}

	$itemListTemplate = str_replace('$itemList', $itemList, $itemListTemplate);

	return $itemListTemplate;
} # GetItemListHtml()

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
	$html .= GetTemplate('html/maincontent.template');

	my $itemList = ''; # the "filling" part of the page, with all the items templated
	my $itemComma = ''; # separator between items

	#DBAddItemPage($itemHash, 'index', $currentPageNumber); #todo

	$itemList = GetItemListHtml(\@files);
	#$itemList = 'sup';

	$html .= $itemList;

	$html .= '<p>';

	if (defined($currentPageNumber)) {
		$html .= GetPageLinks($currentPageNumber);
	}

	# Close html
	$html .= GetPageFooter();
	$html = InjectJs($html, qw(utils settings avatar voting profile timestamp));

	return $html;
} # GetIndexPage()

sub GetMenuItem { # $address, $caption; returns html snippet for a menu item (used for both top and footer menus)
	my $address = shift;
	my $caption = shift;

	#todo more sanity

	WriteLog('GetMenuItem: $address = ' . $address . '; $caption = ' . $caption);

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

	if (GetConfig('html/accesskey')) {
		my $accessKey = GetAccessKey($caption);
		if ($accessKey) {
			$menuItem = AddAttributeToTag($menuItem, 'a', 'accesskey', $accessKey);
			if (GetConfig('html/emoji_menu')) {
				my $menuItemEmoji = GetString(lc($caption), 'emoji', 1); #lc() is a hack, name should be passed instead of caption
				$menuItem = AddAttributeToTag($menuItem, 'a', 'title', $caption);
			} else {
				$caption =~ s/($accessKey)/<u>$1<\/u>/i;
			}
		}
	} else {
		if (GetConfig('html/emoji_menu')) {
			my $menuItemEmoji = GetString(lc($caption), 'emoji', 1); #lc() is a hack, name should be passed instead of caption
		}
	}

	$menuItem =~ s/\$address/$address/g;
	$menuItem =~ s/\$caption/$caption/g;


	# $menuItem =~ s/\$color/$color/g;
	# $menuItem =~ s/\$firstLetter/$firstLetter/g;

	return $menuItem;
} # GetMenuItem()

sub WriteIndexPages { # writes the compost pages (index0-n.html)
	# sub MakeIndexPages {

	my $pageLimit = GetConfig('html/page_limit');
	if (!$pageLimit) {
		WriteLog('WriteIndexPages: warning: $pageLimit was FALSE, setting to sane 25');
		$pageLimit = 25;
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

	my $overlapPage = GetConfig('html/overlap_page');
	#in order to keep both the "last" and the "first" page the same length
	#and avoid having mostly-empty pages with only a few items
	#we introduce an overlap on page 5, where some items are displayed
	#twice. this also allows us to only update the first 5 plus all affected
	#when a new item is added, instead of the whole catalog
	#todo does not work as expected, fix it

	if (defined($itemCount) && $itemCount && $itemCount > 0) {
		my $i = 0;

		WriteLog('WriteIndexPages: $itemCount = ' . $itemCount);

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
			if (
				$overlapPage &&
				$lastPage > $overlapPage &&
				$i > $overlapPage
			) {
				$offset = $offset - ($itemCount % $pageLimit);
			}

			$queryParams{'limit_clause'} = "LIMIT $pageLimit OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY child_count ASC, add_timestamp DESC';

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
		} # for ($i)
	} else {
		my $indexPage = GetPageHeader(GetConfig('home_title'), GetConfig('home_title'), 'home_empty');
#		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';
		#todo this should be in template
		my $infoMessage = '<p>It looks like there is nothing to display here.</p><p><a href="/write.html">Would you like to write something?</a></p>';
		$indexPage .= GetWindowTemplate($infoMessage, 'No Items');
		$indexPage .= GetPageFooter();
		$indexPage = InjectJs($indexPage, qw(profile settings avatar utils));
		PutHtmlFile("index0.html", $indexPage); #empty/no items
		PutHtmlFile("compost.html", $indexPage); #empty/no items
	}
} # WriteIndexPages()

sub GetAccessKey { # $caption ; returns access key to use for menu item
	# tries to find non-conflicting one
	WriteLog('GetAccessKey()');

	if (!GetConfig('html/accesskey')) {
		WriteLog('GetAccessKey: warning: sanity check failed');
		return '';
	}

	my $caption = shift;
	#todo sanity checks

	state %captionKey;
	state %keyCaption;
	if ($captionKey{$caption}) {
		return $captionKey{$caption};
	}

	my $newKey = '';
	for (my $i = 0; $i < length($caption) - 1; $i++) {
		my $newKeyPotential = lc(substr($caption, $i, 1));
		if (!$keyCaption{$newKeyPotential}) {
			$newKey = $newKeyPotential;
			last;
		}
	}

	if ($newKey) {
		$captionKey{$caption} = $newKey;
		$keyCaption{$newKey} = $caption;
		return $captionKey{$caption};
	} else {
		#todo pick another letter, add in parentheses like this: File (<u>N</u>)
	}
} # GetAccessKey()

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

	my $jsTest2 = GetTemplate('test/jstest1/jstest2.template');
	$jsTest2 = InjectJs($jsTest2, qw(jstest2));
	PutHtmlFile("jstest2.html", $jsTest2);
}

sub GetDesktopPage { # returns html for desktop page (/desktop.html)
	my $html = "";
	my $title = "Desktop";

	$html = GetPageHeader($title, $title, 'desktop');
	$html .= GetTemplate('html/maincontent.template');

	{
		my $tosText = GetString('tos');
		$tosText = str_replace("\n", '<br>', $tosText);
		my $tosWindow = GetWindowTemplate(
			$tosText,
			'Terms of Service',
		);
		$html .= $tosWindow;

		$html .= GetTopAuthorsWindow();
		$html .= GetSettingsWindow();
		$html .= GetProfileWindow();
		$html .= GetStatsTable();
		#$html .= GetWriteForm(); #commented because of the setFocus js, which should not happen on this page
		$html .= GetUploadWindow('html/form/upload.template');
		$html .= GetOperatorWindow();
	}

	$html .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		my @scripts = qw(settings avatar profile timestamp pingback utils);
		if (GetConfig('admin/js/dragging')) {
			push @scripts, 'dragging';
		}
		$html = InjectJs($html, @scripts);
	}

	return $html;
} # GetDesktopPage()

sub MakeInputExpandable {
#		if (GetConfig('admin/js/enable')) {
#			$html = AddAttributeToTag($html, 'input name=comment', onpaste, "window.inputToChange=this; setTimeout('ChangeInputToTextarea(window.inputToChange); return true;', 100);");
#		} #input_expand_into_textarea

#todo
}

sub ListItemsByTag { #todo
	my $pageName = shift;
	if (!$pageName) {
		$pageName = 'welcome';
	}

	my $contentWindow = '';

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE item_flat.tags_list LIKE '%welcome%' AND item_flat.tags_list NOT LIKE '%flag%'"; #loose match
	$queryParams{'order_clause'} = "ORDER BY item_flat.add_timestamp DESC"; #order by timestamp desc
	$queryParams{'limit_clause'} = "LIMIT 100";
	my @files = DBGetItemList(\%queryParams);
	if (@files) {
		my $itemListHtml = GetItemListHtml(\@files);
		$contentWindow = $itemListHtml;
	}

	return $contentWindow;
}

sub GetSimpleWindow {
	my $windowType = shift;
	#todo sanity
	my $html = '';
	my $pageContent = GetTemplate("page/$windowType.template");
	if (!$pageContent) {
		WriteLog('GetSimpleWindow: warning: empty template, sanity check failed');
		return '';
	}
	my $contentWindow = GetWindowTemplate(
		$pageContent,
		ucfirst($windowType)
	);
	return $contentWindow;
} # GetSimpleWindow()

sub GetSimplePage { # given page name, makes page
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
	$html .= GetTemplate('html/maincontent.template');


	$html .= GetSimpleWindow($pageName);

	$html .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		my @scripts = qw(avatar settings profile utils timestamp);
		if (GetConfig('admin/js/dragging')) {
			push @scripts, 'dragging';
		}
		$html = InjectJs($html, @scripts);
	}

	return $html;
} # GetSimplePage()

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
	$html .= GetTemplate('html/maincontent.template');

	my $pageContent = GetTemplate("page/$pageName.template");

	my $contentWindow = GetWindowTemplate(
		$pageContent,
		ucfirst($pageName)
	);

	my $itemListPlaceholder = '<span id=itemList></span>';
	if ($pageName eq 'welcome') {
#		if (GetConfig('admin/js/enable')) {
#			$html = AddAttributeToTag($html, 'input name=comment', onpaste, "window.inputToChange=this; setTimeout('ChangeInputToTextarea(window.inputToChange); return true;', 100);");
#		} #input_expand_into_textarea

		if (index($html, $itemListPlaceholder) != -1) {
			my %queryParams;
			$queryParams{'where_clause'} = "WHERE item_flat.tags_list LIKE '%welcome%' AND item_flat.tags_list NOT LIKE '%flag%'"; #loose match
			$queryParams{'order_clause'} = "ORDER BY item_flat.add_timestamp DESC"; #order by timestamp desc
			$queryParams{'limit_clause'} = "LIMIT 100";
			my @files = DBGetItemList(\%queryParams);
			if (@files) {
				my $itemListHtml = GetItemListHtml(\@files);
				$contentWindow = $itemListHtml;
			}
		}
	}

	$html .= $contentWindow;

	$html .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		my @scripts = qw(avatar settings profile utils timestamp);
		if (GetConfig('admin/js/dragging')) {
			push @scripts, 'dragging';
		}
		$html = InjectJs($html, @scripts);
	}

	PutHtmlFile("$pageName.html", $html);

	if ($pageName eq 'welcome') {
		PutHtmlFile("index.html", $html);
	}
} # MakeSimplePage()

sub MakePhpPages {
	WriteLog('MakePhpPages() begin');

	if (GetConfig('admin/php/enable')) {
		# post.php
		# test2.php
		# config.php
		# test.php
		# write.php
		# upload.php
		# search.php
		# cookie.php
		# cookietest.php
		# route.php
		# quick.php
		my @templatePhpSimple = qw(post test2 config test write upload search cookie cookietest utils route);
		if (GetConfig('admin/php/quickchat')) {
			push @templatePhpSimple, 'quick';
		}
		for my $template (@templatePhpSimple) {
			my $fileContent = GetTemplate("php/$template.php");
            my $PHPDIR = GetDir('php');
			PutFile($PHPDIR . "/$template.php", $fileContent);
		}

		my $utilsPhpTemplate = GetTemplate('php/utils.php');
		my $SCRIPTDIR = GetDir('script');
		my $PHPDIR = GetDir('php');
        $utilsPhpTemplate =~ s/\$scriptDirPlaceholderForTemplating/$SCRIPTDIR/g;
		PutFile($PHPDIR . '/utils.php', $utilsPhpTemplate);
	}
} # MakePhpPages()

sub MakeJsPages {
	my $HTMLDIR = GetDir('html');

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
			my $oldValue = $crypto2JsTemplate;
			$crypto2JsTemplate = str_replace('var algoSelectMode = 0;', "var algoSelectMode = '$algoSelectMode'", $crypto2JsTemplate);
			if ($oldValue eq $crypto2JsTemplate) {
				WriteLog('MakeJsPages: warning: crypto2.js algoSelectMode templating failed, value of $crypto2JsTemplate did not change as expected');
			}
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
} # MakeJsPages()

sub MakeSummaryPages { # generates and writes all "summary" and "static" pages StaticPages
# write, add event, stats, profile management, preferences, post ok, action/vote, action/event
# js files, 
	WriteLog('MakeSummaryPages() BEGIN');

	my $HTMLDIR = GetDir('html');

	PutHtmlFile("test.html", GetTemplate('html/test.template'));
	PutHtmlFile("keyboard.html", GetTemplate('keyboard/keyboard.template'));
	PutHtmlFile("keyboard_netscape.html", GetTemplate('keyboard/keyboard_netscape.template'));
	PutHtmlFile("keyboard_android.html", GetTemplate('keyboard/keyboard_a.template'));

	PutHtmlFile("frame.html", GetTemplate('keyboard/keyboard_frame.template'));
	PutHtmlFile("frame2.html", GetTemplate('keyboard/keyboard_frame2.template'));
	PutHtmlFile("frame3.html", GetTemplate('keyboard/keyboard_frame3.template'));

	if (GetConfig('admin/offline/enable')) {
		PutHtmlFile("cache.manifest", GetTemplate('js/cache.manifest.template') . "#" . time()); # config/admin/offline/enable
	}

	if (GetConfig('admin/dev/make_js_test_pages')) {
		MakeJsTestPages();
	}

	my $jsTest1 = GetTemplate('test/jstest1/jstest1.template');
	$jsTest1 = InjectJs($jsTest1, qw(jstest1));
	PutHtmlFile("jstest1.html", $jsTest1);

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
		$submitPage =~ s/cols=32/cols=50/g;
		$submitPage =~ s/rows=9/rows=15/g;
		$submitPage =~ s/please click here/you're in the right place/g;
		PutHtmlFile("write_post.html", $submitPage);
	}

	# Upload page
	my $uploadPage = GetUploadPage();
	PutHtmlFile("upload.html", $uploadPage);

	# Upload page
	my $uploadMultiPage = GetUploadPage('html/form/upload_multi.template');
	PutHtmlFile("upload_multi.html", $uploadMultiPage);

	# Search page
	my $searchPage = GetSearchPage();
	PutHtmlFile("search.html", $searchPage);
#
#	# Add Event page
#	my $eventAddPage = GetEventAddPage();
#	PutHtmlFile("event.html", $eventAddPage);
#
#	# Add Event page
#	my $eventsPage = GetEventsPage();
#	PutHtmlFile("events.html", $eventsPage);

	# Add Authors page
	MakePage('authors', 0);

	MakePage('read', 0);

	MakePage('tags', 0);

	PutStatsPages();
	#
	# { # clock test page
	# 	my $clockTest = '<form name=frmTopMenu>' . GetTemplate('html/widget/clock.template') . '</form>';
	# 	my $clockTestPage = '<html><body>';
	# 	$clockTestPage .= $clockTest;
	# 	$clockTestPage .= '</body></html>';
	# 	$clockTestPage = InjectJs($clockTestPage, qw(clock));
	# 	PutHtmlFile("clock.html", $clockTestPage);
	# }

	{
		my $fourOhFourPage = GetDialogPage('404'); #GetTemplate('html/404.template');
		if (GetConfig('html/clock')) {
			$fourOhFourPage = InjectJs($fourOhFourPage, qw(clock fresh utils)); #todo this causes duplicate clock script
		}
		PutHtmlFile("404.html", $fourOhFourPage);
		PutHtmlFile("error/error-404.html", $fourOhFourPage);
	}

	{
		my $accessDeniedPage = GetDialogPage('401'); #GetTemplate('html/401.template');
		PutHtmlFile("error/error-401.html", $accessDeniedPage);
	}

	# Settings page
	my $settingsPage = GetSettingsPage();
	PutHtmlFile("settings.html", $settingsPage);

	# Access page
	my $accessPage = GetAccessPage();
	PutHtmlFile("access.html", $accessPage);

	# More page
	my $etcPage = GetEtcPage();
	PutHtmlFile("etc.html", $etcPage);

	{
		# Target page for the submit page
		my $postPage = GetPageHeader("Thank You", "Thank You", 'post');
		# $postPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;
		$postPage .= GetTemplate('html/maincontent.template');
		my $postTemplate = GetTemplate('page/post.template');
		$postPage .= $postTemplate;
		$postPage .= GetPageFooter();
		$postPage = InjectJs($postPage, qw(settings avatar post));
		if (GetConfig('admin/js/enable')) {
			$postPage =~ s/<body /<body onload="makeRefLink();" /;
			$postPage =~ s/<body>/<body onload="makeRefLink();">/;
		}
		my $HTMLDIR = GetDir('html');
		WriteLog('MakeSummaryPages: ' . "$HTMLDIR/post.html");
		PutHtmlFile("post.html", $postPage);
	}
	
	# Ok page
	my $okPage;
	$okPage .= GetPageHeader('OK', 'OK', 'default');
	my $windowContents = GetTemplate('html/action_ok.template');
	$okPage .= GetWindowTemplate($windowContents, 'Data Received', '', 'Ready');
	$okPage .= GetPageFooter();
	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;
	$okPage = InjectJs($okPage, qw(settings));
	PutHtmlFile("action/event.html", $okPage);

	#MakeSimplePage('calculator'); # calculator.html calculator.template
	MakeSimplePage('manual'); # manual.html manual.template
	MakeSimplePage('help'); # help.html help.template
	MakeSimplePage('welcome'); # welcome.html welcome.template
	MakeSimplePage('bookmark'); # welcome.html welcome.template
#	MakeSimplePage('desktop'); # welcome.html welcome.template
	MakeSimplePage('manual_advanced'); # manual_advanced.html manual_advanced.template
	MakeSimplePage('manual_tokens'); # manual_tokens.html manual_tokens.template

	PutHtmlFile('desktop.html', GetDesktopPage());

	# Blank page
	PutHtmlFile("blank.html", "");

	if (GetConfig('admin/js/enable')) {
		MakeJsPages();
	}

	if (GetConfig('admin/htaccess/enable')) { #.htaccess
		# .htaccess file for Apache
		my $HtaccessTemplate = GetTemplate('htaccess/htaccess.template');

		# here, we inject the contents of 401.template into .htaccess
		# this is a kludge until i figure out how to do it properly
		# 401.template should not contain any " characters (will be removed)
		#
		my $text401 = GetTemplate('html/401.template');
		$text401 =~ s/\n//g;
		$text401 =~ s/"//g;
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
				if ($HTMLDIR =~ m/^([^\s]+)$/) { #todo security less permissive and untaint at top of file #security #taint
					$HTMLDIR = $1;
					chmod 0644, "$HTMLDIR/.htpasswd";
				}

				$HtaccessHttpAuthTemplate =~ s/\.htpasswd/$HTMLDIR\/\.htpasswd/;

				my $errorDocumentRoot = "$HTMLDIR/error/";
				$HtaccessHttpAuthTemplate =~ s/\$errorDocumentRoot/$errorDocumentRoot/g;
				#todo this currently has a one-account template

				$HtaccessTemplate .= "\n" . $HtaccessHttpAuthTemplate;
			}
		}

		if (GetConfig('admin/ssi/enable')) {
			my $ssiConf = GetTemplate('htaccess/htaccess_ssi.template');
			$HtaccessTemplate .= "\n" . $ssiConf;
		}

		PutFile("$HTMLDIR/.htaccess", $HtaccessTemplate);

		# WriteDataPage();
	} #.htaccess

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

	WriteIndexPages();

	if (GetConfig('admin/php/enable')) {
		MakePhpPages();
	}

	WriteLog('MakeSummaryPages() END');
} # MakeSummaryPages()

sub GetUploadWindow { # upload window for upload page
	if (!GetConfig('admin/upload/enable')) {
		WriteLog('GetUploadWindow: warning: called while admin/upload/enable was false');
		return '';
	}

	my $template = shift;
	if (!$template) {
		$template = 'upload.template';
	}
	my $title = 'Upload';
	if (index(lc($template), 'multi') != -1) {
		$title = 'Upload Multiple Files';
	}

	my $uploadForm = GetTemplate($template);
	if (GetConfig('admin/js/enable')) {
		# $uploadForm = AddAttributeToTag($uploadForm, 'input name=uploaded_file', 'onchange', "if (document.upload && document.upload.submit && document.upload.submit.value == 'Upload') { document.upload.submit.click(); }");
		# this caused back button breaking
		$uploadForm = AddAttributeToTag($uploadForm, 'input name=uploaded_file', 'onchange', "if (window.UploadedFileOnChange) { UploadedFileOnChange(this); }");
		$uploadForm = AddAttributeToTag($uploadForm, 'input name="uploaded_file[]"', 'onchange', "if (window.UploadedFileMultiOnChange) { UploadedFileMultiOnChange(this); }");
		$uploadForm = AddAttributeToTag($uploadForm, 'input name=submit', 'onclick', "this.value='Meditate...';");
	}
	my $allowFiles = GetConfig('admin/image/allow_files');
	$uploadForm =~ s/\$allowFiles/$allowFiles/gms;
	my $uploadWindow = GetWindowTemplate($uploadForm, $title);
	return $uploadWindow;
} # GetUploadWindow()

sub GetSearchWindow { # search window for search page
	my $searchForm = GetTemplate('form/search.template');
	my $searchWindow = GetWindowTemplate($searchForm, 'Public Search');
	return $searchWindow;
} # GetSearchWindow()

sub GetWriteForm { # returns write form (for composing text message)
	my $writeForm = GetWindowTemplate(GetTemplate('html/form/write/write.template'), 'Write');
	WriteLog('GetWriteForm()');

	if (GetConfig('admin/php/enable')) {
		my $writeLongMessage = GetTemplate('form/write/long_message.template');
		if ($writeLongMessage) {
			my $targetElement = '<span id=writeintro>';
			$writeForm = str_replace($targetElement, $targetElement . $writeLongMessage, $writeForm);
		}

		if (GetConfig('admin/php/enable') && !GetConfig('admin/php/rewrite')) {
			# if php is enabled but rewrite is disabled
			# change submit target to post.php
			my $postHtml = 'post\\.html'; # post.html
			$writeForm =~ s/$postHtml/post.php/;
		}

		# this is how auto-save to server would work (with privacy implications) #autosave
		# $submitForm =~ s/\<textarea/<textarea onkeyup="if (this.length > 2) { document.forms['compose'].action='\/post2.php'; }" /;
	}

	my $initText = '';
	#
	# # these are not present in the template
	# $writeForm =~ s/\$extraFields/poop/g;
	$writeForm =~ s/\$initText/$initText/g;

	if (GetConfig('admin/js/enable')) {
		# javascript is enabled, add event hooks
		my $writeOnChange = "if (window.commentOnChange) { return commentOnChange(this, 'compose'); } else { return true; }";
		$writeForm = AddAttributeToTag($writeForm, 'textarea', 'onchange', $writeOnChange);
		$writeForm = AddAttributeToTag($writeForm, 'textarea', 'onkeyup', $writeOnChange);
		if (GetConfig('admin/js/translit')) {
			$writeForm = AddAttributeToTag(
				$writeForm,
				'textarea',
				'onkeydown',
				'if (window.translitKey) { translitKey(event, this); } else { return true; }'
			);
		}

		$writeForm = AddAttributeToTag(
			$writeForm,
			'input type=submit',
			'onclick',
			"this.value = 'Meditate...'; if (window.writeSubmit) { setTimeout('writeSubmit();', 1); return true; } else { return true; }"
		);
	} # js stuff in write form

	return $writeForm;
} # GetWriteForm()

sub GetUploadPage { # returns html for upload page
	my $html = '';
	my $title = 'Upload';

	if (GetConfig('admin/php/enable') && GetConfig('admin/upload/enable')) {
		my $template = shift;
		if (!$template) {
			$template = 'html/form/upload.template';
		}
		$html .= GetPageHeader($title, $title, 'upload');
		$html .= GetTemplate('html/maincontent.template');
		$html .= GetUploadWindow($template);
		$html .= GetPageFooter();

		if (GetConfig('admin/js/enable')) {
			$html = InjectJs($html, qw(utils settings avatar profile upload));
		}
	} else {
		$html .= GetPageHeader($title, $title, 'upload');
		$html .= GetTemplate('html/maincontent.template');
		$html .= GetWindowTemplate('<p>Upload feature is not available. Apologies.</p>', $title);
		$html .= GetPageFooter();
		if (GetConfig('admin/js/enable')) {
			$html = InjectJs($html, qw(utils settings avatar profile));
		}
	}

	return $html;
} # GetUploadPage()

sub GetSearchPage { # returns html for search page
	my $html = '';
	my $title = 'Search';

	$html .= GetPageHeader($title, $title, 'search');
	$html .= GetTemplate('html/maincontent.template');
	$html .= GetSearchWindow();
	$html .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		$html = InjectJs($html, qw(settings avatar profile puzzle));
	}
	return $html;
} # GetSearchPage()

sub GetWritePage { # returns html for write page
	# $writePageHtml stores html page output
	my $writePageHtml = "";

	my $title = "Write";
	my $titleHtml = "Write";

#	my $itemCount = DBGetItemCount();
#	my $itemLimit = GetConfig('number/item_limit');
#	if (!$itemLimit) {
#		$itemLimit = 9000;
#	}

	$writePageHtml = GetPageHeader($title, $titleHtml, 'write');
	$writePageHtml .= GetTemplate('html/maincontent.template');

	my $writeForm = GetWriteForm();
	WriteLog('GetWriteForm: js is on, adding write_js.template');
    my $writeJs = '<span class=advanced>' . GetWindowTemplate(GetTemplate('form/write/write_js.template'), 'Options') . '</span>'; #todo this is a hack

    $writePageHtml .= '<form action="/post.html" method=GET id=compose class=submit name=compose target=_top>'; #todo
	$writePageHtml .= $writeForm;
	$writePageHtml .= $writeJs;
	$writePageHtml .= '</form>'; #todo

#	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
#		my $itemCounts = GetTemplate('form/itemcount.template');
#		$itemCounts =~ s/\$itemCount/$itemCount/g;
#		$itemCounts =~ s/\$itemLimit/$itemLimit/g;
#	}
#
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

	return $writePageHtml;
} # GetWritePage()

sub GetProfileWindow {
	my $profileWindowContents = GetTemplate('form/profile.template');

	if (GetConfig('admin/gpg/use_gpg2')) {
		my $gpg2Choices = GetTemplate('html/gpg2.choices.template');
		$profileWindowContents =~ s/\$gpg2Algochoices/$gpg2Choices/;
	} else {
		$profileWindowContents =~ s/\$gpg2Algochoices//;
	}

	my $profileWindow = GetWindowTemplate(
		$profileWindowContents,
		'Profile',
	);

	return $profileWindow;
}

sub GetEventAddPage { # get html for /event.html
	# $txtIndex stores html page output
	my $txtIndex = "";

	my $title = "Add Event";
	my $titleHtml = "Add Event";

	$txtIndex = GetPageHeader($title, $titleHtml, 'event_add');

	$txtIndex .= GetTemplate('html/maincontent.template');
	

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
		$txtIndex .= GetTemplate('html/maincontent.template');

		my $profileWindowContents = GetTemplate('form/profile.template');

		if (GetConfig('admin/gpg/use_gpg2')) {
			my $gpg2Choices = GetTemplate('html/gpg2.choices.template');
			$profileWindowContents =~ s/\$gpg2Algochoices/$gpg2Choices/;
		} else {
			$profileWindowContents =~ s/\$gpg2Algochoices//;
		}

		my $profileWindow = GetProfileWindow();

		my $tosText = GetString('tos');
		$tosText = str_replace("\n", '<br>', $tosText);
		my $tosWindow = GetWindowTemplate(
			$tosText,
			'Terms of Service',
		);

		$txtIndex .= $profileWindow;
		$txtIndex .= $tosWindow;
		$txtIndex .= GetPageFooter();

		if (GetConfig('admin/js/enable')) {
			$txtIndex = InjectJs($txtIndex, qw(settings utils profile timestamp));
		} else {
			# js is disabled
		}
	} else {
		$txtIndex = GetPageHeader($title, $titleHtml, 'identity');
		$txtIndex .= GetTemplate('html/maincontent.template');

		my $profileWindowContents = GetTemplate('form/profile_no.template');
		my $profileWindow = GetWindowTemplate(
			$profileWindowContents,
			'Profile'
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

sub GetAccessPage { # returns html for compatible mode page, /access.html
	my $html = '';
	my $title = 'Light Mode';

	$html = GetPageHeader($title, $title, 'access');
	$html .= GetTemplate('html/maincontent.template');
	my $accessTemplate = GetTemplate('html/access.template');
	$accessTemplate = GetWindowTemplate(
		$accessTemplate,
		'Light Mode'
	);
	$html .= $accessTemplate;
	$html .= GetPageFooter();

	return $html;
}

sub GetSettingsWindow {
	my $settingsTemplate = GetTemplate('form/settings.template');
	my $settingsWindow = GetWindowTemplate($settingsTemplate, 'Settings');
	$settingsWindow = '<form id=frmSettings name=frmSettings>' . $settingsWindow . '</form>';
	return $settingsWindow;
}

sub GetOperatorWindow {
	my $operatorTemplate = GetTemplate('form/operator.template');
	my $operatorWindow = GetWindowTemplate($operatorTemplate, 'operator');
	$operatorWindow = '<form id=frmOperator name=frmOperator class=admin>' . $operatorWindow . '</form>';
	return $operatorWindow;
}

sub GetSettingsPage { # returns html for settings page (/settings.html)
	my $txtIndex = "";

	my $title = "Settings";
	my $titleHtml = "Settings";

	$txtIndex = GetPageHeader($title, $titleHtml, 'settings');
	$txtIndex .= GetTemplate('html/maincontent.template');

	$txtIndex .= GetSettingsWindow();
	$txtIndex .= GetStatsTable();
	$txtIndex .= GetOperatorWindow();

	$txtIndex .= GetPageFooter();

	if (GetConfig('admin/js/enable')) {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar profile timestamp pingback utils));
	}

	return $txtIndex;
} # GetSettingsPage()

sub GetEtcPage { # returns html for etc page (/etc.html)
	my $txtIndex = "";

	my $title = "More";
	my $titleHtml = "More";

	$txtIndex = GetPageHeader($title, $titleHtml, 'etc');

	$txtIndex .= GetTemplate('html/maincontent.template');

	my $menuItems = GetMenuFromList('menu', 'html/menuitem-p.template');
	$menuItems .= GetMenuFromList('menu_advanced', 'html/menuitem-p.template');

	my $etcPageContent = GetTemplate('html/etc.template');

	$etcPageContent =~ s/\$etcMenuItems/$menuItems/;

	my $etcPageWindow = GetWindowTemplate($etcPageContent, 'More');

	$txtIndex .= $etcPageWindow;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(utils clock settings avatar profile));

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
		my $itemDescription = GetItemDetokenedMessage($fileHash, $file->{'file_path'});

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

	$txtPageHtml .= GetTemplate('html/maincontent.template');

	my $versionInfo = GetTemplate('html/versioninfo.template');
	my $shortVersion = substr($version, 0, 8);

	$versionInfo =~ s/\$version/$version/g;
	$versionInfo =~ s/\$shortVersion/$shortVersion/g;

	$txtPageHtml .= $versionInfo;

	$txtPageHtml .= GetPageFooter();

	$txtPageHtml = InjectJs($txtPageHtml, qw(settings avatar));

	return $txtPageHtml;
}

sub WriteDataPage { # writes /data.html (and zip files if needed)
	#This makes the zip file as well as the data.html page that lists its size
	WriteLog('MakeDataPage() called');

	my $zipInterval = 1;
	my $touchZip = GetCache('touch/zip');
	if (!$touchZip) {
		$touchZip = 0;
	}
	WriteLog('MakeDataPage: $zipInterval = ' . $zipInterval . '; $touchZip = ' . $touchZip);

	if (!$touchZip || (GetTime() - $touchZip) > $zipInterval) {
		WriteLog('MakeDataPage: Making zip files...');
		my $HTMLDIR = GetDir('html');
		WriteLog('MakeDataPage: $HTMLDIR = ' . $HTMLDIR);

		# zip -qr foo.zip somefile
		# -q for quiet
		# -r for recursive
		#todo write zip call
		system("zip -qr $HTMLDIR/txt.tmp.zip $HTMLDIR/txt/ $HTMLDIR/chain.log");
		rename("$HTMLDIR/txt.tmp.zip", "$HTMLDIR/txt.zip");
		
		system("zip -qr $HTMLDIR/index.sqlite3.zip.tmp cache/" . GetMyCacheVersion() . "/index.sqlite3");
		rename("$HTMLDIR/index.sqlite3.zip.tmp", "$HTMLDIR/index.sqlite3.zip");

		PutCache('touch/zip', GetTime());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}
	my $dataPage = GetPageHeader("Data", "Data", 'data');
	$dataPage .= GetTemplate('html/maincontent.template');
	my $dataPageContents = GetTemplate('html/data.template');

	my $HTMLDIR = GetDir('html');
	my $sizeHikeZip = -s "$HTMLDIR/txt.zip";
	my $sizeSqliteZip = -s "$HTMLDIR/index.sqlite3.zip";

	$sizeHikeZip = GetFileSizeWidget($sizeHikeZip);
	if (!$sizeHikeZip) {
		$sizeHikeZip = 0;
	}

	$sizeSqliteZip = GetFileSizeWidget($sizeSqliteZip);
	if (!$sizeSqliteZip) {
		$sizeSqliteZip = 0;
	}

	$dataPageContents =~ s/\$sizeHikeZip/$sizeHikeZip/g;
	$dataPageContents =~ s/\$sizeSqliteZip/$sizeSqliteZip/g;

	$dataPageContents = $dataPageContents;

	my $dataPageWindow = GetWindowTemplate(
		$dataPageContents,
		'Data'
	);

	$dataPage .= $dataPageWindow;
	$dataPage .= GetPageFooter();
	$dataPage = InjectJs($dataPage, qw(settings avatar profile));

	PutHtmlFile("data.html", $dataPage);
} # WriteDataPage()

sub GetItemPageFromHash { # $fileHash, returns html
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
		WriteLog("GetItemPageFromHash: \@files loop: warning: Asked to index file $fileHash, but it is not in the database! Returning.");
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

		WriteLog('GetItemTemplateFromHash: my $itemPage = GetItemTemplate2($file = "' . $file . '")');
		my $itemPage = GetItemTemplate2($file);

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
		GetStatsTable('stats-horizontal.template'),
		'Site Statistics*'
	);
	PutHtmlFile("stats-footer.html", $statsFooter);
}

sub GetPagePath { # $pageType, $pageParam ; returns path to item's html path
# $pageType, $pageParam match parameters for MakePage()
	my $pageType = shift;
	my $pageParam = shift;

	chomp $pageType;
	chomp $pageParam;

	if (!$pageType) {
		return '';
	}

	my $htmlPath = '';

	if ($pageType eq 'author') {
		# /author/ABCDEF1234567890/index.html
		$htmlPath = $pageType . '/' . $pageParam . '/index.html';
	}
	elsif ($pageType eq 'tag') {
		# /top/approve.html
		$htmlPath = 'top/' . $pageParam . '.html';
	}
	elsif ($pageType eq 'rss') {
		# /rss.xml
		$htmlPath = 'rss.xml';
	}
	elsif ($pageType eq 'authors') {
		# /authors.html
		$htmlPath = 'authors.html';
	} else {
		if ($pageParam) {
			# e.g. /tag/approve.html
			$htmlPath = $pageType . '/' . $pageParam . '.html';
		} else {
			# e.g. /profile.html
			$htmlPath = $pageType . '.html';
		}
	}

	return $htmlPath;
} # GetPagePath()

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

	WriteLog("BuildTouchedPages($timeLimit, $startTime)");

	my $pagesLimit = GetConfig('admin/update/limit_page');
	if (!$pagesLimit) {
		WriteLog("WARNING: config/admin/update/limit_page missing!");
		$pagesLimit = 1000;
	}

	my $pagesProcessed = 0;

	# get a list of pages that have been touched since touch git_flow
	# this is from the task table
	my $touchedPages = DBGetTouchedPages($pagesLimit);

	if ($touchedPages) { #todo actually check it's an array reference or something?
		# de-reference array of touched pages
		my @touchedPagesArray = @$touchedPages;

		# write number of touched pages to log
		WriteLog('BuildTouchedPages: scalar(@touchedPagesArray) = ' . scalar(@touchedPagesArray));

		# this part will refresh any pages that have been "touched"
		# in this case, 'touch' means when an item that affects the page
		# is updated or added

		my $isLazy = 0;
		if (GetConfig('admin/pages/lazy_page_generation')) {
			if (GetConfig('admin/php/enable')) {
				# at this time, php is the only module which can support regrowing
				# 404 pages and thsu lazy page gen
				if (GetConfig('admin/php/rewrite')) {
					# rewrite is also required for this to work
					if (GetConfig('admin/php/regrow_404_pages')) {
						WriteLog('BuildTouchedPages: $isLazy conditions met, setting $isLazy = 1');
						$isLazy = 1;
					}
				}
			}
		}
		WriteLog('BuildTouchedPages: $isLazy = ' . $isLazy);

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
			WriteLog('BuildTouchedPages: $pageType = ' . $pageType . '; $pageParam = ' . $pageParam . '; $touchTime = ' . $touchTime);

			if ($isLazy) {
				my $pagePath = GetPagePath($pageType, $pageParam);
				RemoveHtmlFile($pagePath);
			} else {
				MakePage($pageType, $pageParam);
			}
			DBDeletePageTouch($pageType, $pageParam);
		}
	} # $touchedPages
	else {
		WriteLog('BuildTouchedPages: warning: $touchedPages was false, and thus not an array reference.');
		return 0;
	}

	return $pagesProcessed;
} # BuildTouchedPages

sub GetAvatar { # $key, $noCache ; returns HTML avatar based on author key, using avatar.template
	# affected by config/html/avatar_icons
	WriteLog("GetAvatar(...)");
	my $aliasHtmlEscaped = '';

	state $avatarCacheDir;
	state $avatarTemplate;

	if (!$avatarCacheDir || !$avatarTemplate) {
		if (GetConfig('html/avatar_icons')) {
			$avatarCacheDir = 'avatar.color';
			$avatarTemplate = 'html/avatar.template';
		} else {
			$avatarCacheDir = 'avatar.plain';
			$avatarTemplate = 'html/avatar-username.template';
		}
		my $themeName = GetConfig('html/theme');
		$avatarCacheDir .= '/' . $themeName;
	}

	WriteLog('GetAvatar: $avatarCacheDir = ' . $avatarCacheDir . '; $avatarTemplate = ' . $avatarTemplate);

	state %avatarCache;

	my $authorKey = shift;
	if (!$authorKey) {
		WriteLog('GetAvatar: warning: $authorKey is false, returning empty string');
		return '';
	}
	chomp $authorKey;

	WriteLog("GetAvatar($authorKey)");

	my $noCache = shift;
	$noCache = ($noCache ? 1 : 0);

	if (! $noCache) {
		# $noCache is FALSE, so use cache!
		if ($avatarCache{$authorKey}) {
			WriteLog('GetAvatar: found in %avatarCache');
			return $avatarCache{$authorKey};
		}
		my $avCacheFile = GetCache("$avatarCacheDir/$authorKey");
		if ($avCacheFile) {
			$avatarCache{$authorKey} = $avCacheFile;
			WriteLog('GetAvatar: found cache, returning: $avatarCache{$authorKey} = ' . $avatarCache{$authorKey});
			return $avatarCache{$authorKey};
		}
	} else {
		WriteLog('GetAvatar: $noCache is true, ignoring cache');
	}

	my $avatar = GetTemplate($avatarTemplate);
	WriteLog('GetAvatar: $avatar = ' . $avatar . '; $avatarTemplate = ' . $avatarTemplate);

	{ # trim whitespace from avatar template
		#this trims extra whitespace from avatar template
		#otherwise there may be extra spaces in layout
		#WriteLog('avdesp before:'.$avatar);
		$avatar =~ s/\>\s+/>/g;
		$avatar =~ s/\s+\</</g;
		#WriteLog('avdesp after:'.$avatar);
	}

	my $redditUsername = '';
	if ($authorKey) {
		WriteLog('GetAvatar: $authorKey = ' . $authorKey);

		my $authorPubKeyHash = DBGetAuthorPublicKeyHash($authorKey) || '';
		WriteLog('GetAvatar: $authorPubKeyHash = ' . $authorPubKeyHash);
		my $authorItemAttributes = $authorPubKeyHash ? DBGetItemAttribute($authorPubKeyHash) : '' || '';
		WriteLog('GetAvatar: $authorItemAttributes = ' . $authorItemAttributes);

		my $isVerified = 0;
		my $alias = '';
		if (!$alias) {
			$alias = GetAlias($authorKey, $noCache);
			$alias = trim($alias);
		}
		if ($authorItemAttributes) {
			foreach my $authorAttributeLine (split("\n", $authorItemAttributes)) {
				my ($authorAttribute, $authorAttributeValue) = split('\|', $authorAttributeLine);
				WriteLog('GetAvatar: $authorAttribute = ' . $authorAttribute);

				if ($authorAttribute eq 'gpg_id') { #todo add or admin
#				if ($authorAttribute eq 'reddit_username') { #todo add or admin
					WriteLog('GetAvatar: found gpg_id!');

					if (!GetConfig('admin/html/ascii_only')) {
						#$alias .= '✔';
						$alias .= '&check;';
						#$alias .= 'V';
					} else {
						$alias .= '(verified)';
					}

					#$redditUsername = $authorAttributeValue . 'xx';
#
#					if ($redditUsername eq $alias) {
#						# if alias is the same as reddit username,
#						# don't print it twice
#						if (!GetConfig('admin/html/ascii_only')) {
#							$alias .= '✔';
#						} else {
#							$alias .= '(verified)';
#						}
#					} else {
#						$alias .= '(' . $redditUsername . ')';
#					}
				} # gpg_id
			} # $authorAttributeLine
		} # $authorItemAttributes

		if (GetConfig('html/avatar_icons')) {
			my $color1 = '#' . substr($authorKey, 0, 6);
			my $color2 = '#' . substr($authorKey, 3, 6);
			my $color3 = '#' . substr($authorKey, 6, 6);
			my $color4 = '#' . substr($authorKey, 9, 6);
			my $color5 = '#' . substr($authorKey, 12, 4) . substr($authorKey, 0, 2);
			my $color6 = '#' . substr($authorKey, 1, 6);
			my $color7 = '#' . substr($authorKey, 2, 6);
			my $color8 = '#' . substr($authorKey, 4, 6);
			my $color9 = '#' . substr($authorKey, 5, 6);
			my $colorA = '#' . substr($authorKey, 7, 6);
			my $colorB = '#' . substr($authorKey, 8, 6);

			$alias = encode_entities2($alias);
			#$alias = encode_entities($alias, '<>&"');

			if ($alias) {
				my $char1;
				my $char2;
				my $char3;

				$char1 = substr($authorKey, 12, 1);
				$char2 = substr($authorKey, 13, 1);
				$char3 = substr($authorKey, 14, 1);

				# 
				$char1 =~ tr/0123456789ABCDEF/)!]#$%^&*(;,.:['/;
				$char2 =~ tr/0123456789ABCDEF/)!]#$%^&*(;,.:['/;
				$char3 =~ tr/0123456789ABCDEF/)!]#$%^&*(;,.:['/;

				# $char1 =~ tr/0123456789ABCDEF/abcdefghijklmnop/;
				# $char2 =~ tr/0123456789ABCDEF/abcdefghijklmnop/;
				# $char3 =~ tr/0123456789ABCDEF/abcdefghijklmnop/;

				# $char1 = '*';
				# $char2 = '*';
				# $char3 = '*';

				$avatar =~ s/\$color1/$color1/g;
				$avatar =~ s/\$color2/$color2/g;
				$avatar =~ s/\$color3/$color3/g;
				$avatar =~ s/\$color4/$color4/g;
				$avatar =~ s/\$color5/$color5/g;
				$avatar =~ s/\$color6/$color6/g;
				$avatar =~ s/\$color7/$color7/g;
				$avatar =~ s/\$color8/$color8/g;
				$avatar =~ s/\$color9/$color9/g;
				$avatar =~ s/\$colorA/$colorA/g;
				$avatar =~ s/\$colorB/$colorB/g;

				$avatar =~ s/\$alias/$alias/g;
				$avatar =~ s/\$char1/$char1/g;
				$avatar =~ s/\$char2/$char2/g;
				$avatar =~ s/\$char3/$char3/g;
			}
			else {
				$avatar = '';
			}
		}
		else {
			# no icons
			$aliasHtmlEscaped = encode_entities2($alias);
			if ($redditUsername) {
				$aliasHtmlEscaped = '<b><i>'.$aliasHtmlEscaped.'</i></b>';
			}
		}
		#$avatar =~ s/\$alias/$aliasHtmlEscaped/g;
	} else {
		WriteLog('GetAvatar: warning: sanity check failed, $authorKey is false');
		$avatar = "";
	}

	$avatar =~ s/\$alias/$aliasHtmlEscaped/g;

	#my $colorUsername = GetThemeColor('username');
	my $colorUsername = GetThemeColor('author');
	if ($redditUsername) {
		$colorUsername = GetThemeColor('verified');
	}
	if (IsAdmin($authorKey)) {
		$colorUsername = GetThemeColor('admin');
	}
	WriteLog('GetAvatar: $colorUsername = ' . $colorUsername);
	$avatar =~ s/\$colorUsername/$colorUsername/g;

	$avatarCache{$authorKey} = $avatar;

	if ($avatar) {
		PutCache("$avatarCacheDir/$authorKey", $avatar);
	}

	return $avatar;
} # GetAvatar()

sub GetTimestampWidget { # $time ; returns timestamp widget
	#todo format on server-side for no-js clients
	my $time = shift;
	if ($time) {
		chomp $time;
	} else {
		$time = 0;
	}
	WriteLog('GetTimestampWidget("' . $time . '")');

	state $epoch; # state of config
	if (!defined($epoch)) {
		$epoch = GetConfig('html/timestamp_epoch');
	}

	if (!$time =~ m/^[0-9]+$/) {
		WriteLog('GetTimestampWidget: warning: sanity check failed!');
		return '';
	}

	my $widget = '';
	if ($epoch) {
		# epoch-formatted timestamp, simpler template
		$widget = GetTemplate('html/widget/timestamp_epoch.template');
		$widget =~ s/\$timestamp/$time/;
	} else {
		WriteLog('GetTimestampWidget: $epoch = false');
		$widget = GetTemplate('html/widget/timestamp.template');

		$widget = str_replace("\n", '', $widget);
		# if we don't do this, the link has an extra space

		my $timeDate = $time;
		$timeDate = FormatDate($time);
		# Alternative formats tried
		# my $timeDate = strftime '%c', localtime $time;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;

		# replace into template
		$widget =~ s/\$timestamp/$time/g;
		$widget =~ s/\$timeDate/$timeDate/g;
	}

	chomp $widget;
	return $widget;
} # GetTimestampWidget()

sub FormatDate { # $epoch ; formats date depending on how long ago it was
# FormatDateForDisplay()
	my $epoch = shift;

	if ($epoch =~ m/\D/) { # has non-digits
		WriteLog('FormatDate: warning: $epoch failed sanity check');
		return '???';
	}

	my $time = GetTime();
	my $difference = $time - $epoch;
	my $formattedDate = '';

	if ($difference < 86400) {
		# less than a day, return 24-hour time
		$formattedDate = strftime '%H:%M', localtime $epoch;
	} elsif ($difference < 86400 * 30) {
		# less than a month, return short date
		$formattedDate = strftime '%m/%d', localtime $epoch;
	} else {
		# more than a month, return long date
		$formattedDate = strftime '%a, %d %b %Y', localtime $epoch;
		# my $timeDate = strftime '%Y/%m/%d %H:%M:%S', localtime $time;
	}
	return $formattedDate;
} # FormatDate()

sub SurveyForWeb { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	my $i = 0;

	$text = HtmlEscape($text);
	# $text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	# $text =~ s/\n/<br>\n/g;
	# $text =~ s/<br>/'<br><input type=text size=80 name=txt'.$i++.'><br>'/ge;
	# $text =~ s/<br>/<br><br>/g;
	$text = '<textarea wrap=wrap cols=80 rows=24>'.$text.'</textarea>';
	$text = '<form action=/post.html>'.$text.'<br><input type=submit value=Send></form>';

	#htmlspecialchars(
	## nl2br(
	## str_replace(
	## '  ', ' &nbsp;',
	# htmlspecialchars(
	## $quote->quote))))?><? if ($quote->comment) echo(htmlspecialchars('<br><i>Comment:</i> '.htmlspecialchars($quote->comment)
	#));?><?=$tt_c?></description>

	return $text;
}

sub TextartForWeb { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	$text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	$text =~ s/\n/<br>\n/g;

	#htmlspecialchars(
	## nl2br(
	## str_replace(
	## '  ', ' &nbsp;',
	# htmlspecialchars(
	## $quote->quote))))?><? if ($quote->comment) echo(htmlspecialchars('<br><i>Comment:</i> '.htmlspecialchars($quote->comment)
	#));?><?=$tt_c?></description>

	return $text;
}

sub FormatForWeb { # $text ; replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);

	# these have been moved to format for textart
	#	$text =~ s/\n /<br>&nbsp;/g;
	#	$text =~ s/^ /&nbsp;/g;
	#	$text =~ s/  / &nbsp;/g;

	#$text =~ s/\n\n/<p>/g; #todo reinstate this when the stylesheet problem is fixed
	$text =~ s/\n/<br>/g;

	# this is more flexible than \n but may cause problems with unicode
	# for example, it recognizes second half of russian "x" as \R
	# #regexbugX
	# $text =~ s/\R\R/<p>/g;
	# $text =~ s/\R/<br>/g;

	if (GetConfig('admin/html/allow_tag/code')) {
		$text =~ s/&lt;code&gt;(.*?)&lt;\/code&gt;/<code>$1<\/code>/msgi;
		# /s = single-line (changes behavior of . metacharacter to match newlines)
		# /m = multi-line (changes behavior of ^ and $ to work on lines instead of entire file)
		# /g = global (all instances)
		# /i = case-insensitive
	}

	return $text;
}

sub FormatForRss { # replaces some spaces with &nbsp; to preserve text-based layout for html display; $text
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	$text =~ s/\n/<br \/>\n/g;

	return $text;
} # FormatForRss()

sub GetFileSizeWidget { # takes file size as number, and returns html-formatted human-readable size
	my $fileSize = shift;

	#todo more sanity checks, and 0 should be a valid filesize
	if (!$fileSize && $fileSize != 0) {
		return '';
	}

	chomp ($fileSize);

	my $fileSizeString = $fileSize;

	if ($fileSizeString > 1024) {
		$fileSizeString = $fileSizeString / 1024;

		if ($fileSizeString > 1024) {
			$fileSizeString = $fileSizeString / 1024;

			if ($fileSizeString > 1024) {
				$fileSizeString = $fileSizeString / 1024;

				if ($fileSizeString > 1024) {
					$fileSizeString = $fileSizeString / 1024;

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="terabytes">TB</abbr>';
				} else {

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="gigabytes">GB</abbr>';
				}
			} else {
				$fileSizeString = ceil($fileSizeString) . ' <abbr title="megabytes">MB</abbr>';
			}
		} else {
			$fileSizeString = ceil($fileSizeString) . ' <abbr title="kilobytes">KB</abbr>';
		}
	} else {
		$fileSizeString .= " bytes";
	}

	return $fileSizeString;
} # GetFileSizeWidget()

sub GetSecondsHtml {# takes number of seconds as parameter, returns the most readable approximate time unit
	# 5 seconds = 5 seconds
	# 65 seconds = 1 minute
	# 360 seconds = 6 minutes
	# 3600 seconds = 1 hour
	# etc

	my $seconds = shift;

	if (!$seconds) {
		return;
	}

	chomp $seconds;

	my $secondsString = $seconds;

	if ($secondsString >= 60) {
		$secondsString = $secondsString / 60;

		if ($secondsString >= 60 ) {
			$secondsString = $secondsString / 60;

			if ($secondsString >= 24) {
				$secondsString = $secondsString / 24;

				if ($secondsString >= 365) {
					$secondsString = $secondsString / 365;

					$secondsString = floor($secondsString) . ' years';
				}
				elsif ($secondsString >= 30) {
					$secondsString = $secondsString / 30;

					$secondsString = floor($secondsString) . ' months';
				}
				else {
					$secondsString = floor($secondsString) . ' days';
				}
			}
			else {
				$secondsString = floor($secondsString) . ' hours';
			}
		}
		else {
			$secondsString = floor($secondsString) . ' minutes';
		}
	} else {
		$secondsString = floor($secondsString) . ' seconds';
	}
} # GetSecondsHtml()

require './widget.pl';

while (my $arg1 = shift @foundArgs) {
	print $arg1;
	# go through all the arguments one at a time
	if ($arg1) {
		if ($arg1 eq '--theme') {
			print ("recognized token --theme");
			my $themeArg = shift @foundArgs;
			chomp $themeArg;
			GetConfig('html/theme', 'override', $themeArg);
		}
		elsif (IsItem($arg1)) {
			print ("recognized item identifier\n");
			MakePage('item', $arg1, 1);
		}
		elsif (IsItemPrefix($arg1)) {
			print ("recognized item prefix\n");
			MakePage('prefix', $arg1, 1);
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
		elsif ($arg1 eq '--php') {
			print ("recognized --php\n");
			MakePhpPages();
		}
		elsif ($arg1 eq '--js') {
			print ("recognized --js\n");
			MakeJsPages();
		}
		elsif ($arg1 eq '--settings') {
			print ("recognized --settings\n");
			my $settingsPage = GetSettingsPage();
			PutHtmlFile('settings.html', $settingsPage);
		}
		elsif ($arg1 eq '--tags') {
			print ("recognized --tags\n");
			MakePage('tags');
		}
		elsif ($arg1 eq '--write') {
			print ("recognized --write\n");
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
				$submitPage =~ s/cols=32/cols=50/g;
				$submitPage =~ s/rows=9/rows=15/g;
				$submitPage =~ s/please click here/you're in the right place/g;
				PutHtmlFile("write_post.html", $submitPage);
			}

		}
		elsif ($arg1 eq '--index' || $arg1 eq '-i') {
			print ("recognized --index\n");
			WriteIndexPages();
		}
		elsif ($arg1 eq '--data' || $arg1 eq '-i') {
			print ("recognized --data\n");
			WriteDataPage();
		}
		elsif ($arg1 eq '--desktop' || $arg1 eq '-i') {
			print ("recognized --desktop\n");
			PutHtmlFile('desktop.html', GetDesktopPage());
		}
		elsif ($arg1 eq '--queue' || $arg1 eq '-Q') {
			print ("recognized --queue\n");
			BuildTouchedPages();
		}
		elsif ($arg1 eq '--all' || $arg1 eq '-a') {
			print ("recognized --all\n");
			print `query/touch_all.sh`;
			MakeSummaryPages();
			BuildTouchedPages();
		}
		elsif ($arg1 eq '-M') { # makepage
			print ("recognized -M\n");
			my $makePageArg = shift @foundArgs;
			#todo sanity check of $makePageArg
			if ($makePageArg) {
				print ("calling MakePage($makePageArg)\n");
				MakePage($makePageArg);
			} else {
				print("missing argument for -M\n");
			}
		}
		else {
			print ("Available arguments:\n");
			print ("--summary or -s for all summary or system pages\n");
			print ("--php for all php pages\n");
			print ("--queue or -Q for all pages in queue\n");
			print ("--index or -i for all index pages\n");
			print ("item id for one item's page\n");
			print ("author fingerprint for one item's page\n");
			print ("#tag for one tag's page\n");
		}
	}
}

1;
