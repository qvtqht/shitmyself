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

sub PopulateColors {
	my $theme = 'default';
	
	my $clockColor = ''; 
	
}

sub GenerateSomeKindOfPage { # generates page html (doesn't do anything atm)
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

sub GetStylesheet { # returns style template based on config
	my $style = GetTemplate('css/default.css.template');
	# baseline style

	if (GetConfig('html/color_avatars')) {
		$style .= "\n" . GetTemplate('style.avatar.template');
		# add style for color avatars if that's the setting
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
		$authorAvatar = GetPlainAvatar($gpgKey);
	} else {
		$authorAvatar = GetAvatar($gpgKey);
	}

	chomp $authorAvatar;
	my $authorLink = GetTemplate('authorlink.template');

	$authorLink =~ s/\$authorUrl/$authorUrl/g;
	$authorLink =~ s/\$authorAvatar/$authorAvatar/g;

	return $authorLink;
}

sub GetPageLink { # returns one pagination link as html, used by GetPageLinks
	my $pageNumber = shift;

	my $pageLimit = GetConfig('page_limit');
	
	my $pageStart = $pageNumber * $pageLimit;
	my $pageEnd = $pageNumber * $pageLimit + $pageLimit;
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

sub GetPageLinks { # returns html for pagination links
# $currentPageNumber = current page  
	state $pageLinks;

	my $currentPageNumber = shift;

	my $pageLimit = GetConfig('page_limit');
	
	WriteLog("GetPageLinks($currentPageNumber)");

	if (defined($pageLinks)) {
		WriteLog("GetPageLinks: \$pageLinks already exists, doing a quickie");

		my $currentPageTemplate = GetPageLink($currentPageNumber);
		
		my $currentPageStart = $currentPageNumber * $pageLimit;
		my $currentPageEnd = $currentPageNumber * $pageLimit + $pageLimit;
		my $currentPageCaption = $currentPageStart . '-' . $currentPageEnd;

		my $pageLinksFinal = $pageLinks;
		$pageLinksFinal =~ s/$currentPageTemplate/<b>$currentPageCaption<\/b> /g;

		return $pageLinksFinal;
	}

	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

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
			$pageLinkTemplate = GetPageLink($i);
			#			}

			$pageLinks .= $pageLinkTemplate;
		}
	}

	my $frame = GetTemplate('pagination.template');

	$frame =~ s/\$paginationLinks/$pageLinks/;

	$pageLinks = $frame;

	#todo explain recursion
	return GetPageLinks($currentPageNumber);
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

	while (@eventsArray) {
		my $event = shift @eventsArray;

		my $eventItemHash = %{$event}{'file_hash'};
		my $eventTitle =  %{$event}{'item_title'};
		my $eventTime = %{$event}{'event_time'};
		my $eventDuration = %{$event}{'event_duration'};
		my $eventItemLink = GetHtmlLink($eventItemHash);
		my $eventItemAuthor = %{$event}{'author_key'};

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

		my $eventItem = GetTemplate('event/event_item.template');

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

		$eventsItemsList .= $eventItem;
	}

	my $eventsList = GetTemplate('event/event_list.template');

	$eventsList =~ s/\$eventsList/$eventsItemsList/;

	$txtPage .= $eventsList;

	$txtPage .= GetPageFooter();

	$txtPage = InjectJs($txtPage, qw(avatar fresh prefs timestamps voting profile));

	return $txtPage;

}

sub GetVotesPage { # returns html for tags listing page (sorted by number of uses)
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

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs profile));

	return $txtIndex;
}

