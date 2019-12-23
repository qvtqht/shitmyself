#!/usr/bin/perl

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

my $HTMLDIR = "html";


MakeSummaryPages();

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Author pages...");

my @authors = DBGetAuthorList();
#my @authors = ();

WriteLog('@authors: ' . scalar(@authors));

my $authorInterval = 3600;

my $authorsCount = scalar(@authors);
my $authorsIndex = 0;

foreach my $hashRef (@authors) {
	my $key = $hashRef->{'key'};

	WriteLog('Making stuff for author: ' . $hashRef->{'key'});

	my $lastTouch = GetCache("key/$key");
	if ($lastTouch && $lastTouch + $authorInterval > GetTime()) {
		#WriteLog("I already did $key recently, too lazy to do it again");
		#next;
		#todo uncomment
	}

	WriteLog("$HTMLDIR/author/$key");

	if (!-e "$HTMLDIR/author") {
		mkdir("$HTMLDIR/author");
	}

	if (!-e "$HTMLDIR/author/$key") {
		mkdir("$HTMLDIR/author/$key");
	}

	$authorsIndex++;
	my $percent = ($authorsIndex / $authorsCount * 100);

	WriteMessage("GetReadPage (author) $authorsIndex / $authorsCount ( $percent % ) $key");

	my $authorIndex = GetReadPage('author', $key);

	WriteLog("$HTMLDIR/author/$key/index.html");

	PutHtmlFile("$HTMLDIR/author/$key/index.html", $authorIndex);

	PutCache("key/$key", GetTime());
}

my %queryParams;

$queryParams{'order_clause'} = 'ORDER BY add_timestamp DESC';
my @rssFiles = DBGetItemList(\%queryParams);

PutFile("$HTMLDIR/rss.xml", GetRssFile(@rssFiles));


# this should create a page for each item
{
	my %queryParams = ();
	my @files = DBGetItemList(\%queryParams);

	WriteLog("DBGetItemList() returned " . scalar(@files) . " items");

	my $fileList = "";

	my $fileInterval = 3600;

	my $filesCount = scalar(@files);
	my $currentFile = 0;

	foreach my $file(@files) {
		my $fileHash = $file->{'file_hash'};

		if (!$fileHash) {
			WriteLog("Problem! No \$fileHash in \$file");
			next;
		}

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");

			next;
		}

		$currentFile++;

		my $percent = $currentFile / $filesCount * 100;

		WriteMessage("*** GetItemPage: $currentFile/$filesCount ($percent %) " . $file->{'file_hash'});

		my $fileIndex = GetItemPage($file);

		#my $targetPath = $HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
		my $targetPath = 'html/' . GetHtmlFilename($fileHash);

		WriteLog("Writing HTML file for item");
		WriteLog("\$targetPath = $targetPath");

		if (!-e 'html/' . substr($fileHash, 0, 2)) {
			mkdir('html/' . substr($fileHash, 0, 2));
		}

		PutHtmlFile($targetPath, $fileIndex);

		PutCache("file/$fileHash", GetTime());
	}

	PutFile("$HTMLDIR/rss.txt", $fileList);
}

# generate commits page
{
	my $versionPageCount = 5;

	#todo only do this for versions mentioned in changelogs
	my $commits = `git log -n $versionPageCount | grep ^commit`;

	WriteLog('$commits = git log -n $versionPageCount | grep ^commit');

	if ($commits) {
		my $currentCommit = 0;
		foreach(split("\n", $commits)) {

			my $commit = $_;
			$commit =~ s/^commit //;
			chomp($commit);

			$currentCommit++;

			if (IsSha1($commit)) {
				my $percent = ($currentCommit / $versionPageCount) * 100;
				WriteMessage("*** GetVersionPage: $currentCommit/$versionPageCount ($percent %) " . $commit);

				my $htmlSubDir = 'html/' . substr($commit, 0, 2) . '/' . substr($commit, 2, 2);
				my $htmlFilename = $commit;
				if (!-e $htmlSubDir) {
					mkdir($htmlSubDir);
				}
				WriteLog("html/$commit.html");
				PutHtmlFile("$htmlSubDir/$htmlFilename.html", GetVersionPage($commit));
			} else {
				WriteLog("generate.pl... Found non-SHA1 where SHA1 expected!!!");
			}
		}
	}
}

WriteIndexPages();

WriteMessage("GetTagsPage()...");
my $tagsPage = GetTagsPage();
PutHtmlFile("html/tags.html", $tagsPage);

WriteMessage("GetEventsPage()...");
my $eventsPage = GetEventsPage();
PutHtmlFile("html/events.html", $eventsPage);

WriteMessage("GetScoreboardPage()...");
my $scoreboardPage = GetScoreboardPage();
PutHtmlFile('html/authors.html', $scoreboardPage);
PutHtmlFile('html/author/index.html', $scoreboardPage);

