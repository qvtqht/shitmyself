#!/usr/bin/perl -T

use strict;
use warnings;
use utf8;
use 5.010;

my @foundArgs;
while (my $argFound = shift) {
	push @foundArgs, $argFound;
}

use lib qw(lib);
#use HTML::Entities qw(encode_entities);
use Digest::MD5 qw(md5_hex);
use POSIX qw(strftime ceil);
use Data::Dumper;
use File::Copy;
# use File::Copy qw(copy);
use Cwd qw(cwd);

#require './utils.pl';
#require './makepage.pl';


sub GetItemPage { # %file ; returns html for individual item page. %file as parameter
	# %file {
	#		file_hash = git's file hash
	#		file_path = path where text file is stored
	#		item_title = title, if any
	#		author_key = author's fingerprint
	#		vote_buttons = 1 to display vote buttons
	#		display_full_hash = 1 to display full hash for permalink (otherwise shortened)
	#		show_vote_summary = 1 to display all votes recieved separately from vote buttons
	#		show_quick_vote = 1 to display quick vote buttons
	#		format_avatars = 1 to format fingerprint-looking strings into avatars
	#		child_count = number of child items for this item
	#		template_name = name of template to use (item.template is default)
	#		remove_token = reply token to remove from message (used for displaying replies)
	#	}

	# we're expecting a reference to a hash as the first parameter
	#todo sanity checks here, it will probably break if anything else is supplied
	# keyword: ItemInfo {
	my %file = %{shift @_};

	# create $fileHash and $filePath variables, since we'll be using them a lot
	my $fileHash = $file{'file_hash'};
	my $filePath = $file{'file_path'};

	WriteLog("GetItemPage(file_hash = " . $file{'file_hash'} . ', file_path = ' . $file{'file_path'} . ")");

	# initialize variable which will contain page html
	my $txtIndex = "";

	my $title = '';     # title for <title>
	my $titleHtml = ''; # title for <h1>

	{
		my $debugOut = '';
		foreach my $key (keys (%file)) {
			$debugOut .= '$file{' . $key . '} = ' . ($file{$key} ? $file{$key} : 'FALSE');
			$debugOut .= "\n";
		}
		WriteLog('GetItemPage: ' . $debugOut);
	}

	if (defined($file{'item_title'}) && $file{'item_title'}) {
		WriteLog("GetItemPage: defined(item_title) = true!");
		$title = HtmlEscape($file{'item_title'});
		$titleHtml = HtmlEscape($file{'item_title'});
		$title .= ' (' . substr($file{'file_hash'}, 0, 8) . '..)';
	}
	else {
		WriteLog("GetItemPage: defined(item_title) = false!");
		$title = $file{'file_hash'};
		$titleHtml = $file{'file_hash'};
	}

	if (defined($file{'author_key'}) && $file{'author_key'}) {
		#todo the .txt extension should not be hard-coded
		my $alias = GetAlias($file{'author_key'});
		$alias = HtmlEscape($alias);
		$title .= " by $alias";
	}

	# Get the HTML page template
	my $htmlStart = GetPageHeader($title, $titleHtml, 'item');
	$txtIndex .= $htmlStart;
	$txtIndex .= GetTemplate('html/maincontent.template');

	$file{'display_full_hash'} = 1;
	$file{'show_vote_summary'} = 1;
	# $file{'show_quick_vote'} = 1;
	$file{'vote_buttons'} = 1;
	$file{'format_avatars'} = 1;
	if (!$file{'item_title'}) {
		$file{'item_title'} = 'Untitled';
	}

	my $itemTemplate = GetItemTemplate2(\%file); # GetItemPage()
	WriteLog('GetItemPage: child_count: ' . $file{'file_hash'} . ' = ' . $file{'child_count'});
	$file{'show_easyfind'} = 0;

	if ($file{'show_easyfind'}) {
		my $itemEasyFind = GetItemEasyFind($fileHash);
		#$itemTemplate =~ s/\$itemEasyFind/EasyFind: $itemEasyFind/g;
		$itemTemplate .= $itemEasyFind;
	} else {
		#$itemTemplate =~ s/\$itemEasyFind//g;
	}

	###############
	### /REPLIES##########

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	if (GetConfig('reply/enable')) {
		my $voteButtons = '';
		$voteButtons .= GetItemTagButtons($file{'file_hash'});

		$txtIndex .= '<p><span class=advanced>'.GetWindowTemplate($voteButtons, 'Classify').'</span></p>';
		$txtIndex .= GetReplyListing($file{'file_hash'});
		$txtIndex .= GetReplyForm($file{'file_hash'});
	}

	$txtIndex .= GetItemAttributesWindow(\%file);

	$txtIndex .= GetMenuTemplate();

	# end page with footer
	$txtIndex .= GetPageFooter();

	if (GetConfig('reply/enable')) {
		# if replies is on, include write.js and write_buttons.js
		my @js = qw(settings avatar voting utils profile translit write write_buttons timestamp);
		if (GetConfig('admin/php/enable')) {
			push @js, 'write_php';
		}
		$txtIndex = InjectJs($txtIndex, @js);

	} else {
		$txtIndex = InjectJs($txtIndex, qw(settings avatar voting utils profile translit timestamp));
	}

	#	my $scriptsInclude = '<script src="/openpgp.js"></script><script src="/crypto2.js"></script>';
#	$txtIndex =~ s/<\/body>/$scriptsInclude<\/body>/;

	return $txtIndex;
} # GetItemPage()