sub GetTagsPage { # returns html for tags listing page (alphabetically sorted)
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags Alphabetical';
	my $titleHtml = 'Tags Alphabetical';

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

#sub GetItemTemplateFromHash { # takes a hash, returns an item in html format
##todo sanity checks etc
#	my $itemHash = shift;
#	my $templateName = shift;
#
#	my $itemTemplate = '';
#
#	if (IsSha1($itemHash)) {
#
#		my %queryParams;
#		$queryParams{'where_clause'} = "WHERE file_hash IN('$itemHash')";
#
#		my @files = DBGetItemList(\%queryParams);
#
#		WriteLog(Data::Dumper->Dump(@files));
#		
#		sleep 10;
#		
##			my $thisItem = @files[0];
##			$thisItem{'template_name' = 'item/item-small.template';
##
#		#$itemTemplate = GetItemTemplate($files[0]);
#	#		} else {
#	#			$itemTemplate = GetHtmlLink($itemHash);
#	#		}
#	#		return $itemTemplate;
#	#	} else {
#	#		WriteLog("Warning! GetItemTemplateFromHash called with improper parameter!");
#	#		return '[item could not be displayed]';
#		}
#	#
#	#	WriteLog("Something is terribly wrong! GetItemTemplateFromHash");
#	#	return '[aaaaahhhh!!!]';
#	
#	return $itemTemplate;
#}
#
sub GetThreadPage { # returns page with entire discussion thread for a top-level item (incomplete)
	my $threadParent = shift;
	if (!IsItem($threadParent)) {
		return;
	}
	
	
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

	$txtIndex = InjectJs($txtIndex, qw(avatar formencode prefs fresh voting profile));

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
}

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
# $fileHash = item's file hash
# $tagset (optional) use a particular tagset instead of item's default
	my $fileHash = shift;
	my $tagSet = shift;

	#todo sanity checks

	my @quickVotesList;

	my %voteTotals = DBGetItemVoteTotals($fileHash);
	
	if ($tagSet) {
		my $quickVotesForTagSet = GetConfig('tagset/' . $tagSet);
		if ($quickVotesForTagSet) {
			push @quickVotesList, split("\n", $quickVotesForTagSet);
		}
	} else {
		my $quickVotesForTags;

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

			if ($voteTotals{$quickTagCaption}) {
				$quickTagCaption .= '(' . $voteTotals{$quickTagCaption} . ')';
				$quickTagCaption = '<b><big>' . $quickTagCaption . '</big></b>';
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
			}
		}

		if ($isTextart) {
			# if textart, format with extra spacing to preserve character arrangement
			$message = TextartForWeb($message);
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
				$itemTemplate = GetTemplate("item/itemlong.template");
			} else {
				# otherwise use template/item/item.template
				$itemTemplate = GetTemplate("item/item.template");
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

			# generate $authorLink from template
			$authorLink = GetTemplate('authorlink.template');
			
			$authorLink =~ s/\$authorUrl/$authorUrl/g;
			$authorLink =~ s/\$authorAvatar/$authorAvatar/g;
		} else {
			# if no author, no $authorLink
			$authorLink = "";
		}

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
		my $itemName; # item's 'name'
		
		if ($file{'display_full_hash'}) {
			# if display_full_hash is set, display the item's entire hash for name
			$itemName = $fileHash;
		} else {
			# if display_full_hash is not set, truncate the hash to 8 characters
			$itemName = substr($fileHash, 0, 8) . '..';
		}

		#my $replyCount = $file{'child_count'};

		my $borderColor = '#' . substr($fileHash, 0, 6); # item's border color

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
				$votesSummary = '<p class=advanced><b class=beginner>Attributes:</b> ' . $votesSummary . '</p>';
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

			$quickVotesForTags = GetConfig('tagset/' . 'all');
			if ($quickVotesForTags) {
				unshift @quickVotesList, split("\n", $quickVotesForTags);
			}

			my %dedupe = map { $_, 1 } @quickVotesList;
			@quickVotesList = keys %dedupe;

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
						
						if ($voteTotals{$quickTagCaption}) {
							$quickTagCaption .= '(' . $voteTotals{$quickTagCaption} . ')';
							$quickTagCaption = '<b>' . $quickTagCaption . '</b>';
						}
						
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

sub GetPageFooter { # returns html for page footer
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

	#todo templatify
	my $footer = "<span class=advanced><span class=beginner>Printed: </span>" . GetTimestampElement($timeBuilt) . " ; <span class=beginner>Version </span>$myVersionPrettyLink</span> ; ";

	my $footerMenuTemplate = '';

	#footer menu
	$footerMenuTemplate .= GetMenuItem("/stats.html", 'Status');
	$footerMenuTemplate .= GetMenuItem("/top/admin.html", 'Admin');
	$footerMenuTemplate .= GetMenuItem("/data.html", 'Data');
	$footerMenuTemplate .= GetMenuItem("/index0.html", 'Abyss');
	$footerMenuTemplate .= GetMenuItem("/tags.html", GetString('menu/tags'));
	$footerMenuTemplate .= GetMenuItem("/manual.html", GetString('menu/manual'));

	$footer .= $footerMenuTemplate;

	$txtFooter =~ s/\$footer/$footer/;

	my $ssiFooter;
	if (GetConfig('admin/ssi/enable') && GetConfig('admin/ssi/footer_timestamp')) {
		$ssiFooter = '<p class=advanced><font color="#808080"><small>' . GetTimestampElement(trim(GetTemplate('ssi/print_date.ssi.template'))) . '</small></font></p>'; #todo templatify
	} else {
		$ssiFooter = '';
	}
	$txtFooter =~ s/\$ssiFooter/$ssiFooter/;

	return $txtFooter;
}

my $primaryColor;
my $secondaryColor;
my $textColor;

sub GetPageHeader { # returns html for page header
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
		$logoText = GetConfig('logo_text');
		if (!$logoText) {
			#$logoText = random_emoji();
			#$logoText = encode_entities($logoText, '^\n\x20-\x25\x27-\x7e');
			#$logoText = "*"
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


	my $identityLink = '<span id="signin"></span> <span class="myid" id=myid></span> ';

	$topMenuTemplate .= GetMenuItem("/", 'Read');
	$topMenuTemplate .= GetMenuItem("/write.html", GetString('menu/write'));
	$topMenuTemplate .= GetMenuItem("/top.html", 'Topics');
	$topMenuTemplate .= GetMenuItem("/events.html", 'Events');
	$topMenuTemplate .= GetMenuItem("/authors.html", 'Authors');
	$topMenuTemplate .= GetMenuItem("/prefs.html", 'Prefs', 1);
	$topMenuTemplate .= GetMenuItem("/stats.html", 'Status', 1);
	$topMenuTemplate .= GetMenuItem("/tags.html", 'Tags', 1);
	$topMenuTemplate .= GetMenuItem("/index0.html", 'Abyss', 1);
	$topMenuTemplate .= GetMenuItem("/manual.html", 'Help');
	$topMenuTemplate .= $identityLink;

	$htmlStart =~ s/\$menuItems/$topMenuTemplate/g;

#	my $adminKey = GetAdminKey();
#	if ($adminKey) {
#		$topMenuTemplate .= GetMenuItem('/author/' . $adminKey . '/', 'Admin');
#	}


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
	
	$txtIndex .= '<p><b><a href="/write.html">Start a new topic</a></b></p>'; #todo templatize

	$txtIndex .= GetTemplate('maincontent.template');

	my @topItems = DBGetTopItems();
							 
	if (scalar(@topItems)) {
		my $itemListingWrapper = GetTemplate('item_listing_wrapper.template');

		my $itemListings = '';

		while (@topItems) {
			my $itemTemplate = GetTemplate('item_listing.template');
			#todo don't need to do this every time

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
				$authorAvatar = GetAuthorLink($authorKey, 1);
			} else {
				$authorAvatar = '';
			}
			
			$itemLastTouch = GetTimestampElement($itemLastTouch);

			$itemTemplate =~ s/\$link/$itemLink/g;
			$itemTemplate =~ s/\$itemTitle/$itemTitle/g;
			$itemTemplate =~ s/\$itemScore/$itemScore/g;
			$itemTemplate =~ s/\$authorAvatar/$authorAvatar/g;
			$itemTemplate =~ s/\$itemLastTouch/$itemLastTouch/g;

			$itemListings .= $itemTemplate;
		}

		$itemListingWrapper =~ s/\$itemListings/$itemListings/;

		$txtIndex .= $itemListingWrapper;
	} else {
		$txtIndex .= "<p class=beginner>Couldn't find any items to put on this page. Recommend that you post something or contact your operator.</p><p>No matches.</p>";
		#todo should be in template/
	}

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs voting timestamps profile));

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
	
	my $statsTable = GetTemplate('stats.template');

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

	$statsTable =~ s/\$versionFull/$versionFull/;
	$statsTable =~ s/\$versionShort/$versionShort/;
	$statsTable =~ s/\$itemCount/$itemCount/;
	$statsTable =~ s/\$authorCount/$authorCount/;

	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	$statsPage = InjectJs($statsPage, qw(avatar fresh prefs timestamps pingback profile));

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

		my $authorLink = "/author/" . $authorKey . "/";

