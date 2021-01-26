#!/usr/bin/perl -T
#
# widget.pl
# returns widget html 
# GetItemTagButtons: voting buttons for an item
# to come: clock, etc

use strict;
use 5.010;
use utf8;

sub GetItemTagButtons { # $fileHash, [$tagSet], [$returnTo] ; get vote buttons for item in html form
	my $fileHash = shift; # item's file hash
	my $tagSet = shift;   # (optional) use a particular tagset instead of item's default
	my $returnTo = shift; # (optional) what page to return to instead of current (for use by post.php)
	WriteLog('GetItemTagButtons(' . ($fileHash ? $fileHash : '-') . ', ' . ($tagSet ? $tagSet : '-') . ')');

	if (!IsItem($fileHash)) {
		WriteLog('GetItemTagButtons: warning: sanity check failed, returning');
		return '';
	}

	my @quickVotesList; # this will hold all the tag buttons we want to display
	my %voteTotals = DBGetItemVoteTotals($fileHash);
	WriteLog('GetItemTagButtons: scalar(%voteTotals) = ' . scalar(%voteTotals));

	if ($tagSet) {
		# if $tagSet is specified, just use that list of tags
		my $quickVotesForTagSet = GetConfig('tagset/' . $tagSet);
		if ($quickVotesForTagSet) {
			push @quickVotesList, split("\n", $quickVotesForTagSet);
		}
		else {
			# no tagset?
			WriteLog('GetItemTagButtons: warning: tagset not found: ' . $tagSet);
			return '';
		}
	} # $tagSet
	else {
		# need to look up item's default tagset
		my $quickVotesForTags;
		foreach my $voteTag (keys %voteTotals) {
			$quickVotesForTags = GetConfig('tagset/' . $voteTag);
			if ($quickVotesForTags) {
				push @quickVotesList, split("\n", $quickVotesForTags);
			}
		}

		# all items will have a 'flag' button
		push @quickVotesList, 'flag';

		# remove duplicates
		my %dedupe = map {$_, 1} @quickVotesList;
		@quickVotesList = keys %dedupe;
	}

	my $styleSheet = GetStylesheet(); # for looking up which vote buttons need a class=
	# if they're listed in the stylesheet, add a class= below
	# the class name is tag-foo, where foo is tag

	my $tagButtons = '';
	my $doVoteButtonStyles = GetConfig('style_vote_buttons');
	my $jsEnabled = GetConfig('admin/js/enable');

	WriteLog('GetItemTagButtons: @quickVotesList = ' . scalar(@quickVotesList));

	foreach my $quickTagValue (@quickVotesList) {
		my $ballotTime = GetTime();

		if ($fileHash && $ballotTime) {
			my $tagButton = GetTemplate('vote/vote_button.template');

			if ($jsEnabled) {
				$tagButton = AddAttributeToTag(
					$tagButton,
					'a', 'onclick',
					trim("
						if (window.SignVote) {
							var gt = unescape('%3E');
							return SignVote(this, gt+gt+'\$fileHash\\n#\$voteValue');
						}
					")
				);
			}

			if ($doVoteButtonStyles) {
				# this is a hack, think about replace with config/tag_color
				if (index($styleSheet, "tag-$quickTagValue") > -1) {
					$tagButton =~ s/\$class/tag-$quickTagValue/g;
				}
				else {
					$tagButton =~ s/class="\$class"//g;
				}
			}

			my $quickTagCaption = GetString($quickTagValue);
			WriteLog('GetItemTagButtons: $$$ ' . $quickTagCaption . ' $ ' . $quickTagValue);
			if ($voteTotals{$quickTagCaption}) {
				# $voteTotals{$quickTagCaption} is the number of tags of this type item has

				$quickTagCaption .= '(' . $voteTotals{$quickTagCaption} . ')';
				# $quickTagCaption = '<b><big>' . $quickTagCaption . '</big></b>';
			}

			if ($returnTo) {
				# set value for $returnTo placeholder
				$tagButton =~ s/\$returnTo/$returnTo/g;
			}
			else {
				# remove entire returnto= parameter
				$tagButton =~ s/&returnto=\$returnTo//g;
			}

			$tagButton =~ s/\$fileHash/$fileHash/g;
			$tagButton =~ s/\$ballotTime/$ballotTime/g;
			$tagButton =~ s/\$voteValue/$quickTagValue/g;
			$tagButton =~ s/\$voteCaption/$quickTagCaption/g;

			$tagButtons .= $tagButton;
		} # if ($fileHash && $ballotTime)
	} # foreach my $quickTagValue (@quickVotesList)

	WriteLog('GetItemTagButtons returning: ' . $tagButtons);

	return $tagButtons;
} # GetItemTagButtons()


1;