sub GetReplyListingEmpty {
	my $html = '<p>No replies found.</p>';
	$html = GetWindowTemplate($html, 'Replies');
	return $html;
}

sub GetReplyListing {
	# if this item has a child_count, we want to print all the child items below
	# keywords: reply replies subitems child parent
	# REPLIES #replies #reply GetItemPage()
	######################################

	if (my $fileHash = shift) {
		my @itemReplies = DBGetItemReplies($fileHash);

		if (@itemReplies) {
			return GetItemListing($fileHash);;
		} else {
			return GetReplyListingEmpty($fileHash);
		}
	} else {
		return GetReplyListingEmpty($fileHash);
	}

	WriteLog('GetReplyListing: warning: unreachable reached');
	return '';
} # GetReplyListing()

sub GetItemAttributesWindow {
	#my $itemInfoTemplate = GetTemplate('html/item_info.template');
	my $itemInfoTemplate;
	WriteLog('GetItemPage: my $itemInfoTemplate; ');

	my %file = %{shift @_};

	my $fileHash = $file{'file_hash'};

	#todo sanity checks

	my $itemAttributes = DBGetItemAttribute($fileHash);
	$itemAttributes = trim($itemAttributes);

	my $itemAttributesTable = '';
	{ # arrange into table nicely
		foreach my $itemAttribute (split("\n", $itemAttributes)) {
			if ($itemAttribute) {
				my ($iaName, $iaValue) = split('\|', $itemAttribute);

				{
					# this part formats some values for output
					if ($iaName =~ m/_timestamp/) {
						# timestamps
						$iaValue = $iaValue . ' (' . GetTimestampWidget($iaValue) . ')';
					}
					if ($iaName =~ m/file_size/) {
						# timestamps
						$iaValue = $iaValue . ' (' . GetFileSizeWidget($iaValue) . ')';
					}
					if ($iaName eq 'author_key' || $iaName eq 'cookie_id' || $iaName eq 'gpg_id') {
						# turn author key into avatar
						$iaValue = '<tt>' . $iaValue . '</tt>' . ' (' . trim(GetAuthorLink($iaValue)) . ')';
					}
					if ($iaName eq 'title') {
						# title needs to be escaped
						$iaValue = HtmlEscape($iaValue);
					}
					if ($iaName eq 'gpg_alias') {
						# aka signature / username, needs to be escaped
						$iaValue = HtmlEscape($iaValue);
					}
					if ($iaName eq 'file_path') {
						# link file path to file
						my $HTMLDIR = GetDir('html'); #todo
						WriteLog('attr: $HTMLDIR = ' . $HTMLDIR); #todo
						#problem here is GetDir() returns full path, but here we already have relative path
						#currently we assume html dir is 'html'

						WriteLog('attr: $iaValue = ' . $iaValue); #todo
						if (GetConfig('html/relativize_urls')) {
							$iaValue =~ s/^html\//.\//;
						} else {
							$iaValue =~ s/^html\//\//;
						}
						WriteLog('attr: $iaValue = ' . $iaValue); #todo

						$iaValue = HtmlEscape($iaValue);
						$iaValue = '<a href="' . $iaValue . '">' . $iaValue . '</a>';
						#todo sanitizing #security
					}
					if ($iaName eq 'sha1' || $iaName eq 'md5' || $iaName eq 'chain_previous') { #todo make it match on _hash and use _hash on the names
						$iaValue = '<tt>' . $iaValue . '</tt>';
					}
				}

				$itemAttributesTable .= '<tr><td>';
				$itemAttributesTable .= GetString("item_attribute/$iaName") . ':';
				$itemAttributesTable .= '</td><td>';
				$itemAttributesTable .= $iaValue;
				$itemAttributesTable .= '</td></tr>';
			}
		}



		if (defined($file{'tags_list'})) { # bolt on tags list as an attribute
			$itemAttributesTable .= '<tr><td>';
			$itemAttributesTable .= GetString('item_attribute/tags_list');
			$itemAttributesTable .= '</td><td>';
			$itemAttributesTable .= $file{'tags_list'};
			$itemAttributesTable .= '</td></tr>';
		}

		if (defined($file{'item_score'})) { # bolt on item score
			$itemAttributesTable .= '<tr><td>';
			$itemAttributesTable .= GetString('item_attribute/item_score');
			$itemAttributesTable .= '</td><td>';
			$itemAttributesTable .= $file{'item_score'};
			$itemAttributesTable .= '</td></tr>';
		}

		$itemAttributesTable = '<tbody class=content>' . $itemAttributesTable . '</tbody>';

		my $itemAttributesWindow = GetWindowTemplate($itemAttributesTable, 'Item Attributes', 'attribute,value');
		$itemAttributesWindow = '<span class=advanced>' . $itemAttributesWindow . '</span>';
		return $itemAttributesWindow;
	}
} #attributes

sub GetPublishForm {
	my $template = GetTemplate('html/form/publish.template');

	my $textEncoded = 'abc';

	$template =~ str_replace('?comment=', '?comment=' . $textEncoded);

	return $template;
}

1;