#		my $authorFriendKey = %{$authorFriend}{'author_key'};

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

	$authorListingWrapper =~ s/\$authorListings/$authorListings/;

	$txtIndex .= $authorListingWrapper;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs timestamps profile));

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
		my $authorScore = DBGetAuthorScore($authorKey) || 0;
		my $itemCount = DBGetAuthorItemCount($authorKey);
		my $authorDescription = '';
		my $authorWeight = DBGetAuthorWeight($authorKey);
		my $authorLastSeen = DBGetAuthorLastSeen($authorKey) || 0;

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
			$authorDescription .= '<b>Admin.</b>';
		}

		if ($authorDescription) {
			$authorDescription .= '<br>';
		}
		$authorDescription .= GetItemVotesSummary($publicKeyHash);

		my $profileVoteButtons = GetItemVoteButtons($publicKeyHash);
		
		$authorLastSeen = GetTimestampElement()

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
		$txtIndex = InjectJs($txtIndex, qw(avatar prefs timestamps voting profile));
	} else {
		$txtIndex = InjectJs($txtIndex, qw(avatar prefs voting profile));
	}

	return $txtIndex;
} # /GetReadPage


sub GetMenuItem { # returns html snippet for a menu item (used for both top and footer menus)
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

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);
	
	$htmlStart =~ s/<main id=maincontent><a name=maincontent><\/a>//;
	# todo fix this hack

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

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs voting profile fresh));

	return $txtIndex;
}

