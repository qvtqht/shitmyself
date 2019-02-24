#!/usr/bin/perl


#todo add "account" and "sign up" and "register" links

use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

use lib qw(lib);
use HTML::Entities qw(encode_entities);
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

my $PAGE_LIMIT = GetConfig('page_limit');
#my $PAGE_THRESHOLD = 5;


sub GetAuthorHeader {
	return "HI";
}

sub GetPageParams {
	# Used for getting the title and query for a page given its type and parameters
	my $pageType = shift;

	my %pageParams;
	my %queryParams;

	if (defined($pageType)) {
		# If there is a page type specified
		if ($pageType eq 'author') {
			# Author, get the author key
			my $authorKey = shift;
			chomp($authorKey);

			# Get the pretty versions of the alias and the avatar
			# for the title
			my $authorAliasHtml = GetAlias($authorKey);
			my $authorAvatarHtml = GetAvatar($authorKey);

			# Set title params
			$pageParams{'title'} = "Posts by (or for) $authorAliasHtml";
			$pageParams{'title_html'} = "$authorAvatarHtml";

			# Set the WHERE clause for the query
			my $whereClause = "author_key='$authorKey'";
			$queryParams{'where_clause'} = $whereClause;
		}
		if ($pageType eq 'tag') {
			my $tagKey = shift;
			chomp($tagKey);

			$pageParams{'title'} = $tagKey;
			$pageParams{'title_html'} = $tagKey;

			my @items = DBGetItemsForTag($tagKey);
			my $itemsList = "'" . join ("','", @items) . "'";

			$queryParams{'where_clause'} = "WHERE file_hash IN (" . $itemsList . ")";
			$queryParams{'limit_clause'} = "LIMIT 1024";
		}
	} else {
		# Default = main home page title
		$pageParams{'title'} = GetConfig('home_title') . GetConfig('logo_text');
		$pageParams{'title_html'} = GetConfig('home_title');
		#$queryParams{'where_clause'} = "item_type = 'text' AND IFNULL(parent_count, 0) = 0";
	}

	# Add the query parameters to the page parameters
	$pageParams{'query_params'} = %queryParams;

	# Return the page parameters
	return %pageParams;
}

sub GetVersionPage {
	my $version = shift;

	if (!IsSha1($version)) {
		return;
	}

	my $txtPageHtml = '';

	my $pageTitle = "Information page for version $version";

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);
#
#	my $writeSmall = GetTemplate("write-small.template");
#
#	$htmlStart .= $writeSmall;

	$txtPageHtml .= $htmlStart;

	$txtPageHtml .= GetTemplate('maincontent.template');

	my $versionInfo = GetTemplate('versioninfo.template');
	my $shortVersion = substr($version, 0, 8);

	$versionInfo =~ s/\$version/$version/g;
	$versionInfo =~ s/\$shortVersion/$shortVersion/g;

	$txtPageHtml .= $versionInfo;

	$txtPageHtml .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtPageHtml =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtPageHtml;
}

