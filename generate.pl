#!/usr/bin/perl

# generate.pl
#
# generates all the static html files
# summary/static files like write.html and stats.html
# all the item files like /ab/cd/abcdef0123.html
#
# the idea is to re-generate all of the frontend,
# and this is largely successful
#
# happens in 3 steps:
# 1. query/touch_all.sh, which sets task.priority++
# 2. calls pages.pl --all, which builds all the touched pages
# 3. some legacy stuff follows, which is not yet covered by MakePage()
#
# the large commented out areas is what's already been
# replaced by MakePage() calls in update.pl
#

print "Loading...\n";

use strict;
use warnings FATAL => 'all';
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
require './pages.pl';

print "MakeSummaryPages()...\n";
MakeSummaryPages();

print `query/touch_all.sh`;

print "pages.pl --queue ...\n";
print `time ./pages.pl --queue`;

#
#
# MakeSummaryPages();
#
# WriteLog("GetReadPage()...");
#
# #my $indexText = GetReadPage();
#
# #PutHtmlFile("index.html", $indexText);
# {
# 	WriteLog("Author pages...");
#
# 	my @authors = DBGetAuthorList();
# 	#my @authors = ();
#
# 	WriteLog('@authors: ' . scalar(@authors));
#
# 	my $authorInterval = 3600;
#
# 	my $authorsCount = scalar(@authors);
# 	my $authorsIndex = 0;
#
# 	foreach my $hashRef (@authors) {
# 		my $key = $hashRef->{'key'};
#
# 		WriteLog('Making stuff for author: ' . $hashRef->{'key'});
#
# 		WriteLog("Ensure $HTMLDIR/author/$key exists...");
#
# 		if (!-e "$HTMLDIR/author") {
# 			mkdir("$HTMLDIR/author");
# 		}
#
# 		if (!-e "$HTMLDIR/author") {
# 			WriteLog("Something went wrong with creating $HTMLDIR/author");
# 		}
#
# 		if (!-e "$HTMLDIR/author/$key") {
# 			mkdir("$HTMLDIR/author/$key");
# 		}
#
# 		if (!-e "$HTMLDIR/author/$key") {
# 			WriteLog("Something went wrong with creating $HTMLDIR/author/$key");
# 		}
#
# 		$authorsIndex++;
# 		my $percent = ($authorsIndex / $authorsCount * 100);
#
# 		WriteMessage("GetReadPage(author) $authorsIndex / $authorsCount ( $percent % ) $key");
#
# 		my $authorIndex = GetReadPage('author', $key);
#
# 		WriteLog("$HTMLDIR/author/$key/index.html");
#
# 		PutHtmlFile("author/$key/index.html", $authorIndex);
#
# 		PutCache("key/$key", GetTime());
# 	}
# }
#
# my %queryParams;
#
# $queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
# my @rssFiles = DBGetItemList(\%queryParams);
#
# PutFile("$HTMLDIR/rss.xml", GetRssFile(@rssFiles));
#
#

#
# if (0) {
# 	# generate commits pages
# 	my $versionPageCount = 5;
#
# 	my $commits = `git log -n $versionPageCount | grep ^commit`;
#
# 	WriteLog('$commits = git log -n $versionPageCount | grep ^commit');
#
# 	if ($commits) {
# 		my $currentCommit = 0;
# 		foreach(split("\n", $commits)) {
#
# 			my $commit = $_;
# 			$commit =~ s/^commit //;
# 			chomp($commit);
#
# 			$currentCommit++;
#
# 			if (IsSha1($commit)) {
# 				my $percent = ($currentCommit / $versionPageCount) * 100;
# 				WriteMessage("*** GetVersionPage: $currentCommit/$versionPageCount ($percent %) " . $commit);
#
# 				my $htmlSubDir = 'html/' . substr($commit, 0, 2) . '/' . substr($commit, 2, 2);
# 				my $htmlFilename = $commit;
# 				if (!-e $htmlSubDir) {
# 					mkdir($htmlSubDir);
# 				}
# 				WriteLog("html/$commit.html");
# 				PutHtmlFile("$htmlSubDir/$htmlFilename.html", GetVersionPage($commit));
# 			} else {
# 				WriteLog("generate.pl... Found non-SHA1 where SHA1 expected!!!");
# 			}
# 		}
# 	}
# }
#
# WriteIndexPages();
#
# WriteMessage("GetTagsPage()...");
# my $tagsPage = GetTagsPage();
# PutHtmlFile("tags.html", $tagsPage);
#
# WriteMessage("GetEventsPage()...");
# my $eventsPage = GetEventsPage();
# PutHtmlFile("events.html", $eventsPage);
#
# WriteMessage("GetScoreboardPage()...");
# my $scoreboardPage = GetScoreboardPage();
# PutHtmlFile('authors.html', $scoreboardPage);
# PutHtmlFile('author/index.html', $scoreboardPage);