sub WriteIndexPages { # writes the abyss pages (index0-n.html)
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

sub MakeFormPages { #generates and writes all 'form' pages (doesn't do anything atm)
}

sub MakeSummaryPages { # generates and writes all "summary" and "static" pages
# write, add event, stats, profile management, preferences, post ok, action/vote, action/event
	WriteLog('MakeSummaryPages() BEGIN');

	# Submit page
	my $submitPage = GetWritePage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);

	# Add Event page
	my $eventAddPage = GetEventAddPage();
	PutHtmlFile("$HTMLDIR/event.html", $eventAddPage);


	# Stats page
	my $statsPage = GetStatsPage();
	PutHtmlFile("$HTMLDIR/stats.html", $statsPage);


	# Profile page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/profile.html", $identityPage);

	# Preferences page
	my $prefsPage = GetPrefsPage();
	PutHtmlFile("$HTMLDIR/prefs.html", $prefsPage);


	# Target page for the submit page
	my $postPage = GetPageHeader("Thank You", "Thank You", 'post');
	$postPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	$postPage .= GetTemplate('maincontent.template');

	my $postTemplate = GetTemplate('page/post.template');

	$postPage .= $postTemplate;

	$postPage .= GetPageFooter();

	$postPage = InjectJs($postPage, qw(avatar post prefs));

	$postPage =~ s/<body /<body onload="makeRefLink();" /;

	PutHtmlFile("$HTMLDIR/post.html", $postPage);


	# Ok page
	my $okPage = GetTemplate('action_ok.template');

	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	#$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote2.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/event.html", $okPage);
		
	system('cp default/template/p.gif.template html/p.gif');

	{
		# Manual page
		my $tfmPage = GetPageHeader("Manual", "Manual", 'manual');

		$tfmPage .= GetTemplate('maincontent.template');

		my $tfmPageTemplate = GetTemplate('page/manual.template');

		$tfmPage .= $tfmPageTemplate;

		$tfmPage .= '<p>' . GetTemplate('netnow3.template') . '</p>';

		$tfmPage .= GetPageFooter();

		$tfmPage = InjectJs($tfmPage, qw(avatar prefs profile));

		PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);

	}

	{
		# Advanced Manual page
		my $tfmPage = GetPageHeader("Advanced Manual", "Advanced Manual", 'manual_advanced');

		$tfmPage .= GetTemplate('maincontent.template');

		my $tfmPageTemplate = GetTemplate('page/manual_advanced.template');

		my $writeForm = GetTemplate('form/write2.template');
		#$writeForm =~ s/\$prefillText/I've read the advanced manual, and here is what I think:\n\n/;
		$tfmPageTemplate =~ s/\$writeForm/$writeForm/g;

		$tfmPage .= $tfmPageTemplate;

		$tfmPage .= '<p>' . GetTemplate('netnow3.template') . '</p>';

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

	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
		if ($itemCount < $itemLimit) {
			my $submitForm = GetTemplate('form/write2.template');
			#my $submitForm = GetTemplate('form/write.template');

			if (GetConfig('admin/php/enable')) {
				$submitForm =~ s/\<textarea/<textarea onkeyup="if (this.length > 2) { document.forms['compose'].action='\/post2.php'; }" /;
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

		$txtIndex = InjectJs($txtIndex, qw(avatar writeonload prefs profile));

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

	$txtIndex = InjectJs($txtIndex, qw(avatar writeonload prefs event_add fresh profile));

#	$txtIndex =~ s/<body /<body onload="writeOnload();" /;

	return $txtIndex;
}

sub GetIdentityPage { #todo rename GetProfilePage?
	my $txtIndex = "";

	my $title = "Profile";
	my $titleHtml = "Profile";

	$txtIndex = GetPageHeader($title, $titleHtml, 'identity');

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('form/identity.template');

	my $idCreateForm = GetTemplate('form/id_create.template');
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

	if (GetConfig('admin/gpg/use_gpg2')) {
		my $gpg2Choices = GetTemplate('gpg2.choices.template');
		$idPage =~ s/\$gpg2Algochoices/$gpg2Choices/;
	} else {
		$idPage =~ s/\$gpg2Algochoices//;
	}

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs fresh profile));

	my $scriptsInclude = '<script src="/zalgo.js"></script><script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="identityOnload();" /;

	return $txtIndex;
}