sub GetIndexPage {
	# Returns index#.html files given an array of files
	# Called by a loop in generate.pl
	# Should probably be replaced with GetReadPage()

	my $filesArrayReference = shift;
	my @files = @$filesArrayReference;
	my $currentPageNumber = shift;

	my $txtIndex = "";

	my $pageTitle = GetConfig('home_title');

	my $htmlStart = GetPageHeader($pageTitle, $pageTitle);

	my $writeSmall = GetTemplate("write-small.template");

	#my $writeShortMessage = GetString('write_short_message');
	#$writeSmall =~ s/\$writeShortMessage/$writeShortMessage/g;

	$htmlStart .= $writeSmall;

	$txtIndex .= $htmlStart;

	$txtIndex .= "<a name=toppage></a>"; #todo template this!

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	$txtIndex .= GetTemplate('maincontent.template');

	my $itemList = '';

	foreach my $row (@files) {
		my $file = $row->{'file_path'};

		if (-e $file) {
			my $gitHash = $row->{'file_hash'};

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

			$message = FormatForWeb($message);

			$message =~ s/([a-f0-9]{8})([a-f0-9]{32})/<a href="\/$1$2.html">$1..<\/a>/g;
			#todo verify that the items exist before turning them into links,
			# so that we don't end up with broken links

			if ($isSigned && $gpgKey eq GetAdminKey()) {
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

			WriteLog('GetTemplate("item.template") 1');

			my $itemTemplate = '';
			if (length($message) > GetConfig('item_long_threshold')) {
				$itemTemplate = GetTemplate("itemlong.template");
			} else {
				$itemTemplate = GetTemplate("item.template");
			}
			#$itemTemplate = s/\$primaryColor/$primaryColor/g;

			my $itemClass = "txt $signedCss";

			my $authorUrl;
			my $authorAvatar;
			my $authorLink;
			my $byString = GetString('by');

			if ($gpgKey) {
				$authorUrl = "/author/$gpgKey/";
				$authorAvatar = GetAvatar($gpgKey);

				$authorLink = GetTemplate('authorlink.template');

				$authorLink =~ s/\$authorUrl/$authorUrl/g;
				$authorLink =~ s/\$authorAvatar/$authorAvatar/g;
			} else {
				$authorLink = "";
			}
			my $permalinkTxt = $file;
			my $permalinkHtml = "/" . $gitHash . ".html";

			$permalinkTxt =~ s/^\.//;
			$permalinkTxt =~ s/html\///;

			my $itemText = $message;
			my $fileHash = GetFileHash($file);
			my $itemName = substr($gitHash, 0, 8) . "..";

			#			my $ballotTime = time();

			my $replyCount = $row->{'child_count'};

			my $borderColor = '#' . substr($fileHash, 0, 6);

			$itemTemplate =~ s/\$borderColor/$borderColor/g;
			$itemTemplate =~ s/\$itemClass/$itemClass/g;
			$itemTemplate =~ s/\$authorLink/$authorLink/g;
			$itemTemplate =~ s/\$itemName/$itemName/g;
			$itemTemplate =~ s/\$permalinkTxt/$permalinkTxt/g;
			$itemTemplate =~ s/\$permalinkHtml/$permalinkHtml/g;
			$itemTemplate =~ s/\$itemText/$itemText/g;
			$itemTemplate =~ s/\$fileHash/$fileHash/g;
			$itemTemplate =~ s/\$by/$byString/g;

#			if ($replyCount) {
#				$itemTemplate =~ s/\$replyCount/$replyCount replies/g;
#			} else {
#				$itemTemplate =~ s/\$replyCount//g;
#			}
			if ($replyCount) {
				$itemTemplate =~ s/\$replyCount/\($replyCount\)/g;
			} else {
				$itemTemplate =~ s/\$replyCount//g;
			}


			#todo templatize this
			#this displays the vote summary (tags applied and counts)
			my $votesSummary = '';
			my %voteTotals = DBGetItemVoteTotals($fileHash);

			foreach my $voteTag (keys %voteTotals) {
				$votesSummary .= "$voteTag (" . $voteTotals{$voteTag} . ")\n";
			}
			if ($votesSummary) {
				$votesSummary = '<p>' . $votesSummary . '</p>';
			}
			$itemTemplate =~ s/\$votesSummary/$votesSummary/g;
			#
			#end of tag summary display


			#my $voterButtons = GetVoterTemplate($fileHash, $ballotTime);
			#$itemTemplate =~ s/\$voterButtons/$voterButtons/g;

			#$txtIndex .= $itemTemplate;
			$itemList = $itemTemplate . $itemList;
		}
	}

	$txtIndex .= $itemList;

#	$txtIndex .= GetTemplate('voteframe.template');

	if (defined($currentPageNumber)) {
		$txtIndex .= GetPageLinks($currentPageNumber);
	}

	# Add javascript warning to the bottom of the page
	#$txtIndex .= GetTemplate("jswarning.template");

	# Close html
	$txtIndex .= GetPageFooter();

	#$txtIndex =~ s/<\/body>/\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
}

sub GetIdentityPage {
	my $txtIndex = "";

	my $title = "Identity Management";
	my $titleHtml = "Identity Management";

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $idPage = GetTemplate('identity.template');

	$txtIndex .= $idPage;

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	$txtIndex =~ s/<\/body>/<script src="zalgo.js"><\/script>\<script src="openpgp.js">\<\/script>\<script src="crypto.js"><\/script><\/body>/;

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

sub GetVotesPage {
	#todo rewrite this more pretty
	my $txtIndex = "";

	my $title = 'Tags';
	my $titleHtml = 'Tags';

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	my $voteCounts = DBGetVoteCounts();

	my @voteCountsArray = split("\n", $voteCounts);

	foreach my $row (@voteCountsArray) {
		my @rowSplit = split(/\|/, $row);

		my $voteItemTemplate = GetTemplate('vote_page_link.template');

		my $tagName = $rowSplit[0];
		my $tagCount = $rowSplit[1];
		my $voteItemLink = "/top/" . $tagName . ".html";

		$voteItemTemplate =~ s/\$link/$voteItemLink/g;
		$voteItemTemplate =~ s/\$tagName/$tagName ($tagCount)/g;

		$txtIndex .= $voteItemTemplate;
	}

	$txtIndex .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

	return $txtIndex;
}

sub GetTopPage {
	my $tag = shift;
	chomp($tag);

	my $txtIndex = '';

	my $items = GetTopItemsForTag('interesting');

	return $items;


}

sub GetSubmitPage {
	my $txtIndex = "";

	my $title = "Write";
	my $titleHtml = "Write";

	my $itemCount = DBGetItemCount();
	my $itemLimit = 9000;

	$txtIndex = GetPageHeader($title, $titleHtml);

	$txtIndex .= GetTemplate('maincontent.template');

	if (defined($itemCount) && defined($itemLimit)) {
		if ($itemCount < $itemLimit) {
			my $submitForm = GetTemplate('write.template');
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
		my $avatarjs = GetTemplate('avatar.js.template');
		$scriptInject =~ s/\$javascript/$avatarjs/g;

		$txtIndex =~ s/<\/body>/$scriptInject<\/body>/;

		$txtIndex =~ s/<\/body>/<script src="zalgo.js"><\/script>\<script src="openpgp.js"><\/script>\<script src="crypto.js"><\/script><\/body>/;

		$txtIndex =~ s/<body /<body onload="writeOnload();" /;
	} else {
		my $submitForm = GetTemplate('write.template');
		my $prefillText = "";

		$submitForm =~ s/\$extraFields//g;
		$submitForm =~ s/\$prefillText/$prefillText/g;

		$txtIndex .= $submitForm;
		$txtIndex = "Something went wrong. Could not get item count.";
	}

	return $txtIndex;
}

sub GetPageLink {
	my $pageNumber = shift;

	state $pageLinkTemplate;
	if (!defined($pageLinkTemplate)) {
		$pageLinkTemplate = GetTemplate('pagelink.template');
	}

	my $pageLink = $pageLinkTemplate;
	$pageLink =~ s/\$pageName/$pageNumber/;

	$pageLink =~ s/\$pageNumber/$pageNumber/;

	return $pageLink;
}

sub GetPageLinks {
	state $pageLinks;

	my $currentPageNumber = shift;

	if (defined($pageLinks)) {
		my $currentPageTemplate = GetPageLink($currentPageNumber);

		my $pageLinksFinal = $pageLinks;
		$pageLinksFinal =~ s/$currentPageTemplate/<b>$currentPageNumber<\/b> /g;

		return $pageLinksFinal;
	}

	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	$pageLinks = "";

	my $lastPageNum = ceil($itemCount / $PAGE_LIMIT);

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

	if ($itemCount > $PAGE_LIMIT) {
		for (my $i = $lastPageNum - 1; $i >= 0; $i--) {
#		for (my $i = 0; $i < $lastPageNum; $i++) {
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

	return GetPageLinks($currentPageNumber);
}

sub MakeStaticPages {

	# Submit page
	my $submitPage = GetSubmitPage();
	PutHtmlFile("$HTMLDIR/write.html", $submitPage);


	# Identity page
	my $identityPage = GetIdentityPage();
	PutHtmlFile("$HTMLDIR/identity.html", $identityPage);


	# Target page for the submit page
	my $graciasPage = GetPageHeader("Thank You", "Thank You");
	$graciasPage =~ s/<\/head>/<meta http-equiv="refresh" content="10; url=\/"><\/head>/;

	$graciasPage .= GetTemplate('maincontent.template');

	my $graciasTemplate = GetTemplate('gracias.template');

	my $currUpdateTime = time();
	my $prevUpdateTime = GetConfig('last_update_time');
	if (!defined($prevUpdateTime) || !$prevUpdateTime) {
		$prevUpdateTime = time();
	}

	my $updateInterval = $currUpdateTime - $prevUpdateTime;

	PutConfig("last_update_time", $currUpdateTime);

	my $nextUpdateTime = EpochToHuman($currUpdateTime + $updateInterval);

	$prevUpdateTime = EpochToHuman($prevUpdateTime);
	$currUpdateTime = EpochToHuman($currUpdateTime);

	$graciasTemplate =~ s/\$prevUpdateTime/$prevUpdateTime/;
	$graciasTemplate =~ s/\$currUpdateTime/$currUpdateTime/;
	$graciasTemplate =~ s/\$updateInterval/$updateInterval/;
	$graciasTemplate =~ s/\$nextUpdateTime/$nextUpdateTime/;

	$graciasPage .= $graciasTemplate;

	$graciasPage .= GetPageFooter();

	my $scriptInject = GetTemplate('scriptinject.template');
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$graciasPage =~ s/<\/body>/$scriptInject<\/body>/;


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

	my $tfmPageTemplate = GetTemplate('manual.template');

	$tfmPage .= $tfmPageTemplate;

	$tfmPage .= GetTemplate('netnow3.template');

	$tfmPage .= GetPageFooter();

	$scriptInject = GetTemplate('scriptinject.template');
	$avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$tfmPage =~ s/<\/body>/$scriptInject<\/body>/;

	PutHtmlFile("$HTMLDIR/manual.html", $tfmPage);


	# Blank page
	PutHtmlFile("$HTMLDIR/blank.html", "");


	# Zalgo javascript
	PutHtmlFile("$HTMLDIR/zalgo.js", GetTemplate('zalgo.js.template'));


	# OpenPGP javascript
	PutHtmlFile("$HTMLDIR/openpgp.js", GetTemplate('openpgp.js.template'));
	PutHtmlFile("$HTMLDIR/openpgp.worker.js", GetTemplate('openpgp.worker.js.template'));

	# Write form javasript
	my $cryptoJsTemplate = GetTemplate('crypto.js.template');
	my $prefillUsername = GetConfig('prefill_username') || '';
	$cryptoJsTemplate =~ s/\$prefillUsername/$prefillUsername/g;

	PutHtmlFile("$HTMLDIR/crypto.js", $cryptoJsTemplate);

	# Write form javasript
	PutHtmlFile("$HTMLDIR/avatar.js", GetTemplate('avatar.js.template'));


	# .htaccess file for Apache
	my $HtaccessTemplate = GetTemplate('htaccess.template');
	PutHtmlFile("$HTMLDIR/.htaccess", $HtaccessTemplate);

	PutHtmlFile("$HTMLDIR/favicon.ico", '');
}

WriteLog ("GetReadPage()...");

#my $indexText = GetReadPage();

#PutHtmlFile("$HTMLDIR/index.html", $indexText);

WriteLog ("Author pages...");

my @authors = DBGetAuthorList();

WriteLog('@authors: ' . scalar(@authors));

my $authorInterval = 3600;

foreach my $key (@authors) {
	WriteLog ("$key");

	my $lastTouch = GetCache("key/$key");
	if ($lastTouch && $lastTouch + $authorInterval > time()) {
		WriteLog("I already did $key recently, too lazy to do it again");
		next;
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

	PutFile('./html/author/index.html', $authorsListPage);

#	foreach my $key (@authors) {
#
#	}
}

sub MakeRssFile {
	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	my $fileList = "";

	foreach my $file(@files) {
		my $fileHash = $file->{'file_hash'};

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");

			return;
		}

		my $fileName = $file->{'file_path'};

		$fileList .= $fileName . "|" . $fileHash . "\n";
	}

	PutFile("$HTMLDIR/rss.txt", $fileList);
}

{
	my %queryParams;
	my @files = DBGetItemList(\%queryParams);

	WriteLog("DBGetItemList() returned " . scalar(@files) . " items");

	my $fileList = "";

	my $fileInterval = 3600;

	foreach my $file(@files) {
		my $fileHash = $file->{'file_hash'};

		if (-e 'log/deleted.log' && GetFile('log/deleted.log') =~ $fileHash) {
			WriteLog("generate.pl: $fileHash exists in deleted.log, skipping");

			return;
		}

		my $lastTouch = GetCache("file/$fileHash");
		if ($lastTouch && $lastTouch + $fileInterval > time()) {
			WriteLog("I already did $fileHash recently, too lazy to do it again");
			next;
		}

		my $fileName = $file->{'file_hash'};

		$fileName =~ s/^\.//;
		$fileName =~ s/\/html//;

		$fileList .= $fileName . "|" . $fileHash . "\n";

		my $fileIndex = GetItemPage($file);

		my $targetPath = $HTMLDIR . '/' . $fileHash . '.html';

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

		system("zip -qr $HTMLDIR/hike.tmp.zip ./txt/ ./log/votes.log .git/");
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
	my $avatarjs = GetTemplate('avatar.js.template');
	$scriptInject =~ s/\$javascript/$avatarjs/g;

	$clonePage =~ s/<\/body>/$scriptInject<\/body>/;


	PutHtmlFile("$HTMLDIR/clone.html", $clonePage);
}

{
	my $commits = `git log -n 25 | grep ^commit`;

	WriteLog('$commits = git log -n 25 | grep ^commit');

	if ($commits) {
		foreach(split("\n", $commits)) {
			my $commit = $_;
			$commit =~ s/^commit //;
			chomp($commit);
			if (IsSha1($commit)) {
				WriteLog("./html/$commit.html");
				PutHtmlFile("./html/$commit.html", GetVersionPage($commit));
			}
		}
	}
}

{
	#my $itemCount = DBGetItemCount("item_type = 'text'");
	my $itemCount = DBGetItemCount();

	my $overlapPage = GetConfig('overlap_page');
	#in order to keep both the "last" and the "first" page the same length
	#and avoid having mostly-empty pages with only a few items
	#we introduce an overlap on page 5, where some items are displayed
	#twice. this also allows us to only update the first 5 plus all affected
	#when a new item is added, instead of the whole catalog

	if ($itemCount > 0) {
		my $i;

		WriteLog("\$itemCount = $itemCount");

		my $lastPage = ceil($itemCount / $PAGE_LIMIT);

		for ($i = 0; $i < $lastPage; $i++) {
			my %queryParams;
			my $offset = $i * $PAGE_LIMIT;

			#$queryParams{'where_clause'} = "WHERE item_type = 'text' AND IFNULL(parent_count, 0) = 0";

			if ($overlapPage && $lastPage > $overlapPage && $i > $overlapPage) {
				$offset = $offset - ($itemCount % $PAGE_LIMIT);
			}
			$queryParams{'limit_clause'} = "LIMIT $PAGE_LIMIT OFFSET $offset";
			$queryParams{'order_clause'} = 'ORDER BY add_timestamp';

			my @ft = DBGetItemList(\%queryParams);

			my $indexPage;
			if ($lastPage > 1) {
				$indexPage = GetIndexPage(\@ft, $i);
			} else {
				$indexPage = GetIndexPage(\@ft);
			}

			if ($i < $lastPage-1) {
				PutHtmlFile("./html/index$i.html", $indexPage);
			} else {
				PutHtmlFile("./html/index.html", $indexPage);
				PutHtmlFile("./html/index$i.html", $indexPage);
			}
		}
	} else {
		my $indexPage = GetPageHeader(GetConfig('home_title'), GetConfig('home_title'));

		$indexPage .= '<p>It looks like there is nothing to display here. Would you like to write something?</p>';

		$indexPage .= GetPageFooter();

		PutHtmlFile('./html/index.html', $indexPage);
	}
}

my $votesPage = GetVotesPage();
PutHtmlFile("./html/tags.html", $votesPage); #todo are they tags or votes?


my $voteCounts = DBGetVoteCounts();
if ($voteCounts) {
	my @voteCountsArray = split("\n", $voteCounts);

	foreach my $row (@voteCountsArray) {
		WriteLog($row);

		my @rowSplit = split(/\|/, $row);
		my $tagName = $rowSplit[0];

		my $indexPage = GetReadPage('tag', $tagName);

		PutHtmlFile('./html/top/' . $tagName . '.html', $indexPage);
	}

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
#		#PutHtmlFile('./html/' . $page, $pageContent);
#
#}
#

# This is a special call which gathers up last run's written html files
# that were not updated on this run and removes them
#PutHtmlFile("removePreviousFiles", "1");

#my $votesInDatabase = DBGetVotesTable();
#if ($votesInDatabase) {
#	PutFile('./html/votes.txt', DBGetVotesTable());
#}

MakeClonePage();

1;