WriteMessage("DBGetVoteCounts()...");

my $voteCounts = DBGetVoteCounts();
my @voteCountsArray = @{$voteCounts};

my @allTagsList;

while (@voteCountsArray) {
	my $tag = pop @voteCountsArray;

	my $tagName = @{$tag}[0];
	#my $tagCount = @{$tag}[1];

	WriteMessage("GetReadPage('tag', '$tagName')");

	my $indexPage = GetReadPage('tag', $tagName);

	unshift @allTagsList, $tagName;

	PutHtmlFile('html/top/' . $tagName . '.html', $indexPage);
}

WriteMessage("DBGetAllAppliedTags()...");

my @tagsList = DBGetAllAppliedTags();

WriteLog("DBGetAllAppliedTags returned " . scalar(@tagsList) . " items");

if (GetConfig('tag_cloud_page')) {
	foreach my $tag1 (@tagsList) {
		WriteLog("DBGetAllAppliedTags $tag1...");
		foreach my $tag2 (@tagsList) {
			WriteLog("DBGetAllAppliedTags $tag1 $tag2");
			my @items = DBGetItemListByTagList($tag1, $tag2);
	
			if (scalar(@items) >= 5) {
				WriteLog("Returned: ". scalar(@items));
	
				WriteMessage("Writing tags page for $tag1 together with $tag2");
	
				my $testPage;
				$testPage = GetIndexPage(\@items);
	
				WriteLog("html/top/$tag1\_$tag2.html");
	
				PutHtmlFile("html/top/$tag1\_$tag2.html", $testPage);
	
				unshift @allTagsList, "$tag1\_$tag2";
			} else {
				WriteLog("Returned: ". scalar(@items));
			}
		}
	}
}

WriteMessage("GetTopItemsPage()");

#my $topItemsPage = GetTopItemsPage();
my $topItemsPage = GetTopItemsPage();
PutHtmlFile('html/top.html', $topItemsPage);

@allTagsList = sort @allTagsList;

if (GetConfig('tag_cloud_page')) {
	my $tagCloudPage = '';
	foreach my $tag (@allTagsList) {
		my $linkTitle = $tag;
		$linkTitle =~ s/_/+/;
	#	$linkTitle =~ s/\_/+/;
		$tagCloudPage .= '<a href="top/' . $tag . '.html">' . $linkTitle . '</a><br>';
	}
	PutHtmlFile('html/tagcloud.html', $tagCloudPage);
}
#
#sub MakePage {
#	if (!$force) {
#		if ($myCounter < $myCounterMax) {
#			return;
#		}
#	}
#
#	my $page = shift;
#
#
#
#	my $currentPageContent = GetCache("page/$page");
#
#	if ($newPageContent == $currentPageContent) {
#		#PutHtmlFile('html/' . $page, $pageContent);
#
#}
#

# This is a special call which gathers up last run's written html files
# that were not updated on this run and removes them
#PutHtmlFile("removePreviousFiles", "1");

#my $votesInDatabase = DBGetVotesTable();
#if ($votesInDatabase) {
#	PutFile('html/votes.txt', DBGetVotesTable());
#}
#
#my $arg1 = shift;
#if ($arg1) {
#	if (-e $arg1) {
#		if ($arg1 == 'summary') {
#			WriteMessage('MakeSummaryPages');
#			
#			MakeSummaryPages();
#		}
#	}
#} else {

MakeDataPage();

my $homePageHasBeenWritten = PutHtmlFile('check_homepage'); # this is not a mistake, but a special command in PutHtmlFile()
# returns true if index.html has been written, false if not

if ($homePageHasBeenWritten) {
	WriteLog("Home Page has been written! Yay!");
} else {
	WriteLog("Warning! Home Page has not been written! Fixing that");
	
	if (-e 'html/write.html') {
		WriteLog('-e html/write.html');
		PutHtmlFile('html/index.html', GetFile('html/write.html'));
	} elsif (-e 'html/top.html') {
		WriteLog('-e html/top.html');
		PutHtmlFile('html/index.html', GetFile('html/top.html'));
	} else {
		WriteLog('fallback for html/index.html');
		my $fallbackHomepage =
'<html><body><h1>Placeholder</h1>
<p>There was a problem writing homepage. Please contact your administrator for resolution.</p>
<p>Try one of these links in the mean time:</p>
<p><a href="/top.html">Top Posts</a></p>
<p><a href="/write.html">Writing Something</a></p>
<p><a href="/stats.html">Check the Server Status</a></p>';

		PutHtmlFile('html/index.html', $fallbackHomepage);
	} 	
	
	$homePageHasBeenWritten = PutHtmlFile('check_homepage');
	if ($homePageHasBeenWritten) {
		
	}
}

#}

1;