##########################################


WriteMessage("DBGetVoteCounts()...");

my $voteCounts = DBGetVoteCounts();
my @voteCountsArray = @{$voteCounts};

my @allTagsList;
#
# while (@voteCountsArray) {
# 	my $tag = pop @voteCountsArray;
#
# 	my $tagName = @{$tag}[0];
# 	#my $tagCount = @{$tag}[1];
#
# 	WriteMessage("GetReadPage('tag', '$tagName')");
#
# 	my $indexPage = GetReadPage('tag', $tagName);
#
# 	unshift @allTagsList, $tagName;
#
# 	PutHtmlFile('top/' . $tagName . '.html', $indexPage);
# }

WriteMessage("DBGetAllAppliedTags()...");
my @tagsList = DBGetAllAppliedTags();

WriteLog("DBGetAllAppliedTags() returned " . scalar(@tagsList) . " items");

if (GetConfig('tag_cloud_page')) {
	foreach my $tag1 (@tagsList) {
		WriteLog("DBGetAllAppliedTags: $tag1...");
		foreach my $tag2 (@tagsList) {
			WriteLog("DBGetAllAppliedTags: $tag1 $tag2");
			my @items = DBGetItemListByTagList($tag1, $tag2);

			if (scalar(@items) >= 5) {
				WriteLog("Returned: ". scalar(@items));

				WriteMessage("Writing tags page for $tag1 together with $tag2");

				my $testPage;
				$testPage = GetIndexPage(\@items);

				WriteLog("top/$tag1\_$tag2.html");

				PutHtmlFile("top/$tag1\_$tag2.html", $testPage);

				unshift @allTagsList, "$tag1\_$tag2";
			} else {
				WriteLog("Returned: ". scalar(@items));
			}
		}
	}
}
#
# WriteMessage("GetTopItemsPage()");
#
# #my $topItemsPage = GetTopItemsPage();
# my $topItemsPage = GetTopItemsPage();
# PutHtmlFile('read.html', $topItemsPage);
#
@allTagsList = sort @allTagsList;

if (GetConfig('tag_cloud_page')) {
	my $tagCloudPage = '';
	foreach my $tag (@allTagsList) {
		my $linkTitle = $tag;
		$linkTitle =~ s/_/+/;
	#	$linkTitle =~ s/\_/+/;
		$tagCloudPage .= '<a href="top/' . $tag . '.html">' . $linkTitle . '</a><br>';
	}
	PutHtmlFile('tagcloud.html', $tagCloudPage);
}

# MakeDataPage();
#
# my $homePageHasBeenWritten = PutHtmlFile('check_homepage'); # this is not a mistake, but a special command in PutHtmlFile()
# # returns true if index.html has been written, false if not
#
# if ($homePageHasBeenWritten) {
# 	WriteLog("Home Page has been written! Yay!");
# } else {
# 	WriteLog("warning: Home Page has not been written! Fixing that");
#
# 	if (-e $HTMLDIR.'/'.GetConfig('html/home_page')) {
# 		PutHtmlFile('index.html', GetFile($HTMLDIR . '/' . GetConfig('home_page')));
# 	} elsif (-e $HTMLDIR.'/read.html') {
# 		PutHtmlFile('index.html', GetFile($HTMLDIR.'/read.html'));
# 	} elsif (-e $HTMLDIR.'/write.html') {
# 		PutHtmlFile('index.html', GetFile($HTMLDIR.'/write.html'));
# 	} else {
# 		WriteLog('fallback for index.html');
# 		my $fallbackHomepage =
# '<html><body><h1>Placeholder</h1>
# <p>There was a problem writing homepage. Please contact your administrator for resolution.</p>
# <p>Try one of these links in the mean time:</p>
# <p><a href="/read.html">Top Posts</a></p>
# <p><a href="/write.html">Writing Something</a></p>
# <p><a href="/stats.html">Check the Server Status</a></p>';
#
# 		PutHtmlFile('index.html', $fallbackHomepage);
# 	}
#
# 	$homePageHasBeenWritten = PutHtmlFile('check_homepage');
# 	if ($homePageHasBeenWritten) {
#
# 	}
# }

1;
