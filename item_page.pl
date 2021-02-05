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
	#		vote_buttons = 1 to display vote buttons (checkboxes)
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

	WriteLog("GetItemPage(" . $file{'file_path'} . ")");

	# initialize variable which will contain page html
	my $txtIndex = "";

	my $title = '';     # title for <title>
	my $titleHtml = ''; # title for <h1>

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

	# if this item has a child_count, we want to print all the child items below
	# keywords: reply replies subitems child parent
	# REPLIES #replies #reply GetItemPage()
	######################################
	if ($file{'child_count'}) {
		# get item's children (replies) and store in @itemReplies
		my @itemReplies = DBGetItemReplies($file{'file_hash'});

		#debug message
		WriteLog('@itemReplies = ' . @itemReplies);

		# this will contain the replies as html output
		my $allReplies = '';

		{
			my $voteButtons = GetItemTagButtons($file{'file_hash'});
			$allReplies .= '<hr>'.GetWindowTemplate($voteButtons, 'Add Tags').'<hr>'; #todo make class=advanced
		}

		if (GetConfig('replies') && GetConfig('html/reply_form_before_reply_list')) {
			# add reply form before replies
			my $replyForm = GetReplyForm($file{'file_hash'});
			$allReplies .= $replyForm;
		}

		# start with a horizontal rule to separate from above content
		$allReplies .= '<hr size=3>';

		# this will store separator between items.
		# first item doesn't need separator above it
		my $replyComma = '';

		foreach my $replyItem (@itemReplies) {
			# output info about item to debug
			WriteLog('$replyItem: ' . $replyItem);
			foreach my $replyVar ($replyItem) {
				WriteLog($replyVar);
			}

			DBAddItemPage($$replyItem{'file_hash'}, 'item', $file{'file_hash'});

			# use item-small template to display the reply items
			#$$replyItem{'template_name'} = 'html/item/item.template';

			# if the child item contains a reply token for our parent item
			# we want to remove it, to reduce redundant information on the page
			# to do this, we pass the remove_token parameter to GetItemTemplate() below
			$$replyItem{'remove_token'} = '>>' . $file{'file_hash'};

			# after voting, return to the main thread page
			$$replyItem{'vote_return_to'} = $file{'file_hash'};

			# trim long text items
			$$replyItem{'trim_long_text'} = 1;
#
#			if (index(','.$$replyItem{'tags_list'}.',', ','.'notext'.',') != -1) {
#				$$replyItem{'template_name'} = 'html/item/item.template';
#			} else {
#				$$replyItem{'template_name'} = 'html/item/item.template';
#			}

			# Get the reply template
			my $replyTemplate = GetItemTemplate($replyItem); # GetItemPage()

			# output it to debug
			WriteLog('$replyTemplate for ' . $$replyItem{'template_name'} . ':');
			WriteLog($replyTemplate);

			# if the reply item has children also, output the children
			# threads are currently limited to 2 steps
			# eventually, recurdsion can be used to output more levels
			if ($$replyItem{'child_count'}) {
				my $subRepliesTemplate = ''; # will store the sub-replies html output

				my $subReplyComma = ''; # separator for sub-replies, set to <hr on first use

				my @subReplies = DBGetItemReplies($$replyItem{'file_hash'});
				foreach my $subReplyItem (@subReplies) {
					DBAddItemPage($$subReplyItem{'file_hash'}, 'item', $file{'file_hash'});
#
#					if (index(','.$$subReplyItem{'tags_list'}.',', ','.'notext'.',') != -1) {
#						$$subReplyItem{'template_name'} = 'html/item/item.template';
#						# $$subReplyItem{'template_name'} = 'html/item/item-mini.template';
#					} else {
#						$$subReplyItem{'template_name'} = 'html/item/item.template';
#						# $$subReplyItem{'template_name'} = 'html/item/item-small.template';
#					}
					$$subReplyItem{'remove_token'} = '>>' . $$replyItem{'file_hash'};
					$$subReplyItem{'vote_return_to'} = $file{'file_hash'};

					WriteLog('$$subReplyItem{\'remove_token\'} = ' . $$subReplyItem{'remove_token'});
					WriteLog('$$subReplyItem{\'template_name\'} = ' . $$subReplyItem{'template_name'});
					WriteLog('$$subReplyItem{\'vote_return_to\'} = ' . $$subReplyItem{'vote_return_to'});

					$$subReplyItem{'trim_long_text'} = 1;
					my $subReplyTemplate = GetItemTemplate($subReplyItem); # GetItemPage()
					if ($subReplyComma eq '') {
						$subReplyComma = '<hr size=4>';
					}
					else {
						$subReplyTemplate = $subReplyComma . $replyTemplate;
					}
					$subRepliesTemplate .= $subReplyTemplate;
				}

				# replace replies placeholder with generated html
				$replyTemplate =~ s/<replies><\/replies>/$subRepliesTemplate/;
			}
			else {
				# there are no replies, so remove replies placeholder
				$replyTemplate =~ s/<replies><\/replies>//;
			}

			if ($replyTemplate) {
				if ($replyComma eq '') {
					$replyComma = '<hr size=5>';
					# $replyComma = '<p>';
				}
				else {
					$replyTemplate = $replyComma . $replyTemplate;
				}

				$allReplies .= $replyTemplate;
			}
			else {
				WriteLog('Warning: replyTemplate is missing for some reason!');
			}
		} # foreach my $replyItem (@itemReplies)

		if (GetConfig('replies') && GetConfig('html/reply_form_after_reply_list') && !GetConfig('html/reply_form_before_reply_list')) {
			# add reply form after replies
			my $replyForm = GetReplyForm($file{'file_hash'});
			# start with a horizontal rule to separate from above content
			$allReplies .= '<hr size=6>';
			$allReplies .= $replyForm;
		}

		$itemTemplate =~ s/<replies><\/replies>/$allReplies/;
		$itemTemplate .= '<hr><br>';
	} # $file{'child_count'}
	else {
		my $allReplies = '';
		if (GetConfig('replies')) {
			# add reply form if no existing replies

			{
				my $voteButtons = GetItemTagButtons($file{'file_hash'});
				$allReplies .= '<hr>'.GetWindowTemplate($voteButtons, 'Add Tags').'<hr>';
			}


			my $replyForm = GetReplyForm($file{'file_hash'});
			$allReplies .= $replyForm;
		}
		$itemTemplate =~ s/<replies><\/replies>/$allReplies/;
		$itemTemplate .= '<hr><br>';
	} # replies and reply form

	###############
	### /REPLIES##########

	if ($itemTemplate) {
		$txtIndex .= $itemTemplate;
	}

	{
		#my $itemInfoTemplate = GetTemplate('html/item_info.template');
		my $itemInfoTemplate;
		WriteLog('GetItemPage: my $itemInfoTemplate; ');

		my $itemAttributes = DBGetItemAttribute($file{'file_hash'});
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
							$iaValue = $iaValue . ' (' . trim(GetAuthorLink($iaValue)) . ')';
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

			my $itemAttributesWindow = GetWindowTemplate($itemAttributesTable, 'Item Attributes', 'attribute,value');
			$itemAttributesWindow = '<span class=advanced>' . $itemAttributesWindow . '</span>';
			$txtIndex .= $itemAttributesWindow;
		}
	}

	$txtIndex .= GetMenuTemplate();

	# end page with footer
	$txtIndex .= GetPageFooter();

	if (GetConfig('replies')) {
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


1;