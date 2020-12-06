
	while (@hashTags) {
		my $hashTagToken = shift @hashTags;
		$hashTagToken = trim($hashTagToken);
		my $hashTag = shift @hashTags;
		$hashTag = trim($hashTag);

		if ($hashTag && (IsAdmin($gpgKey) || $authorHasTag{'admin'} || $authorHasTag{$hashTag})) {
			#if ($hashTag) {
			WriteLog('IndexTextFile: $hashTag = ' . $hashTag);

			$hasToken{$hashTag} = 1;

			if ($hasParent) {
				WriteLog('$hasParent');

			} # if ($hasParent)
			else { # no parent, !($hasParent)
				WriteLog('$hasParent is FALSE');

				if ($isSigned) {
					# include author's key if message is signed
					DBAddVoteRecord($fileHash, $addedTime, $hashTag, $gpgKey, $fileHash);
				}
				else {
					if ($hasCookie) {
						DBAddVoteRecord($fileHash, $addedTime, $hashTag, $hasCookie, $fileHash);
					} else {
						DBAddVoteRecord($fileHash, $addedTime, $hashTag, '', $fileHash);
					}
				}
			}

			DBAddPageTouch('tag', $hashTag);

			$detokenedMessage =~ s/#$hashTag//g;
		} # if ($hashTag)
	} # while (@hashTags)
} # if (GetConfig('admin/token/hashtag') && $message)









