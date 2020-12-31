#!/usr/bin/perl -T

use strict;
use 5.010;

sub GetString { # $stringKey, $language, $noSubstitutions ; Returns string from config/string/en/
# $stringKey = 'menu/top'
# $language = 'en'
# $noSubstitute = returns empty string if no exact match
	my $defaultLanguage = 'en';

	my $stringKey = shift;
	my $language = shift;
	my $noSubstitute = shift;

	if (!$stringKey) {
		WriteLog('GetString: warning: called without $stringKey, exiting');
		return;
	}
	if (!$language) {
		$language = GetConfig('language');
	}
	if (!$language) {
		$language = $defaultLanguage;
	}

	# this will store all looked up values so that we don't have to look them up again
    state %strings; #memo
    my $memoKey = $stringKey . '/' . $language . '/' . ($noSubstitute ? 1 : 0);

	if (defined($strings{$memoKey})) {
	    #memo match
		return $strings{$memoKey};
	}

	my $string = GetConfig('string/' . $language . '/'.$stringKey);
	if ($string) {
	    # exact match
		chomp ($string);

		$strings{$memoKey} = $string;
	} else {
	    # no match, dig deeper...
		if ($noSubstitute) {
			$strings{$memoKey} = '';
			return '';
		} else {
			if ($language ne $defaultLanguage) {
				$string = GetString($stringKey, $defaultLanguage);
			}

			if (!$string) {
				$string = TrimPath($stringKey);
				# if string is not found, display string key
				# trin string key's path to make it less confusing
			}

			chomp($string);
			$strings{$memoKey} = $string;
			return $string;
		}
	}
} # GetString()

sub trim { # trims whitespace from beginning and end of $string
	my $s = shift;

	if (defined($s)) {
		$s =~ s/\s+$//g;
		$s =~ s/^\s+//g;
		return $s;
	}

	return;
}

sub htmlspecialchars { # $text, encodes supplied string for html output
	# port of php built-in
	my $text = shift;
	$text = encode_entities2($text);
	return $text;
}

sub HtmlEscape { # encodes supplied string for html output
	my $text = shift;
	$text = encode_entities2($text);
	return $text;
}

sub str_repeat {
	my $string = shift;
	my $count = shift;
	WriteLog('str_repeat: $string = ' . $string . '; $count = ' . $count);
	WriteLog('str_repeat: ' . $string x $count); #todo performance?
	return $string x $count;
}

1;
