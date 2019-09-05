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

#
# sub GetPageParams {
# 	# Used for getting the title and query for a page given its type and parameters
# 	my $pageType = shift;
#
# 	my %pageParams;
# 	my %queryParams;
#
# 	if (defined($pageType)) {
# 		# If there is a page type specified
# 		if ($pageType eq 'author') {
# 			# Author, get the author key
# 			my $authorKey = shift;
# 			chomp($authorKey);
#
# 			# Get the pretty versions of the alias and the avatar
# 			# for the title
# 			my $authorAliasHtml = GetAlias($authorKey);
# 			my $authorAvatarHtml = GetAvatar($authorKey);
#
# 			# Set title params
# 			$pageParams{'title'} = "Posts by (or for) $authorAliasHtml";
# 			$pageParams{'title_html'} = "$authorAvatarHtml";
#
# 			# Set the WHERE clause for the query
# 			my $whereClause = "author_key='$authorKey'";
# 			$queryParams{'where_clause'} = $whereClause;
# 		}
# 		if ($pageType eq 'tag') {
# 			my $tagKey = shift;
# 			chomp($tagKey);
#
# 			$pageParams{'title'} = $tagKey;
# 			$pageParams{'title_html'} = $tagKey;
#
# 			my @items = DBGetItemsForTag($tagKey);
# 			my $itemsList = "'" . join ("','", @items) . "'";
# 			#todo do this right
# 			#fixme
#
# 			$queryParams{'where_clause'} = "WHERE file_hash IN (" . $itemsList . ")";
# 			$queryParams{'limit_clause'} = "LIMIT 1024";
# 		}
# 	} else {
# 		# Default = main home page title
# 		$pageParams{'title'} = GetConfig('home_title') . GetConfig('logo_text');
# 		$pageParams{'title_html'} = GetConfig('home_title');
# 		#$queryParams{'where_clause'} = "item_type = 'text' AND IFNULL(parent_count, 0) = 0";
# 	}
#
# 	# Add the query parameters to the page parameters
# 	$pageParams{'query_params'} = %queryParams;
#
# 	# Return the page parameters
# 	return %pageParams;
# }

MakeSummaryPages();

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Author pages...");

my @authors = DBGetAuthorList();

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

{
	my $authorsListPage = GetPageHeader('Authors', 'Authors', 'authors');

	$authorsListPage .= GetPageFooter();

	#PutFile('html/author/index.html', $authorsListPage);

#	foreach my $key (@authors) {
#
#	}
}

#
# sub MakeRssFile {
# 	my %queryParams;
# 	my @files = DBGetItemList(\%queryParams);
#
# 	my $fileList = "";
#
# 	foreach my $file(@files) {
# 		my $fileHash = $file->{'file_hash'};
#
# 		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
# 			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");
#
# 			return;
# 		}
#
# 		my $fileName = $file->{'file_path'};
#
# 		$fileList .= $fileName . "|" . $fileHash . "\n";
# 	}
#
# 	PutFile("$HTMLDIR/rss.txt", $fileList);
# }


PutFile("$HTMLDIR/rss.xml", GetRssFile());


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

WriteMessage("GetVotesPage()...");
my $votesPage = GetVotesPage();
PutHtmlFile("html/tags.html", $votesPage); #todo are they tags or votes?

WriteMessage("GetEventsPage()...");
my $eventsPage = GetEventsPage();
PutHtmlFile("html/events.html", $eventsPage);

WriteMessage("GetTagsPage()....");
my $tagsAlphaPage = GetTagsPage();
PutHtmlFile("html/tags_alpha.html", $tagsAlphaPage);

WriteMessage("GetScoreboardPage()...");
my $scoreboardPage = GetScoreboardPage();
PutHtmlFile('html/scores.html', $scoreboardPage);
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

WriteMessage("GetTopItemsPage()");

#my $topItemsPage = GetTopItemsPage();
my $topItemsPage = GetTopItemsPage();
PutHtmlFile('html/top.html', $topItemsPage);

@allTagsList = sort @allTagsList;
my $tagCloudPage = '';
foreach my $tag (@allTagsList) {
	$tagCloudPage .= '<a href="top/' . $tag . '.html">' . $tag . '</a><br>';
}
PutHtmlFile('html/tagcloud.html', $tagCloudPage);
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

	my $homePageHasBeenWritten = PutHtmlFile('check_homepage');
	if ($homePageHasBeenWritten) {
		WriteLog("Home Page has been written! Yay!");
	} else {
		WriteLog("Warning! Home Page has not been written! Fixing that");
		PutHtmlFile('html/index.html', GetFile('html/write.html'));
	}

#}

1;