sub GetPrefsPage { # returns html for preferences page (/prefs.html)
	my $txtIndex = "";

	my $title = "Preferences";
	my $titleHtml = "Preferences";

	$txtIndex = GetPageHeader($title, $titleHtml, 'preferences');

	$txtIndex .= GetTemplate('maincontent.template');

	my $prefsPage = GetTemplate('form/preferences.template');

	$txtIndex .= $prefsPage;

	$txtIndex .= GetPageFooter();

	$txtIndex = InjectJs($txtIndex, qw(avatar prefs fresh profile));

	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="identityOnload();" /;

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
		WriteLog("Making zip file...");

#		system("git archive --format zip --output html/hike.tmp.zip master");
#		#system("git archive -v --format zip --output html/hike.tmp.zip master");

		system("zip -qr $HTMLDIR/hike.tmp.zip html/txt/ log/votes.log");
		#system("zip -qrv $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");

		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");

		PutCache('last_zip', GetTime());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}


	my $dataPage = GetPageHeader("Data", "Data", 'data');

	$dataPage .= GetTemplate('maincontent.template');

	my $dataPageTemplate = GetTemplate('data.template');

	my $sizeHikeZip = -s "$HTMLDIR/hike.zip";

	$sizeHikeZip = GetFileSizeHtml($sizeHikeZip);
	if (!$sizeHikeZip) {
		$sizeHikeZip = 0;
	}

	$dataPageTemplate =~ s/\$sizeHikeZip/$sizeHikeZip/g;

	$dataPage .= $dataPageTemplate;

	$dataPage .= GetPageFooter();

	$dataPage = InjectJs($dataPage, qw(avatar prefs profile));

	PutHtmlFile("$HTMLDIR/data.html", $dataPage);
}


1;