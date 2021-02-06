#!/usr/bin/perl -T

# gpgpg.pl (gnu pretty good privacy guard)

# INPUT:
# path(s) to one or more text file(s)
#
# PROCESS:
# look for gpg-looking strings #gpg_strings
# prepare arguments for calling gpg: #gpg_prepare
#   if signed message: perform signature verification #gpg_signed
#   if public key: adds to keychain #gpg_pubkey
#   if encrypted message: displays message #gpg_encrypted
# call gpg #gpg_call
#   STDOUT and STDERR is piped to cache #gpg_command_pipe
# naive regex string-matching is used to pull out values #gpg_naive_regex
#   anything good is written to database
#   #gpg_naive_regex_pubkey #gpg_naive_regex_signed #gpg_naive_regex_encrypted


use strict;
use warnings;
use utf8;
use 5.010;

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

require('./utils.pl');
#require('./index.pl');

sub GpgParse { # $filePath ; parses file and stores gpg response in cache
	# PgpParse {
	# $filePath = path to file containing the text
	#

	my $filePath = shift;
	if (!$filePath || !-e $filePath || -d $filePath) {
		WriteLog('GpgParse: warning: $filePath missing, non-existent, or a directory');
		return '';
	}
	if ($filePath =~ m/([a-zA-Z0-9\.\/]+)/) {
		$filePath = $1;
	} else {
		WriteLog('GpgParse: warning: sanity check failed on $filePath, returning');
		return '';
	}

	WriteLog("GpgParse($filePath)");
	my $fileHash = GetFileHash($filePath);

	if (!$fileHash || !IsItem($fileHash)) {
		WriteLog('GpgParse: warning: sanity check failed on $fileHash returned by GetFileHash($filePath), returning');
		return '';
	}

	my $CACHEPATH = GetDir('cache');
	my $cachePathStderr = "$CACHEPATH/gpg_stderr";
	if ($cachePathStderr =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathStderr = $1;
		WriteLog('GpgParse: $cachePathStderr sanity check passed: ' . $cachePathStderr);
	} else {
		WriteLog('GpgParse: warning: sanity check failed, $cachePathStderr = ' . $cachePathStderr);
		return '';
	}

	my $pubKeyFlag = 0;
	my $encryptedFlag = 0;
	my $signedFlag = 0;

	if (!-e "$cachePathStderr/$fileHash.txt") { # no gpg stderr output saved
		# we've not yet run gpg on this file
		WriteLog('GpgParse: found stderr output: ' . "$cachePathStderr/$fileHash.txt");
		my $fileContents = GetFile($filePath);

		#gpg_strings
		my $gpgPubkey = '-----BEGIN PGP PUBLIC KEY BLOCK-----';
		my $gpgSigned = '-----BEGIN PGP SIGNED MESSAGE-----';
		my $gpgEncrypted = '-----BEGIN PGP MESSAGE-----';

		# gpg_prepare
		# this is the base gpg command
		# these flags help prevent stalling due to password prompts
		my $gpgCommand = 'gpg --pinentry-mode=loopback --batch ';

		# basic message classification covering only three cases, exclusively
		if (index($fileContents, $gpgPubkey) > -1) {
			#gpg_pubkey
			WriteLog('GpgParse: found $gpgPubkey');
			$gpgCommand .= '--import --ignore-time-conflict --ignore-valid-from ';
			$pubKeyFlag = 1;
		}
		elsif (index($fileContents, $gpgSigned) > -1) {
			#gpg_signed
			WriteLog('GpgParse: found $gpgSigned');
			$gpgCommand .= '--verify -o - ';
			$signedFlag = 1;
		}
		elsif (index($fileContents, $gpgEncrypted) > -1) {
			#gpg_encrypted
			WriteLog('GpgParse: found $gpgEncrypted');
			$gpgCommand .= '-o - --decrypt ';
			$encryptedFlag = 1;
		} else {
			WriteLog('GpgParse: did not find any relevant strings, returning');
			return '';
		}

		if ($fileHash =~ m/^([0-9a-f]+)$/) {
			#todo not sure if this is needed, since $fileHash is checked above
			$fileHash = $1;
		} else {
			WriteLog('GpgParse: sanity check failed, $fileHash = ' . $fileHash);
			return '';
		}

		#gpg_command_pipe
		my $messageCachePath = GetFileMessageCachePath($filePath) . '_gpg';
		$gpgCommand .= "$filePath "; # file we're parsing
		$gpgCommand .= ">$messageCachePath "; # capture stdout
		$gpgCommand .= "2>$cachePathStderr/$fileHash.txt "; # capture stdeerr
		WriteLog('GpgParse: ' . $fileHash . '; $gpgCommand = ' . $gpgCommand);
		system($gpgCommand);
	}

	my $gpgStderrOutput = GetCache("gpg_stderr/$fileHash.txt");
	if (!defined($gpgStderrOutput)) {
		WriteLog('GpgParse: warning: GetCache(gpg_stderr/$fileHash.txt) returned undefined!');
		$gpgStderrOutput = '';
	}

	if ($gpgStderrOutput) {
		WriteLog('GpgParse: ' . $fileHash . '; $gpgStderrOutput = ' . $gpgStderrOutput);
		WriteLog('GpgParse: ' . $fileHash . '; $pubKeyFlag = ' . $pubKeyFlag);

		if ($pubKeyFlag) {
			my $gpgKeyPub = '';

			if ($gpgStderrOutput =~ /([0-9A-F]{16})/) { # username allowed characters chars filter is here
				$gpgKeyPub = $1;
				DBAddItemAttribute($fileHash, 'gpg_id', $gpgKeyPub);

				if ($gpgStderrOutput =~ m/"([ a-zA-Z0-9<>&\@.()_]+)"/) {
					# we found something which looks like a name
					my $aliasReturned = $1;
					$aliasReturned =~ s/\<(.+\@.+?)\>//g; # if has something which looks like an email, remove it

					if ($gpgKeyPub && $aliasReturned) {
						#gpg_naive_regex_pubkey
						my $message;
						$message = GetTemplate('message/user_reg.template');

						$message =~ s/\$name/$aliasReturned/g;
						$message =~ s/\$fingerprint/$gpgKeyPub/g;

						DBAddVoteRecord($fileHash, GetTime(), 'pubkey', $gpgKeyPub, $fileHash);
						# sub DBAddVoteRecord { # $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash ; Adds a new vote (tag) record to an item based on vote/ token


						DBAddItemAttribute($fileHash, 'gpg_alias', $aliasReturned);

						# gpg author alias shim
						DBAddKeyAlias($gpgKeyPub, $aliasReturned);
						DBAddKeyAlias('flush');

						PutFileMessage($fileHash, $message);
					} else {

					}
				} else {
					WriteLog('GpgParse: warning: alias not found in pubkey mode');
					#DBAddItemAttribute($fileHash, 'gpg_alias', '???');
					#$message =~ s/\$name/???/g;
				}

				return $gpgKeyPub;
			}


		} # $pubKeyFlag
		elsif ($signedFlag) {
			my $gpgKeySigned = '';
			#gpg_naive_regex_signed
			if ($gpgStderrOutput =~ /([0-9A-F]{16})/) {
				$gpgKeySigned = $1;
				DBAddItemAttribute($fileHash, 'gpg_id', $gpgKeySigned);
			}

			if ($gpgStderrOutput =~ /Signature made (.+)/) {
				# my $gpgDateEpoch = #todo convert to epoch time
				WriteLog('GpgParse: ' . $fileHash . '; found signature made token from gpg');
				my $signTimestamp = $1;
				chomp $signTimestamp;
				my $signTimestampEpoch = `date --date='$signTimestamp' +%s`;
				chomp $signTimestampEpoch;

				WriteLog('GpgParse: $signTimestamp = ' . $signTimestamp . '; $signTimestampEpoch = ' . $signTimestampEpoch);

				DBAddItemAttribute($fileHash, 'gpg_timestamp', $signTimestampEpoch);
			}
			return $gpgKeySigned;
		}
		elsif ($encryptedFlag) {
			#gpg_naive_regex_encrypted
			DBAddItemAttribute($fileHash, 'gpg_encrypted', 1);
			PutFileMessage($fileHash, '(Encrypted message)');
			WriteLog('GpgParse: $encryptedFlag was true, setting message accordingly');
			return 1;
		} else {
			# not a pubkey, just take whatever pgp output for us
			WriteLog('GpgParse: fallthrough, nothing gpg-worthy found...');
			return '';
		}
	} # $gpgStderrOutput
	else {
		# for some reason gpg didn't output anything, so just put the original message
		# $returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
		#WriteLog('GpgParse: warning: ' . $fileHash . '; $gpgStderrOutput was false!');
		return '';
	}

	return '';
} # GpgParse()

while (my $arg1 = shift @argsFound) {
	WriteLog('index.pl: $arg1 = ' . $arg1);
	if ($arg1) {
		if (-e $arg1) {
			print GpgParse($arg1);
			print "\n";
		}
	}
}

1;
