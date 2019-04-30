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

sub GetAuthorHeader {
	return "HI";
}
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

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);

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
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtPageHtml =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtPageHtml;
}

sub GetIdentityPage {
	my $txtIndex = "";

	my $title = "Profile";
	my $titleHtml = "Profile";

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('form/identity.template');

	my $idCreateForm = GetTemplate('form/id_create.template');
	my $prefillUsername = GetConfig('prefill_username');
	$idCreateForm =~ s/\$prefillUsername/$prefillUsername/g;
	$idPage =~ s/\$formIdCreate/$idCreateForm/g;

	my $idCurrentForm = GetTemplate('form/id_current.template');
	$idPage =~ s/\$formIdCurrent/$idCurrentForm/g;

	my $idAdminForm = GetTemplate('form/id_admin.template');
	$idPage =~ s/\$formIdAdmin/$idAdminForm/g;

	if (GetConfig('use_gpg2')) {
		my $gpg2Choices = GetTemplate('gpg2.choices.template');
		$idPage =~ s/\$gpg2Algochoices/$gpg2Choices/;
	} else {
		$idPage =~ s/\$gpg2Algochoices//;
	}

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	my $scriptsInclude = '<script src="/zalgo.js"></script><script src="/openpgp.js"></script><script src="/crypto.js"></script>';
	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	$txtIndex =~ s/<body /<body onload="identityOnload();" /;

	return $txtIndex;
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

sub GetSubmitPage {
	my $txtIndex = "";

	my $title = "Write";
	my $titleHtml = "Write";

	my $itemCount = DBGetItemCount();
	my $itemLimit = 9000;

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	if (defined($itemCount) && defined($itemLimit) && $itemCount) {
		if ($itemCount < $itemLimit) {
			#my $submitForm = GetTemplate('form/write2.template');
			my $submitForm = GetTemplate('form/write.template');

			if (GetConfig('enable_php_support')) {
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

		my $scriptInject = GetTemplate('scriptinject.template');
		my $avatarjs = GetTemplate('js/avatar.js.template');
		my $writeOnLoad = GetTemplate('js/writeonload.js.template');
		$scriptInject =~ s/\$javascript/$avatarjs$writeOnLoad/g;

		$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

		my $scriptsInclude = '<script type="text/javascript" src="/zalgo.js"></script><script type="text/javascript" src="/openpgp.js"></script><script type="text/javascript" src="/crypto.js"></script>';
		$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

		$txtIndex =~ s/<body /<body onload="writeOnload();" /;
	} else {
		#my $submitForm = GetTemplate('form/write2.template');
		my $submitForm = GetTemplate('form/write.template');
		my $prefillText = "";

		$submitForm =~ s/\$extraFields//g;
		$submitForm =~ s/\$prefillText/$prefillText/g;

		$txtIndex .= $submitForm;
		$txtIndex .= "Something went wrong. Could not get item count.";
	}

	return $txtIndex;
}

sub GetHomePage {
	my $homePage;

	#my $homePage = GetTemplate('page/home.template');
}

sub GetStatsPage {
	my $statsPage;

	$statsPage = GetPageHeader('Stats', 'Stats');

	my $statsTable = GetTemplate('stats.template');

	my $itemCount = DBGetItemCount();
	my $adminId = GetAdminKey();
	if ($adminId) {
		$statsTable =~ s/\$admin/GetAuthorLink($adminId)/e;
	} else {
		$statsTable =~ s/\$admin/(None)/;
	}


	my $currUpdateTime = time();
	my $prevUpdateTime = GetConfig('last_update_time');
	if (!defined($prevUpdateTime) || !$prevUpdateTime) {
		$prevUpdateTime = time();
	}

	my $updateInterval = $currUpdateTime - $prevUpdateTime;

	PutConfig("last_update_time", $currUpdateTime);

	my $nextUpdateTime = ($currUpdateTime + $updateInterval) . ' (' . EpochToHuman($currUpdateTime + $updateInterval) . ')';
	$prevUpdateTime = $prevUpdateTime . ' (' . EpochToHuman($prevUpdateTime) . ')';
	$currUpdateTime = $currUpdateTime . ' (' . EpochToHuman($currUpdateTime) . ')';

	$statsTable =~ s/\$prevUpdateTime/$prevUpdateTime/;
	$statsTable =~ s/\$currUpdateTime/$currUpdateTime/;
	$statsTable =~ s/\$updateInterval/$updateInterval/;
	$statsTable =~ s/\$nextUpdateTime/$nextUpdateTime/;

	$statsTable =~ s/\$version/GetMyVersion()/e;
	$statsTable =~ s/\$itemCount/$itemCount/e;

	$statsPage .= $statsTable;

	$statsPage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$statsPage =~ s/<\/body>/$scriptInject<\/body>/;

	return $statsPage;
}

sub MakeStaticPages {
	WriteLog('MakeStaticPages() BEGIN');

	# Submit page
	my $submitPage = GetSubmitPage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);


	# Stats page
	my $statsPage = GetStatsPage();
	PutHtmlFile("$HTMLDIR/stats.html", $statsPage);


	# Profile Management page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/profile.html", $identityPage);


	# Target page for the submit page
	my $graciasPage = GetPageHeader("Thank You", "Thank You");
	$graciasPage =~ s/<\/head>/<meta http-equiv="refresh" content="2; url=\/"><\/head>/;

	$graciasPage .= GetTemplate('maincontent.template');

	my $graciasTemplate = GetTemplate('page/gracias.template');

	$graciasPage .= $graciasTemplate;

	$graciasPage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('js/avatar.js.template');
	my $graciasjs = GetTemplate('js/gracias.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs$graciasjs/g;

	$graciasPage =~ s/<\/body>/$scriptInject<\/body>/;

	$graciasPage =~ s/<body /<body onload="makeRefLink();" /;

	PutHtmlFile("$HTMLDIR/gracias.html", $graciasPage);

	# Ok page
	my $okPage = GetTemplate('actionvote.template');

	$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	#$okPage =~ s/<\/head>/<meta http-equiv="refresh" content="5; url=\/blank.html"><\/head>/;

	#PutHtmlFile("$HTMLDIR/ok.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote.html", $okPage);
	PutHtmlFile("$HTMLDIR/action/vote2.html", $okPage);

	# Manual page
	my $tfmPage = GetPageHeader("Manual", "Manual");

	$tfmPage .= GetTemplate('maincontent.template');

	my $tfmPageTemplate = GetTemplate('page/manual.template');

	$tfmPage .= $tfmPageTemplate;

	$tfmPage .= GetTemplate('netnow3.template');

	$tfmPage .= GetPageFooter();

	$scriptInject = GetTemplate('scriptinject.template');
	$avatarjs = GetTemplate('js/avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$tfmPage =~ s/<\/body>/$scriptInject<\/body>/;

	PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('js/zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('js/openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('js/openpgp.worker.js.template'));

	# Write form javasript
	my $cryptoJsTemplate = GetTemplate('js/crypto.js.template');
	my $prefillUsername = GetConfig('prefill_username') || '';
	$cryptoJsTemplate =~ s/\$prefillUsername/$prefillUsername/g;

	PutHtmlFile("$HTMLDIR/crypto.js", $cryptoJsTemplate);

	# Write form javasript
	PutHtmlFile("$HTMLDIR/avatar.js", GetTemplate('js/avatar.js.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');
	if (GetConfig('enable_php_support')) {
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

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Author pages...");

my @authors = DBGetAuthorList();

WriteLog('@authors: ' . scalar(@authors));

my $authorInterval = 3600;

foreach my $hashRef (@authors) {
	my $key = $hashRef->{'key'};

	my $lastTouch = GetCache("key/$key");
	if ($lastTouch && $lastTouch + $authorInterval > time()) {
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

	my $authorIndex = GetReadPage('author', $key);

	PutHtmlFile("$HTMLDIR/author/$key/index.html", $authorIndex);

	PutCache("key/$key", time());
}

{
	my $authorsListPage = GetPageHeader('Authors', 'Authors');

	$authorsListPage .= GetPageFooter();

	PutFile('html/author/index.html', $authorsListPage);

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

		my $fileIndex = GetItemPage($file);

		#my $targetPath = $HTMLDIR . '/' . substr($fileHash, 0, 2) . '/' . substr($fileHash, 2) . '.html';
		my $targetPath = 'html/' . GetHtmlFilename($fileHash);

		WriteLog("Writing HTML file for item");
		WriteLog("\$targetPath = $targetPath");

		if (!-e 'html/' . substr($fileHash, 0, 2)) {
			mkdir('html/' . substr($fileHash, 0, 2));
		}

		PutHtmlFile($targetPath, $fileIndex);

		PutCache("file/$fileHash", time());
	}

	PutFile("$HTMLDIR/rss.txt", $fileList);
}

MakeStaticPages();

sub MakeClonePage {
	WriteLog('MakeClonePage() called');

	#This makes the zip file as well as the clone.html page that lists its size

	my $zipInterval = 3600;
	my $lastZip = GetCache('last_zip');

	if (!$lastZip || (time() - $lastZip) > $zipInterval) {
		WriteLog("Making zip file...");

		system("git archive --format zip --output html/hike.tmp.zip master");
		#system("git archive -v --format zip --output html/hike.tmp.zip master");

		system("zip -qr $HTMLDIR/hike.tmp.zip html/txt/ log/votes.log .git/");
		#system("zip -qrv $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");

		rename("$HTMLDIR/hike.tmp.zip", "$HTMLDIR/hike.zip");

		PutCache('last_zip', time());
	} else {
		WriteLog("Zip file was made less than $zipInterval ago, too lazy to do it again");
	}


	my $clonePage = GetPageHeader("Clone This Site", "Clone This Site");

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
	my $commits = `git log -n 25 | grep ^commit`;

	WriteLog('$commits = git log -n 25 | grep ^commit');

	if ($commits) {
		foreach(split("\n", $commits)) {
			my $commit = $_;
			$commit =~ s/^commit //;
			chomp($commit);
			if (IsSha1($commit)) {
				my $htmlSubDir = 'html/' . substr($commit, 0, 2);
				my $htmlFilename = substr($commit, 2);
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
	WriteLog("Home Page has bee written! Yay!");
} else {
	WriteLog("Warning! Home Page has bee written! Fixing that");
	PutHtmlFile('html/write.html', GetHomePage());
}

1;
