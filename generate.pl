#!/usr/bin/perl


#todo add "account" and "sign up" and "register" links

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

#This has been commented out because it interferes with symlinked html dir
#my $HTMLDIR = "html.tmp";
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

sub GetVersionPage {
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

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	my $freshjs = GetTemplate('js/fresh.js.template');
	my $injectJs = $avatarjs . "\n\n" . $freshjs;
	$scriptInject =~ s/\$javascript/$injectJs/g;

	$txtPageHtml =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtPageHtml;
}

#sub InjectJs {
#	my $scriptName = shift;
#	chomp($scriptName);
#
#	if (!$scriptName) {
#		WriteLog('WARNING! InjectJs() called with missing $scriptName. Returning empty string');
#		return '';
#	}
#
#	WriteLog("InjectJs($scriptName)");
#
#	my $scriptInject = GetTemplate('scriptinject.template');
#
#	WriteLog($scriptInject);
#	my $javascript = GetTemplate($scriptName);
#
#	WriteLog($
#
#	$scriptInject =~ s/\$javascript/$javascript/g;
#
#	return $scriptInject;
#}

#sub GetTopPage {
#	my $tag = shift;
#	chomp($tag);
#
#	my $txtIndex = '';
#
#	my $items = GetTopItemsForTag('interesting');
#
#	return $items;
#
#
#}

MakeStaticPages();

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

sub MakeClonePage {
	WriteLog('MakeClonePage() called');

	#This makes the zip file as well as the clone.html page that lists its size

	my $zipInterval = 3600;
	my $lastZip = GetCache('last_zip');

	if (!$lastZip || (GetTime() - $lastZip) > $zipInterval) {
		WriteLog("Making zip file...");

		system("git archive --format zip --output html/hike.tmp.zip master");
		#system("git archive -v --format zip --output html/hike.tmp.zip master");

		system("zip -qr $HTMLDIR/hike.tmp.zip html/txt/ log/votes.log .git/");
		#system("zip -qrv $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");

		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");

		PutCache('last_zip', GetTime());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}


	my $clonePage = GetPageHeader("Clone This Site", "Clone This Site", 'clone');

	$clonePage .= GetTemplate('maincontent.template');

	my $clonePageTemplate = GetTemplate('clone.template');

	my $sizeHikeZip = -s "$HTMLDIR/hike.zip";

	$sizeHikeZip = GetFileSizeHtml($sizeHikeZip);
	if (!$sizeHikeZip) {
		$sizeHikeZip = 0;
	}

	$clonePageTemplate =~ s/\$sizeHikeZip/$sizeHikeZip/g;

	$clonePage .= $clonePageTemplate;

	$clonePage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$clonePage =~ s/<\/body>/$scriptInject<\/body>/;


	PutHtmlFile("$HTMLDIR/clone.html", $clonePage);
}

# generate commits page
{
	#todo only do this for versions mentioned in changelogs
	my $commits = `git log -n 250 | grep ^commit`;

	WriteLog('$commits = git log -n 250 | grep ^commit');

	if ($commits) {
		foreach(split("\n", $commits)) {
			my $commit = $_;
			$commit =~ s/^commit //;
			chomp($commit);
			if (IsSha1($commit)) {
				my $htmlSubDir = 'html/' . substr($commit, 0, 2) . '/' . substr($commit, 2, 2);
				my $htmlFilename = $commit;
				if (!-e $htmlSubDir) {
					mkdir($htmlSubDir);
				}
				WriteLog("html/$commit.html");
				PutHtmlFile("$htmlSubDir/$htmlFilename.html", GetVersionPage($commit));
			}
		}
	}
}

WriteIndexPages();

my $votesPage = GetVotesPage();
PutHtmlFile("html/tags.html", $votesPage); #todo are they tags or votes?

my $scoreboardPage = GetScoreboardPage();
PutHtmlFile('html/scores.html', $scoreboardPage);
PutHtmlFile('html/author/index.html', $scoreboardPage);

my $topItemsPage = GetTopItemsPage();
PutHtmlFile('html/top.html', $topItemsPage);

my $voteCounts = DBGetVoteCounts();
my @voteCountsArray = @{$voteCounts};

while (@voteCountsArray) {
	my $tag = pop @voteCountsArray;

	my $tagName = @{$tag}[0];
	#my $tagCount = @{$tag}[1];

	my $indexPage = GetReadPage('tag', $tagName);

	PutHtmlFile('html/top/' . $tagName . '.html', $indexPage);
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

MakeClonePage();

my $homePageHasBeenWritten = PutHtmlFile('check_homepage');
if ($homePageHasBeenWritten) {
	WriteLog("Home Page has been written! Yay!");
} else {
	WriteLog("Warning! Home Page has not been written! Fixing that");
	PutHtmlFile('html/index.html', GetFile('html/write.html'));
}

1;
