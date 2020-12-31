#!/usr/bin/perl -T

use strict;
use 5.010;

sub GetHtmlAvatar { # Returns HTML avatar from cache
	state %avatarMemo;

	# returns avatar suitable for comments
	my $key = shift;
	if (!$key) {
		return;
	}

	if (!IsFingerprint($key)) {
		return;
	}

	if ($avatarMemo{$key}) {
		WriteLog("GetHtmlAvatar: found in hash");
		return $avatarMemo{$key};
	}

	my $avatar = GetAvatar($key);
	if ($avatar) {
		if (-e 'html/author/' . $key) {
			my $avatarLink = GetAuthorLink($key);
			$avatarMemo{$key} = $avatar;
			return $avatarLink;
		}
	} else {
		return $key;
		#		return 'unregistered';
	}

	return $key;
	#	return 'unregistered';
}

sub GetHtmlFilename { # get the HTML filename for specified item hash
	# GetItemUrl GetItemHtmlLink { #keywords
	# Returns 'ab/cd/abcdef01234567890[...].html'
	my $hash = shift;

	WriteLog("GetHtmlFilename()");

	if (!defined($hash) || !$hash) {
		if (WriteLog("GetHtmlFilename: warning: called without parameter")) {

			#my $trace = Devel::StackTrace->new;
			#print $trace->as_string; # like carp
		}

		return;
	}

	WriteLog("GetHtmlFilename($hash)");

	if (!IsItem($hash)) {
		WriteLog("GetHtmlFilename: warning: called with parameter that isn't a SHA-1. Returning.");
		WriteLog("$hash");
		#
		# my $trace = Devel::StackTrace->new;
		# print $trace->as_string; # like carp

		return;
	}

	#	my $htmlFilename =
	#		substr($hash, 0, 2) .
	#		'/' .
	#		substr($hash, 2, 8) .
	#		'.html';
	#


	# my $htmlFilename =
	# 	substr($hash, 0, 2) .
	# 	'/' .
	# 	substr($hash, 2, 2) .
	# 	'/' .
	# 	$hash .
	# 	'.html';
	#
	#
	my $htmlFilename =
		substr($hash, 0, 2) .
			'/' .
			substr($hash, 2, 2) .
			'/' .
			substr($hash, 0, 8) .
			'.html';

	return $htmlFilename;
}

sub AddAttributeToTag { # $html, $tag, $attributeName, $attributeValue; adds attr=value to html tag;
	my $html = shift; # chunk of html to work with
	my $tag = shift; # tag we'll be modifying
	my $attributeName = shift; # name of attribute
	my $attributeValue = shift; # value of attribute

	WriteLog("AddAttributeToTag(\$html, $tag, $attributeName, $attributeValue)");
	WriteLog('AddAttributeToTag: $html before: ' . $html);

	my $tagAttribute = '';
	if ($attributeValue =~ m/\w/) {
		# attribute value contains whitespace, must be enclosed in double quotes
		$tagAttribute = $attributeName . '="' . $attributeValue . '"';
	} else {
		$tagAttribute = $attributeName . '=' . $attributeValue . '';
	}

	my $htmlBefore = $html;
	$html = str_ireplace('<' . $tag . ' ', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
	if ($html eq $htmlBefore) {
		$html = str_ireplace('<' . $tag . '', '<' . $tag . ' ' . $tagAttribute . ' ', $html);
	}
	if ($html eq $htmlBefore) {
		$html = str_ireplace('<' . $tag . '>', '<' . $tag . ' ' . $tagAttribute . '>', $html);
	}
	if ($html eq $htmlBefore) {
		WriteLog('AddAttributeToTag: warning: nothing was changed');
	}

	WriteLog('AddAttributeToTag: $html after: ' . $html);

	return $html;
} # AddAttributeToTag()

sub RemoveHtmlFile { # $file ; removes existing html file
# returns 1 if file was removed
	my $file = shift;
	if (!$file) {
		return 0;
	}
	if ($file eq 'index.html') {
		# do not remove index.html
		# temporary measure until caching is fixed
		# also needs a fix for lazy html, because htaccess rewrite rule doesn't catch it
		return 0;
	}

	my $HTMLDIR = './html'; #todo

	my $fileProvided = $file;
	$file = "$HTMLDIR/$file";

	if (
		$file =~ m/^([0-9a-z\/.]+)$/
			&&
		index($file, '..') == -1
	) {
		# sanity check
	 	$file = $1;
		if (-e $file) {
			unlink($file);
		}
	} else {
		WriteLog('RemoveHtmlFile: warning: sanity check failed, $file = ' . $file);
		return '';
	}
} # RemoveHtmlFile()


1;
