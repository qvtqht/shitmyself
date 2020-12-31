#!/usr/bin/perl -T

use strict;
use warnings;
use utf8;

my @argsFound;
while (my $argFound = shift) {
	push @argsFound, $argFound;
}

require('./utils.pl');
require('./index.pl');

sub GpgParse {
	# PgpParse {
	# $filePath = path to file containing the text
	#
	# $returnValues{'isSigned'} = whether the message has a valid signature: 0 or 1 for valid signature
	# $returnValues{'signTimestamp'} = timestamp of gpg signature, if any
	# $returnValues{'text'} = original text
	# $returnValues{'message'} = message text without framing
	# $returnValues{'key'} = fingerprint of signer
	# $returnValues{'alias'} = alias of signer, if they've added one by submitting their public key
	# $returnValues{'keyExpired'} = whether the key has expired: 0 for not expired, 1 for expired
	# $returnValues{'gitHash'} = git's hash of the file's contents
	# $returnValues{'verifyError'} = whether there was an error with parsing the message

	my %returnValues;

	my $filePath = shift;
	if (!$filePath || !-e $filePath || -d $filePath) {
		WriteLog('GpgParse: warning: $filePath missing, non-existent, or a directory');
		return '';
	}
	WriteLog("GpgParse($filePath)");

	if ($filePath =~ m/([a-zA-Z0-9\.\/]+)/) {
		$filePath = $1;
	} else {
		WriteLog('GpgParse: sanity check failed on $filePath, returning');
		return '';
	}

	my $fileHash = GetFileHash($filePath);

	my $CACHEPATH = GetDir('cache');
	my $cachePathStderr = "$CACHEPATH/gpg_stderr";
	my $cachePathMessage = "$CACHEPATH/gpg_message";

	if ($cachePathStderr =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathStderr = $1;
		WriteLog('GpgParse: $cachePathStderr sanity check passed: ' . $cachePathStderr);
	} else {
		WriteLog('GpgParse: warning: sanity check failed, $cachePathStderr = ' . $cachePathStderr);
		return '';
	}
	if ($cachePathMessage =~ m/^([a-zA-Z0-9_\/.]+)$/) {
		$cachePathMessage = $1;
		WriteLog('GpgParse: $cachePathMessage sanity check passed: ' . $cachePathMessage);
	} else {
		WriteLog('GpgParse: warning: sanity check failed, $cachePathMessage = ' . $cachePathMessage);
		return;
	}

	my $pubKeyFlag = 0;

	if (!-e "$cachePathStderr/$fileHash.txt") {
		WriteLog('GpgParse: found stderr output: ' . "$cachePathStderr/$fileHash.txt");

		my $fileContents = GetFile($filePath);

		my $gpgPubkey = '-----BEGIN PGP PUBLIC KEY BLOCK-----';
		my $gpgMessage = '-----BEGIN PGP SIGNED MESSAGE-----';
		my $gpgEncrypted = '-----BEGIN PGP MESSAGE-----';

		my $gpgCommand = 'gpg --pinentry-mode=loopback --batch ';

		if (index($fileContents, $gpgPubkey) > -1) {
			$gpgCommand .= '--import --ignore-time-conflict --ignore-valid-from ';
			$pubKeyFlag = 1;
		}
		elsif (index($fileContents, $gpgMessage) > -1) {
			$gpgCommand .= '--verify ';
		}
		elsif (index($fileContents, $gpgEncrypted) > -1) {
			$gpgCommand .= '--decrypt ';
		}

		if ($fileHash =~ m/^([0-9a-f]+)$/) {
			$fileHash = $1;
		} else {
			WriteLog('GpgParse: sanity check failed, $fileHash = ' . $fileHash);
			return '';
		}

		$gpgCommand .= "$filePath ";
		$gpgCommand .= ">$cachePathMessage/$fileHash.txt ";
		$gpgCommand .= "2>$cachePathStderr/$fileHash.txt ";

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

		if ($gpgStderrOutput =~ /([0-9A-F]{40})/) {
			$returnValues{'key_long'} = $1;
		}
		if ($gpgStderrOutput =~ /([0-9A-F]{16})/) {
			$returnValues{'isSigned'} = 1;
			$returnValues{'key'} = $1;
		}
		if ($gpgStderrOutput =~ /Signature made (.+)/) {
			# my $gpgDateEpoch = #todo convert to epoch time
			WriteLog('GpgParse: ' . $fileHash . '; found signature made token from gpg');
			$returnValues{'signTimestamp'} = $1;
		}

		WriteLog('GpgParse: ' . $fileHash . '; $pubKeyFlag = ' . $pubKeyFlag);
		if ($pubKeyFlag) {
			if ($gpgStderrOutput =~ /\"([ a-zA-Z0-9<>&\@.()\\\/]+)\"/) {
				# we found something which looks like a name
				my $aliasReturned = $1;
				$aliasReturned =~ s/\<(.+\@.+?)\>//g; # if has something which looks like an email, remove it

				$returnValues{'alias'} = $aliasReturned;
			} else {
				$returnValues{'alias'} = '?????';
			}

			my $name = $returnValues{'alias'};
			my $fingerprint = $returnValues{'key'};

			if (!$name) {
				WriteLog('GpgParse: warning: no name/alias from file ' . $filePath);
				$name = '(name)';
			}
			if (!$fingerprint) {
				WriteLog('GpgParse: warning: no fingerprint/key from file ' . $filePath);
				$fingerprint = '(fingerprint)';
			}

			my $message;
			$message = GetTemplate('message/user_reg.template');
			$message =~ s/\$name/$name/g;
			$message =~ s/\$fingerprint/$fingerprint/g;
			$returnValues{'message'} = $message;
		} # $pubKeyFlag
		else {
			WriteLog('GpgParse: not a pubkey, just take whatever pgp output for us');
			# not a pubkey, just take whatever pgp output for us
			$returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
		}
	} # $gpgStderrOutput
	else {
		# for some reason gpg didn't output anything, so just put the original message
		# $returnValues{'message'} = GetFile("$cachePathMessage/$fileHash.txt");
		#WriteLog('GpgParse: warning: ' . $fileHash . '; $gpgStderrOutput was false!');
	}

	if ($returnValues{'message'} eq '') {
		WriteLog('GpgParse: ' . $fileHash . '; warning: $returnValues{message} is empty!');
	}

	$returnValues{'text'} = GetFile($filePath);
	$returnValues{'verifyError'} = 0;

	foreach(keys %returnValues) {
		WriteLog('GpgParse: ' . $_ . ' = ' . $returnValues{$_});
	}

	return %returnValues;
} # GpgParse()

while (my $arg1 = shift @argsFound) {
	WriteLog('index.pl: $arg1 = ' . $arg1);
	if ($arg1) {
		if (-e $arg1) {
			IndexFile($arg1);
			IndexFile('flush');

			print GpgParse($arg1);
			print "\n";
		}
	}
}

1;
