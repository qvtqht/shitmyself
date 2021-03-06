#!/usr/bin/perl -T

use strict;
use warnings;
use utf8;

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

#require('./utils.pl');
#require('./pages.pl');

sub MakePage { # $pageType, $pageParam, $priority ; make a page and write it into $HTMLDIR directory; $pageType, $pageParam
# supported page types so far:
# tag, #hashtag
# author, ABCDEF01234567890
# item, 0123456789abcdef0123456789abcdef01234567
# authors
# read
# prefix
# summary (deprecated)
# tags
# stats
# index
# compost

	my $HTMLDIR = GetDir('html');

	# $pageType = author, item, tags, etc.
	# $pageParam = author_id, item_hash, etc.
	my $pageType = shift;
	my $pageParam = shift;
	my $priority = shift;

	if (!$priority) {
		$priority = 0;
	}

	#todo sanity checks

	if (!defined($pageParam)) {
		$pageParam = 0;
	}

	WriteMessage('MakePage(' . $pageType . ', ' . $pageParam . ')');

	# tag page, get the tag name from $pageParam
	if ($pageType eq 'tag') {
		my $tagName = $pageParam;
		my $targetPath = "top/$tagName.html";

		WriteLog("MakePage: tag: $tagName");
		my $tagPage = GetReadPage('tag', $tagName);
		PutHtmlFile($targetPath, $tagPage);
	}
	#
	# author page, get author's id from $pageParam
	elsif ($pageType eq 'author') {
		if ($pageParam =~ m/^([0-9A-F]{16})$/) {
			$pageParam = $1;
		} else {
			WriteLog('MakePage: author: warning: $pageParam sanity check failed. returning');
			return '';
		}

		my $authorKey = $pageParam;
		my $targetPath = "author/$authorKey/index.html";

		WriteLog('MakePage: author: ' . $authorKey);

		my $authorPage = GetReadPage('author', $authorKey);
		if (!-e "$HTMLDIR/author/$authorKey") {
			mkdir ("$HTMLDIR/author/$authorKey");
		}
		PutHtmlFile($targetPath, $authorPage);

		if (IsAdmin($authorKey) == 2) {
			MakeSummaryPages();
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

		# get item list using DBGetItemList()
		# #todo clean this up a little, perhaps crete DBGetItem()
		my @files = DBGetItemList({'where_clause' => "WHERE file_hash LIKE '$fileHash%'"});

		if (scalar(@files)) {
			my $file = $files[0];
			if ($HTMLDIR =~ m/^(^\s+)$/) { #security #taint #todo
				$HTMLDIR = $1; # untaint
				# create a subdir for the first 2 characters of its hash if it doesn't exist already
				if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2))) {
					mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2)));
				}
				if (!-e ($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2))) {
					mkdir(($HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2, 2)));
				}
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
#		my $tagsPage = GetTagsPage('Tags', 'Tags', '');
		my $tagsPage = GetQueryPage('tags');
		PutHtmlFile("tags.html", $tagsPage);

		my $votesPage = GetTagsPage('Votes', 'Votes', 'ORDER BY vote_value');
		PutHtmlFile("votes.html", $votesPage);

		my $tagsHorizontal = GetTagLinks();
		PutHtmlFile('tags-horizontal.html', $tagsHorizontal);
	}
#	#
#	# events page
#	elsif ($pageType eq 'events') {
#		my $eventsPage = GetEventsPage();
#		PutHtmlFile("events.html", $eventsPage);
#	}
	#
	# authors page
	elsif ($pageType eq 'authors') {
		#my $authorsPage = GetAuthorsPage();
		my $authorsPage = GetQueryPage('authors');
		PutHtmlFile("authors.html", $authorsPage);
	}
	#
	# topitems page
	elsif ($pageType eq 'read') {
		my $topItemsPage = GetQueryPage('read', 'Top Threads', 'item_title,author_key,add_timestamp');
#		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile("read.html", $topItemsPage);
	}
	elsif ($pageType eq 'compost') {
		my $compostPage = GetQueryPage('compost');
#		my $compostPage = GetQueryPage('compost', 'Compost', 'item_title,author_key,add_timestamp');
#		my $topItemsPage = GetTopItemsPage();
		PutHtmlFile("compost.html", $compostPage);
	}
	elsif ($pageType eq 'settings') {
		# Settings page
		my $settingsPage = GetSettingsPage();
		PutHtmlFile("settings.html", $settingsPage);
	}
	#
	# stats page
	elsif ($pageType eq 'stats') {
		PutStatsPages();
	}
	#
	# index pages (queue)
	elsif ($pageType eq 'index') {
		my $touchIndexPages = GetCache('touch/index_pages');
		if (!$touchIndexPages) {
			$touchIndexPages = 0;
		}
		if ((time() - $touchIndexPages) > 1) {
			#do nothing
		} else {
			WriteIndexPages();
			PutCache('touch/index_pages', time());
		}
	}
	#
	# item prefix page
	elsif ($pageType eq 'prefix') {
		my $itemPrefix = $pageParam;
		my $itemsPage = GetItemPrefixPage($itemPrefix);
		PutHtmlFile(substr($itemPrefix, 0, 2) . '/' . substr($itemPrefix, 2, 2) . '/index.html', $itemsPage);
	}
	#
	# profile
	elsif ($pageType eq 'profile') {
		# Profile page
		my $profilePage = GetProfilePage();
		PutHtmlFile("profile.html", $profilePage);
	}
	#
	# rss feed
	elsif ($pageType eq 'rss') {
		#todo break out into own module and/or auto-generate rss for all relevant pages

		my %queryParams;

		$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
		$queryParams{'limit_clause'} = 'LIMIT 200';
		my @rssFiles = DBGetItemList(\%queryParams);

		PutFile("$HTMLDIR/rss.xml", GetRssFile(@rssFiles));
	}
	#
	# summary pages
	elsif ($pageType eq 'summary') {
		MakeSummaryPages();
	}

	WriteLog("MakePage: finished, calling DBDeletePageTouch($pageType, $pageParam)");
	DBDeletePageTouch($pageType, $pageParam);
} # MakePage()

1;