{
	# look up author's tags

	my @tagsAppliedToAuthor = DBGetAllAppliedTags(DBGetAuthorPublicKeyHash($gpgKey));
	foreach my $tagAppliedToAuthor (@tagsAppliedToAuthor) {
		$authorHasTag{$tagAppliedToAuthor} = 1;
		my $tagsInTagSet = GetConfig('tagset/' . $tagAppliedToAuthor);
		# if ($tagsInTagSet) {
		# 	foreach my $tagInTagSet (split("\n", $tagsInTagSet)) {
		# 		if ($tagInTagSet) {
		# 			$authorHasTag{$tagInTagSet} = 1;
		# 		}
		# 	}
		# }
	}
}
#DBAddItemAttribute($fileHash, 'x_author_tags', join(',', keys %authorHasTag));





















		#my $lineCount = @setTitleToLines / 3;
		while (@lines) {
			# loop through all found title: token lines
			my $token = shift @lines;
			my $space = shift @lines;
			my $value = shift @lines;

			chomp $token;
			chomp $space;
			chomp $value;
			$value = trim($value);

			my $reconLine; # reconciliation
			$reconLine = $token . $space . $value;

			WriteLog('IndexTextFile: #verify $reconLine = ' . $reconLine);
			WriteLog('IndexTextFile: #verify $value = ' . $value);

			if ($value =~ m|https://www.reddit.com/user/([0-9a-zA-Z\-_]+)/?|) {
				# reddit verify
				$hasToken{'verify'} = 1;
				my $redditUsername = $1;
				my $valueHash = sha1_hex($value);
				my $profileHtml = '';

				if (-e "once/$valueHash") {
					WriteLog('IndexTextFile: once exists');
					$profileHtml = GetFile("once/$valueHash");
				} else {
					my $curlCommand = 'curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36" "' . EscapeShellChars($value) .'.json"';
					WriteLog('IndexTextFile: #verify once needed, doing curl');
					WriteLog('IndexTextFile: #verify "' . $curlCommand . '"');

					my $curlResult = `$curlCommand`; #note the backticks
					# this could be dangerous, but the url is sanitized above

					PutFile("once/$valueHash", $curlResult);
					$profileHtml = GetFile("once/$valueHash");
				}

				WriteLog('IndexTextFile: #verify $value = ' . $value);

				if ($hasParent) {
					# has parent(s), so add title to each parent
					foreach my $itemParent (@itemParents) {
						if (index($profileHtml, $itemParent) != -1) {
							DBAddItemAttribute($itemParent, 'reddit_url', $value, $addedTime, $fileHash);
							DBAddItemAttribute($itemParent, 'reddit_username', $redditUsername, $addedTime, $fileHash);
							DBAddPageTouch('item', $itemParent);
						}
					} # @itemParents
				} else {
					# no parents, ignore
					WriteLog('IndexTextFile: AccessLogHash: Item has no parent, ignoring');

					# DBAddVoteRecord($fileHash, $addedTime, 'hasAccessLogHash');
					# DBAddItemAttribute($fileHash, 'AccessLogHash', $titleGiven, $addedTime);
				}
			} #reddit


			if ($value =~ m|https://www.twitter.com/([0-9a-zA-Z_]+)/?|) { # supposed to be 15 chars or less
				# twitter verify
				$hasToken{'verify'} = 1;
				my $twitterUsername = $1;
				my $valueHash = sha1_hex($value);
				my $profileHtml = '';

				if (-e "once/$valueHash") {
					WriteLog('IndexTextFile: once exists');
					$profileHtml = GetFile("once/$valueHash");
				} else {
					my $curlCommand = 'curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36" "' . EscapeShellChars($value);

					WriteLog('IndexTextFile: #verify once needed, doing curl');
					WriteLog('IndexTextFile: #verify "' . $curlCommand . '"');

					my $curlResult = `$curlCommand`; #note the backticks
					# should be safe because url is sanitized above

					PutFile("once/$valueHash", $curlResult);
					$profileHtml = GetFile("once/$valueHash");
				}

				WriteLog('IndexTextFile: #verify $value = ' . $value);

				if ($hasParent) {
					# has parent(s), so add title to each parent
					foreach my $itemParent (@itemParents) {
						if (index($profileHtml, $itemParent) != -1) {
							DBAddItemAttribute($itemParent, 'twitter_url', $value, $addedTime, $fileHash);
							DBAddItemAttribute($itemParent, 'twitter_username', $twitterUsername, $addedTime, $fileHash);
							DBAddPageTouch('item', $itemParent);
						}
					} # @itemParents
				} else {
					# no parents, ignore
					WriteLog('IndexTextFile: AccessLogHash: Item has no parent, ignoring');

					# DBAddVoteRecord($fileHash, $addedTime, 'hasAccessLogHash');
					# DBAddItemAttribute($fileHash, 'AccessLogHash', $titleGiven, $addedTime);
				}
			} # twitter

			if ($value =~ m|https://www.instagram.com/([0-9a-zA-Z._]+)/?|) {
				# instagram verification (not working yet)
				$hasToken{'verify'} = 1;
				my $instaUsername = $1;
				my $valueHash = sha1_hex($value);
				my $profileHtml = '';

				if (-e "once/$valueHash") {
					WriteLog('IndexTextFile: once exists');
					$profileHtml = GetFile("once/$valueHash");
				} else {
					my $curlCommand = 'curl -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.117 Safari/537.36" "' . EscapeShellChars($value) . '"';

					WriteLog('IndexTextFile: #verify once needed, doing curl');
					WriteLog('IndexTextFile: #verify "'.$curlCommand.'"');

					my $curlResult = `$curlCommand`; #note backticks
					# should be safe because url is sanitized above

					PutFile("once/$valueHash", $curlResult); # runs the curl command, note the backticks
					$profileHtml = GetFile("once/$valueHash");
				}

				WriteLog('IndexTextFile: #verify $value = ' . $value);

				if ($hasParent) {
					# has parent(s), so add title to each parent
					foreach my $itemParent (@itemParents) {
						if (index($profileHtml, $itemParent) != -1) {
							DBAddItemAttribute($itemParent, 'insta_url', $value, $addedTime, $fileHash);
							DBAddItemAttribute($itemParent, 'insta_username', $instaUsername, $addedTime, $fileHash);
							DBAddPageTouch('item', $itemParent);
						}
					} # @itemParents
				} else {
					# no parents, ignore
					WriteLog('IndexTextFile: AccessLogHash: Item has no parent, ignoring');

					# DBAddVoteRecord($fileHash, $addedTime, 'hasAccessLogHash');
					# DBAddItemAttribute($fileHash, 'AccessLogHash', $titleGiven, $addedTime);
				}
			} #instagram

			$message = str_replace($reconLine, '[Verified]', $message);
			$detokenedMessage = str_replace($reconLine, '[Verified]', $detokenedMessage);
			# $message = str_replace($reconLine, '[AccessLogHash: ' . $value . ']', $message);
		} # @lines
	}







		#look for #config and #resetconfig #setconfig
		if (GetConfig('admin/token/config') && $message) {
			if (
				IsAdmin($gpgKey) # admin can always config
					||
				GetConfig('admin/anyone_can_config') # anyone can config
					||
				(
					# signed can config
					GetConfig('admin/signed_can_config')
						&&
					$isSigned
				)
					||
				(
					# cookied can config
					GetConfig('admin/cookied_can_config')
						&&
					$hasCookie
				)
			) {
				# preliminary conditions met
				my @configLines = ($message =~ m/(config)(\W)([a-z0-9\/_]+)(\W+?[=]?\W+?)(.+?)$/mg);
				#                                 1       2   3             4             5
				WriteLog('@configLines = ' . scalar(@configLines));

				if (@configLines) {
					#my $lineCount = @configLines / 5;

					while (@configLines) {
						my $configAction = shift @configLines; # 1
						my $space1 = shift @configLines; # 2
						my $configKey = shift @configLines; # 3
						my $space2 = ''; # 4
						my $configValue; # 5

						# allow theme aliasing, currently only one alias: theme to html/theme
						my $configKeyActual = $configKey;
						if ($configKey eq 'theme') {
							# alias theme to html/theme
							$configKeyActual = 'html/theme';
						}

						$space2 = shift @configLines;
						$configValue = shift @configLines;
						$configValue = trim($configValue);

						if ($configAction && $configKey && $configKeyActual) {
							my $reconLine;
							$reconLine = $configAction . $space1 . $configKey . $space2 . $configValue;
							WriteLog('IndexTextFile: #config: $reconLine = ' . $reconLine);

							if (ConfigKeyValid($configKey) && $reconLine) {
								WriteLog('IndexTextFile: ConfigKeyValid() passed!');
								WriteLog('$reconLine = ' . $reconLine);
								WriteLog('$gpgKey = ' . ($gpgKey ? $gpgKey : '(no)'));
								WriteLog('$isSigned = ' . ($isSigned ? $isSigned : '(no)'));
								WriteLog('$configKey = ' . $configKey);
								WriteLog('signed_can_config = ' . GetConfig('admin/signed_can_config'));
								WriteLog('anyone_can_config = ' . GetConfig('admin/anyone_can_config'));

								my $canConfig = 0;
								if (IsAdmin($gpgKey)) {
									$canConfig = 1;
								}

								if (!$canConfig && substr(lc($configKeyActual), 0, 5) ne 'admin') {
									if (GetConfig('admin/signed_can_config')) {
										if ($isSigned) {
											$canConfig = 1;
										}
									}
									if (GetConfig('admin/cookied_can_config')) {
										if ($hasCookie) {
											$canConfig = 1;
										}
									}
									if (GetConfig('admin/anyone_can_config')) {
										$canConfig = 1;
									}
								}

								if ($canConfig)	{
									# checks passed, we're going to update/reset a config entry
									DBAddVoteRecord($fileHash, $addedTime, 'config');

									$reconLine = quotemeta($reconLine);

									if ($configValue eq 'default') {
										DBAddConfigValue($configKeyActual, $configValue, $addedTime, 1, $fileHash);
										$message =~ s/$reconLine/[Successful config reset: $configKeyActual will be reset to default.]/g;
									}
									else {
										DBAddConfigValue($configKeyActual, $configValue, $addedTime, 0, $fileHash);
										$message =~ s/$reconLine/[Successful config change: $configKeyActual = $configValue]/g;
									}

									$detokenedMessage =~ s/$reconLine//g;

									if ($configKeyActual eq 'html/theme') {
										# unlink cache/avatar.plain
										# remove/rebuild all html
										#todo
									}
								} # if ($canConfig)
								else {
									$message =~ s/$reconLine/[Attempted change to $configKeyActual ignored. Reason: Not operator.]/g;
									$detokenedMessage =~ s/$reconLine//g;
								}
							} # if (ConfigKeyValid($configKey))
							else {
								#$message =~ s/$reconLine/[Attempted change to $configKey ignored. Reason: Config key has no default.]/g;
								#$detokenedMessage =~ s/$reconLine//g;
							}
						}
					} # while
				}
	}
	} # if (GetConfig('admin/token/config') && $message)







		if (0) {
			my %authorHasTag;
			{
				# look up author's tags

				my @tagsAppliedToAuthor = DBGetAllAppliedTags(DBGetAuthorPublicKeyHash($gpgKey));
				foreach my $tagAppliedToAuthor (@tagsAppliedToAuthor) {
					$authorHasTag{$tagAppliedToAuthor} = 1;
					my $tagsInTagSet = GetConfig('tagset/' . $tagAppliedToAuthor);
					# if ($tagsInTagSet) {
					# 	foreach my $tagInTagSet (split("\n", $tagsInTagSet)) {
					# 		if ($tagInTagSet) {
					# 			$authorHasTag{$tagInTagSet} = 1;
					# 		}
					# 	}
					# }
				}
			}
			#DBAddItemAttribute($fileHash, 'x_author_tags', join(',', keys %authorHasTag));
		}
