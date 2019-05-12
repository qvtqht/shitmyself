#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use 5.010;
use POSIX;
use Data::Dumper;

use File::Basename qw( fileparse );
use File::Path qw( make_path );
use File::Spec;

use lib 'lib';

use URI::Encode qw(uri_decode);
use URI::Escape;
#use HTML::Entities qw(encode_entities);
use Storable;

# We'll use pwd for for the install root dir
my $SCRIPTDIR = `pwd`; #hardcode #todo
chomp $SCRIPTDIR;

my @dirsThatShouldExist = qw(log html html/txt html/txt/log spam admin key cache html/author html/action html/top config);
push @dirsThatShouldExist, 'cache/' . GetMyVersion();
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/key';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/file';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/avatar';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/message';
push @dirsThatShouldExist, 'cache/' . GetMyVersion() . '/gpg';

foreach(@dirsThatShouldExist) {
	if (!-d && !-e $_) {
		mkdir $_;
	}
	if (!-e $_ || !-d $_) {
		die("$_ should exist, but it doesn't. aborting.");
	}
}

if (!-e 'html/txt/.git') {
	my $pwd = `pwd`;
	system("cd html/txt/ ; git init ; cd $pwd");
}

#if (-s 'log/log.log' > 102400) {
#	unlink ('log/log.log');
#	die('yay');
#}


my $gpgCommand = trim(GetConfig('gpg_command'));
if (!$gpgCommand) {
	if (GetConfig('use_gpg2')) {
		$gpgCommand = 'gpg2';
	}
	else {
		if (GetGpgMajorVersion() eq '2') {
			$gpgCommand = 'gpg2';
		}
		else {
			$gpgCommand = 'gpg';
		}
		#what a mess
	}
}
WriteLog("use_gpg2 = " . GetConfig('use_gpg2') . "; \$gpgCommand = $gpgCommand");

# my $gpgCommand;
# if (GetConfig('use_gpg2')) {
# 	$gpgCommand = 'gpg2 --no-default-keyring --keyring ./hike.gpg';
# } else {
# 	if (GetGpgMajorVersion() eq '2') {
# 		$gpgCommand = 'gpg2 --no-default-keyring --keyring ./hike.gpg';
# 	} else {
# 		$gpgCommand = 'gpg2 --no-default-keyring --keyring ./hike.gpg';
# 	}
# 	#what a mess
# }
# WriteLog("use_gpg2 = " . GetConfig('use_gpg2') . "; \$gpgCommand = $gpgCommand");

sub GetCache {
	my $cacheName = shift;
	chomp($cacheName);

	$cacheName = './cache/' . GetMyVersion() . '/' . $cacheName;

	return GetFile($cacheName);
}

sub EnsureSubdirs {
	my $fullPath = shift;

	my ( $file, $dirs ) = fileparse $fullPath;
	if ( !$file ) {
		return;
		$fullPath = File::Spec->catfile( $fullPath, $file );
	}

	if ( !-d $dirs ) {
		make_path $dirs or die "Failed to create path: $dirs";
	}
}

sub PutCache {
	my $cacheName = shift;
	chomp($cacheName);

	my $content = shift;
	chomp($content);

	$cacheName = './cache/' . GetMyVersion() . '/' . $cacheName;

	return PutFile($cacheName, $content);
}

sub UnlinkCache {
	my $cacheName = shift;
	chomp($cacheName);

	$cacheName = './cache/' . GetMyVersion() . '/' . $cacheName;

	if (-e $cacheName) {
		unlink($cacheName);
	}
}

sub CacheExists {
    my $cacheName = shift;
    chomp($cacheName);

    $cacheName = './cache/' . GetMyVersion() . '/' . $cacheName;

    if (-e $cacheName) {
        return 1;
    } else {
        return 0;
    }
}

sub GetGpgMajorVersion {
    state $gpgVersion;

    if ($gpgVersion) {
        return $gpgVersion;
    }

    $gpgVersion = `gpg --version`;
    WriteLog('GetGpgMajorVersion: gpgVersion = ' . $gpgVersion);

    $gpgVersion =~ s/\n.+//g;
    $gpgVersion =~ s/gpg \(GnuPG\) ([0-9]+).[0-9]+.[0-9]+/$1/;
    $gpgVersion =~ s/[^0-9]//g;

    return $gpgVersion;
}

sub GetMyVersion {
	state $myVersion;

	if ($myVersion) {
		return $myVersion;
	}

	$myVersion = `git rev-parse HEAD`;

	chomp($myVersion);

	return $myVersion;
}

# this is not needed, because we are not clearing out the html dir
#if (!-e "html/txt") {
#	system('ln -s "../txt" html/txt');
#}

####################################################################################
#

sub WriteConfigFromDatabase {
#	print("1");
#	my $query = "SELECT * FROM config_latest";
#
#	my $configSet = SqliteQuery2($query);
#
#	my @configSetArray = @{$configSet};
#
#	while (@configSetArray) {
#		my $configLineRef = shift @configSetArray;
#		my @configLine = @{$configLineRef};
#		WriteLog(Data::Dumper->Dump(@configLine));
##
##		my $configKey = shift @configSetArray;
##		my $configValue = shift @configSetArray;
##		my $configTimestamp = shift @configSetArray;
#
##		PutConfig($configKey, $configValue);
#	}
#
#	#print(Data::Dumper->Dump($configSet));
##
##	for my $config (@{$configSet}) {
##		WriteLog(Data::Dumper->Dump($config));
##	}
#	#die();
#
#	#todo finish this
#
#	#get
#
#	#write to config/
}

sub GetString {
	my $stringKey = shift;

	state %strings;

	if (!defined($strings{$stringKey})) {
		my $string = GetConfig('string/en/'.$stringKey);

		if ($string) {
    		chomp ($string);

	    	$strings{$stringKey} = $string;
        } else {
            return $stringKey;
        }
	}

	if (defined($strings{$stringKey})) {
		my @stringLines = split("\n", $strings{$stringKey});
		my $randomNumber = int(rand(@stringLines));
		my $randomLine = $stringLines[$randomNumber];

		return $randomLine;
		#return $strings{$stringKey};
	}
}


#sub GetString {
#	my $stringKey = shift;
#
#	state %strings;
#
#	if (!%strings) {
#		# get them from language/en
#
#		my $stringsFile = GetFile('language/en');
#
#		my @results = split("\n", $stringsFile);
#
#		foreach (@results) {
#			chomp;
#
#			my ($key, $value) = split(/\|/, $_);
#
#			$strings{$key} = $value;
#		}
#	}
#
#	if (defined($strings{$stringKey})) {
#		return $strings{$stringKey};
#	}
#}

sub GetFileHash {
	my $fileName = shift;

	my $gitOutput = `git hash-object -w "$fileName"`;
	#my $gitOutput = `sha1sum "$fileName" | cut -d ' ' -f 1`;

	chomp($gitOutput);

	return $gitOutput;
}

sub GetRandomHash {
	my @chars=('a'..'f','0'..'9');
	my $randomString;
	foreach (1..40) {
		$randomString.=$chars[rand @chars];
	}
	return $randomString;
}

# Gets template from template dir
# Should not fail
sub GetTemplate {
	my $filename = shift;
	chomp $filename;
	$filename = "$SCRIPTDIR/template/$filename";

	WriteLog("GetTemplate($filename)");

	state %templateCache;

	if ($templateCache{$filename}) {
		return $templateCache{$filename};
	}

	if (-e $filename) {
		my $template = GetFile($filename);
		$templateCache{$filename} = $template;
		return $template;
	} else {
		WriteLog("WARNING! GetTemplate() called with non-existing file $filename. Returning empty string.");
		return '';
	}
}

sub encode_entities2 {
	my $string = shift;
	if (!$string) {
		return;
	}

	WriteLog("encode_entities2($string)");

	$string =~ s/&/&amp;/g;
	$string =~ s/\</&lt;/g;
	$string =~ s/\>/&gt;/g;
	$string =~ s/"/&quot;/g;

	return $string;
}

sub GetHtmlAvatar {
# returns avatar suitable for comments
	my $key = shift;
	if (!$key) {
		return;
	}

	if (!IsFingerprint($key)) {
		return;
	}

	my $avatar = GetAvatar($key);
	if ($avatar) {
		if (-e 'html/author/' . $key) {
			my $avatarLink = GetAuthorLink($key);
			return $avatarLink;
		}
	} else {
		return $key;
	}

	return $key;
}

sub GetAvatar {
	state %avatarCache;

	my $gpg_key = shift;

	if (!$gpg_key) {
		return;
	}

	chomp $gpg_key;

	WriteLog("GetAvatar($gpg_key)");

	if ($avatarCache{$gpg_key}) {
		WriteLog("GetAvatar: found in hash");
		return $avatarCache{$gpg_key};
	}

	WriteLog("GetAvatar: continuing with cache lookup");

	my $avCacheFile = GetCache("avatar/$gpg_key");
	if ($avCacheFile) {
		return $avCacheFile;
	}

	my $avatar = GetTemplate('avatar.template');

	if ($gpg_key) {
		my $color1 = substr($gpg_key, 0, 6);
		my $color2 = substr($gpg_key, 3, 6);
		my $color3 = substr($gpg_key, 6, 6);
		my $color4 = substr($gpg_key, 9, 6);

		my $alias = GetAlias($gpg_key);
		$alias = encode_entities2($alias);
		#$alias = encode_entities($alias, '<>&"');

		if ($alias) {

	#		my $char1 = substr($gpg_key, 12, 1);
	#		my $char2 = substr($gpg_key, 13, 1);
	#		my $char3 = substr($gpg_key, 14, 1);
	#
	#		$char1 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;
	#		$char2 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;
	#		$char3 =~ tr/0123456789abcdefABCDEF/~@#$%^&*+=><|*+=><|}:+/;

			my $char1 = '*';
			my $char2 = '*';

			$avatar =~ s/\$color1/$color1/g;
			$avatar =~ s/\$color2/$color2/g;
			$avatar =~ s/\$color3/$color3/g;
			#$avatar =~ s/\$color4/$color4/g;
			$avatar =~ s/\$alias/$alias/g;
			$avatar =~ s/\$char1/$char1/g;
			$avatar =~ s/\$char2/$char2/g;
			#$avatar =~ s/\$char3/$char3/g;
		} else {
			$avatar = '';
		}
	} else {
		$avatar = "";
	}

	$avatarCache{$gpg_key} = $avatar;

	if ($avatar) {
		PutCache("avatar/$gpg_key", $avatar);
	}

	return $avatar;
}

sub GetAlias {
	#todo actually do a lookup

	my $gpgKey = shift;
	chomp $gpgKey;

	WriteLog("GetAlias($gpgKey)");

	my $alias = DBGetAuthorAlias($gpgKey);

	if ($alias) {
		$alias =~ s|<.+?>||g;
		trim($alias);
		chomp $alias;

		return $alias;
	} else {
		return $gpgKey;
	}
}

# Gets the contents of a file
sub GetFile {
	my $fileName = shift;

	if (!$fileName) {
		WriteLog('attempting GetFile() without $fileName');
		return;
	}

	my $length = shift || 209715200;
	# default to reading a max of 2MB of the file. #scaling

	if (-e $fileName && !-d $fileName && open (my $file, "<", $fileName)) {
		my $return;

		read ($file, $return, $length);

		return $return;
	}

	return;
}

sub GetConfig {
	my $configName = shift;
	chomp $configName;

#	if ($configName =~ /^[a-z0-9_]{1,32}$/) {
#		print("WARNING! GetConfig() sanity check failed!");
#		print("\$configName = $configName");
#		die();
#		return;
#	}
#
	state %configLookup;

	if ($configLookup{$configName}) {
		return $configLookup{$configName};
	}

	if (-e "config/$configName") {
		my $configValue = GetFile("config/$configName");
		$configValue = trim($configValue);
		$configLookup{$configValue} = $configValue;

		return $configValue;
	} else {
		if (-e "default/$configName") {
			my $configValue = GetFile("default/$configName");
			#$configValue = trim($configValue);
			$configLookup{$configName} = $configValue;
			PutConfig ($configName, $configValue);

			return $configValue;
		}
	}

	return;
}

sub ConfigKeyValid {
	my $configName = shift;

	if ($configName =~ /^[a-z0-9_]{1,32}$/) {
		WriteLog("WARNING! ConfigKeyValid() sanity check failed!");
	}

	if (-e "default/$configName") {
		return 1;
	} else {
		return 0;
	}
}

sub GetHtmlFilename {
	my $hash = shift;

	WriteLog("GetHtmlFilename()");

	if (!IsSha1($hash)) {
		WriteLog("Warning! GetHtmlFilename() called with parameter that isn't a SHA-1. Returning.");
		return;
	}

	#	my $htmlFilename =
	#		substr($hash, 0, 2) .
	#		'/' .
	#		substr($hash, 2, 8) .
	#		'.html';
	#
		my $htmlFilename =
			substr($hash, 0, 2) .
				'/' .
				substr($hash, 2, 2) .
				'/' .
				$hash .
				'.html';

	return $htmlFilename;
}

sub GetTitle {
	my $text = shift;

	if (!$text) {
		return;
	}

}

sub PutConfig {
	my $configName = shift;
	my $configValue = shift;

	chomp $configValue;

	return PutFile("config/$configName", $configValue);
}

# Writes to a file
sub PutFile {
	WriteLog("PutFile(...)");

	my $file = shift;

	if (!$file) {
		return;
	}

	EnsureSubdirs($file);

	WriteLog("PutFile($file, ...");



	my $content = shift;
	my $binMode = shift;

	if (!$content) {
		return;
	}
	if (!$binMode) {
		$binMode = 0;
	} else {
		$binMode = 1;
	}

	WriteLog("PutFile($file, (\$content), $binMode)");
	WriteLog("==== \$content ====");
	WriteLog($content);
	WriteLog("====");

	if (open (my $fileHandle, ">", $file)) {
		WriteLog("file handle opened.");
		if ($binMode) {
			binmode $fileHandle, ':utf8';
		}
		print $fileHandle $content;
		close $fileHandle;
	}
}

sub EpochToHuman {
	my $time = shift;

	return strftime('%F %T', localtime($time));
}

sub PutHtmlFile {
	my $file = shift;

	state $homePageWritten;
	if (!defined($homePageWritten)) {
		$homePageWritten = 0;
	}
	if ($file eq 'check_homepage') {
		return $homePageWritten;
	}

	my $content = shift;

	WriteLog("PutHtmlFile($file), \$content)");
	#WriteLog("===begin \$content===\n$content\n===");

	state $stripNonAscii;
	if (!defined($stripNonAscii)) {
		$stripNonAscii = GetConfig('ascii_only');
		if (!defined($stripNonAscii)) {
			$stripNonAscii = 0;
		}
		if ($stripNonAscii != 1) {
			$stripNonAscii = 0;
		}
	}

	if ($stripNonAscii == 1) {
		WriteLog( '$stripNonAscii == 1');
		$content =~ s/[^[:ascii:]]//g;
	}

	PutFile($file, $content);

	# this is a special hook for generating index.html, aka the home page
	# if the current file matches config/home_page, write index.html
	# change the title to home_title while at it
	if ($file eq GetConfig('home_page')) {
		my $homePageTitle = GetConfig('home_title');
		$content =~ s/\<title\>(.+)\<\/title\>/<title>$homePageTitle ($1)<\/title>/;
		PutFile ('html/index.html', $content);
		$homePageWritten = 1;
	}
}

sub GetFileAsHashKeys {
	my $fileName = shift;

	my @lines = split('\n', GetFile($fileName));

	my %hash;

	foreach my $line (@lines) {
		$hash{$line} = 0;
	}

	return %hash;
}


# Appends line to a file
sub AppendFile {
	my $file = shift;
	my $content = shift;

	if (open (my $fileHandle, ">>", $file)) {
		say $fileHandle $content;
		close $fileHandle;
	}
}

#Trims a string
sub trim {
	my $s = shift;

	if (defined($s)) {
		$s =~ s/^\s+|\s+$//g;
		$s =~ s/^\n+|\n+$//g;
		chomp $s;

		return $s;
	}
};

sub GetFileSizeHtml {
	my $fileSize = shift;
  
	if (!$fileSize) {
		return;
	}
	
	chomp ($fileSize);

	my $fileSizeString = $fileSize;

	if ($fileSizeString > 1024) {
		$fileSizeString = $fileSizeString / 1024;

		if ($fileSizeString > 1024) {
			$fileSizeString = $fileSizeString / 1024;

			if ($fileSizeString > 1024) {
				$fileSizeString = $fileSizeString / 1024;

				if ($fileSizeString > 1024) {
					$fileSizeString = $fileSizeString / 1024;

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="terabytes">TB</abbr>';
				} else {

					$fileSizeString = ceil($fileSizeString) . ' <abbr title="gigabytes">GB</abbr>';
				}
			} else {
				$fileSizeString = ceil($fileSizeString) . ' <abbr title="megabytes">MB</abbr>';
			}
		} else {
			$fileSizeString = ceil($fileSizeString) . ' <abbr title="kilobytes">KB</abbr>';
		}
	} else {
		$fileSizeString .= " bytes";
	}

	return $fileSizeString;
}

sub IsServer {
	my $key = shift;

	if (!IsFingerprint($key)) {
		return 0;
	}

	WriteLog("IsServer($key)");

	my $serverKey = GetServerKey();

	WriteLog("... \$serverKey = $serverKey");

	if ($serverKey eq $key) {
		WriteLog("... 1");
		return 1;
	} else {
		WriteLog("... 0");
		return 0;
	}
}

sub IsAdmin {
	my $key = shift;

	if (!IsFingerprint($key)) {
		return 0;
	}

#	my $adminKey = GetAdminKey();
#
#	if ($adminKey eq $key) {
	if ($key eq GetAdminKey() || $key eq GetServerKey()) {
		return 1;
	} else {
		return 0;
	}
}


sub GetServerKey {
	#Returns admin's key sig, 0 if there is none

	state $adminsKey = 0;

	if ($adminsKey) {
		return $adminsKey;
	}

	if (-e "html/txt/server.key.txt") {

		my %adminsInfo = GpgParse("html/txt/server.key.txt");

		if ($adminsInfo{'isSigned'}) {
			if ($adminsInfo{'key'}) {
				$adminsKey = $adminsInfo{'key'};

				return $adminsKey;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}

	return 0;
}

sub GetAdminKey {
	#Returns admin's key sig, 0 if there is none

	state $adminsKey = 0;

	if ($adminsKey) {
		return $adminsKey;
	}

	if (-e "$SCRIPTDIR/admin.key") {

		my %adminsInfo = GpgParse("$SCRIPTDIR/admin.key");

		if ($adminsInfo{'isSigned'}) {
			if ($adminsInfo{'key'}) {
				$adminsKey = $adminsInfo{'key'};

				return $adminsKey;
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}

	return 0;
}

# Trims the directories and the file extension from a file path
sub TrimPath {
	my $string = shift;

	while (index($string, "/") >= 0) {
		$string = substr($string, index($string, "/") + 1);
	}

	$string = substr($string, 0, index($string, ".") + 0);

	return $string;
}
#
sub GetGpgFingerprint {
	#gets the full gpg fingerprint from a public key in a text file

	my $file = shift;
	chomp $file;

	WriteLog( "gpg --with-colons --with-fingerprint \"$file\"\n");
	my @gpgResults = split("\n", `gpg --with-colons --with-fingerprint "$file"`);

	foreach my $line (@gpgResults) {
		if (substr($line, 0, 3) eq "fpr") {
			my $fingerprint = substr($line, 3);
			$fingerprint =~ s/://g;

			return $fingerprint;
		}
	}

	return;
}

sub HtmlEscape {
	my $text = shift;

	$text = encode_entities2($text);

	return $text;
}

sub IsSha1 {
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[a-fA-F0-9]{40}/) {
		return 1;
	} else {
		return 0;
	}
}

sub IsItem {
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[0-9a-f]{40}/) {
		return 1;
	} else {
		return 0;
	}
}

sub IsMd5 {
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[a-fA-F0-9]{32}/) {
		return 1;
	} else {
		return 0;
	}
}

sub IsFingerprint {
	my $string = shift;

	if (!$string) {
		return 0;
	}

	if ($string =~ m/[A-F0-9]{16}/) {
		return 1;
	} else {
		return 0;
	}
}

sub GpgParse {
	# GpgParse
	# $filePath = path to file containing the text
	#
	# $returnValues{'isSigned'} = whether the message has a valid signature: 0 or 1 for valid signature
	# $returnValues{'text'} = original text
	# $returnValues{'message'} = message text without framing
	# $returnValues{'key'} = fingerprint of signer
	# $returnValues{'alias'} = alias of signer, if they've added one by submitting their public key
	# $returnValues{'keyExpired'} = whether the key has expired: 0 for not expired, 1 for expired
	# $returnValues{'gitHash'} = git's hash of the file's contents
	# $returnValues{'fingerprint'} = full fingerprint of gpg key

	WriteLog("===BEGIN GPG PARSE===");
	WriteLog("===BEGIN GPG PARSE===");

	my $filePath = shift;

	my $txt = GetFile($filePath);

	my $message;

	my $isSigned = 0;

	my $gpg_key;

	my $fingerprint = '';

	my $alias = '';

	my $keyExpired = 0;

	my $gitHash = GetFileHash($filePath);

	my $cachePath;
	$cachePath = "./cache/" . GetMyVersion() . "/gpg/$gitHash.cache";

	my %returnValues;

	if (-e $cachePath) {
		WriteLog("GpgParse cache hit! $cachePath");

		%returnValues = %{retrieve($cachePath)};
	} else {
		# Signed messages begin with this header
		my $gpg_message_header = "-----BEGIN PGP SIGNED MESSAGE-----";

		# Public keys (that set the username) begin with this header
		my $gpg_pubkey_header = "-----BEGIN PGP PUBLIC KEY BLOCK-----";

		# Encrypted messages begin with this header
		my $gpg_encrypted_header = "-----BEGIN PGP MESSAGE-----";

		###########################################################################
		## Below where we check for a GPG signed message and sort it accordingly ##
		###########################################################################

		my $trimmedTxt = trim($txt);

		my $verifyError = 0;

		######################
		## ENCRYPTED MESSAGE
		##

		if (index($txt, $gpg_encrypted_header) != -1) {
			$message = "This is an encrypted message. Decryption is not yet supported by the web interface.";
		}

#		if (substr($trimmedTxt, 0, length($gpg_encrypted_header)) eq $gpg_encrypted_header) {
#			WriteLog("$gpgCommand --batch --list-only --status-fd 1 \"$filePath\"");
#			my $gpg_result = `$gpgCommand --batch --list-only --status-fd 1 "$filePath"`;
#			WriteLog($gpg_result);
#
#			foreach (split("\n", $gpg_result)) {
#				chomp;
#
#				my $key_id_prefix;
#				my $key_id_suffix;
#
#				if (index($gpg_result, "[GNUPG:] ENC_TO ") >= 0) {
#					$key_id_prefix = "[GNUPG:] ENC_TO ";
#					$key_id_suffix = " ";
#
#					if ($key_id_prefix) {
#						# Extract the key fingerprint from GPG's output.
#						$gpg_key = substr($gpg_result, index($gpg_result, $key_id_prefix) + length($key_id_prefix));
#						$gpg_key = substr($gpg_key, 0, index($gpg_key, $key_id_suffix));
#
#						$message = "Encrypted message for $gpg_key\n";
#
#						$isSigned = 1;
#
#					}
#				}
#			}
#		}

		###############
		## PUBLIC KEY
		##

		WriteLog("Looking for public key header...");

		if (substr($trimmedTxt, 0, length($gpg_pubkey_header)) eq $gpg_pubkey_header) {
			WriteLog("Found public key header!");

			WriteLog("$gpgCommand --keyid-format LONG \"$filePath\"");
			my $gpg_result = `$gpgCommand --keyid-format LONG "$filePath"`;
			WriteLog($gpg_result);

			WriteLog("$gpgCommand --import \"$filePath\"");
			my $gpgImportKeyResult = `$gpgCommand --import "$filePath"`;
			WriteLog($gpgImportKeyResult);

			#		WriteLog( "gpg --with-colons --with-fingerprint \"$file\"\n");
			#		my @gpgResults = split("\n", `gpg --with-colons --with-fingerprint "$file"`);
			#
			#		foreach my $line (@gpgResults) {
			#			if (substr($line, 0, 3) eq "fpr") {
			#				my $fingerprint = substr($line, 3);
			#				$fingerprint =~ s/://g;
			#
			#				return $fingerprint;
			#			}
			#		}
			#
			#		return;

			foreach (split("\n", $gpg_result)) {

				chomp;
				WriteLog("Looking for returned alias in $_");

				# gpg 1
				if ($gpgCommand eq 'gpg' || !GetConfig('use_gpg2')) {
					WriteLog('$gpgCommand is gpg');

					if (substr($_, 0, 4) eq 'pub ') {
						my @split = split(" ", $_, 4);
						$alias = $split[3];
						$gpg_key = $split[1];

						@split = split("/", $gpg_key);
						$gpg_key = $split[1];

						$alias =~ s|<.+?>||g;
						$alias =~ s/^\s+//;
						$alias =~ s/\s+$//;
					}
				}

				# gpg 2
				elsif ($gpgCommand eq 'gpg2' || GetConfig('use_gpg2')) {
					WriteLog('$gpgCommand is gpg2');
					WriteLog('@@' . $_);
					if (substr($_, 0, 4) eq 'uid ') {
						WriteLog('gpg2 ; uid hit');
						my @split = split(" ", $_, 4);
						$alias = $split[1];

						$alias =~ s|<.+?>||g;
						$alias =~ s/^\s+//;
						$alias =~ s/\s+$//;

						WriteLog('$alias = ' . $alias);
					}
					if (substr($_, 0, 4) eq 'pub ') {
						WriteLog('gpg2 ; pub hit');
						my @split = split(" ", $_, 4);
						$gpg_key = $split[1];

						@split = split("/", $gpg_key);
						$gpg_key = $split[1];

						WriteLog('$gpg_key = ' . $gpg_key);
					}
				}
			}

			# Public key confirmed, tell 'em
			if ($alias && $gpg_key) {
				$message = "Welcome, $alias\nFingerprint: $gpg_key";
			}

			$isSigned = 1;
		}

		#######################
		## GPG SIGNED MESSAGE
		##
		if (substr($trimmedTxt, 0, length($gpg_message_header)) eq $gpg_message_header) {
			# Verify the file by using command-line gpg
			# --status-fd 1 makes gpg output to STDOUT using a more concise syntax
			WriteLog("$gpgCommand --verify --status-fd 1 \"$filePath\"\n");
			my $gpg_result = `$gpgCommand --verify --status-fd 1 "$filePath"`;
			WriteLog($gpg_result);

			my $key_id_prefix;
			my $key_id_suffix;

			if (index($gpg_result, "[GNUPG:] BADSIG") >= 0 || index($gpg_result, "[GNUPG:] ERRSIG") >= 0 || index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
				#			$key_id_prefix = 0;
				#			$key_id_suffix = 0;
				#%returnValues{'sigError'} = 1;
				WriteLog("Decoding error detected!!!!1");
				$verifyError = 1;

			}
			else {
				#			if (index($gpg_result, "[GNUPG:] NO_PUBKEY ") >= 0) {
				#				$key_id_prefix = "[GNUPG:] NO_PUBKEY ";
				#				$key_id_suffix = "\n";
				#			}

				if (index($gpg_result, "[GNUPG:] GOODSIG ") >= 0) {
					$key_id_prefix = "[GNUPG:] GOODSIG ";
					$key_id_suffix = " ";
				}

				if (index($gpg_result, "[GNUPG:] EXPKEYSIG ") >= 0) {
					$key_id_prefix = "[GNUPG:] EXPKEYSIG ";
					$key_id_suffix = " ";

					$keyExpired = 1;
				}
			}

			if ($key_id_prefix) {
				# Extract the key fingerprint from GPG's output.
				$gpg_key = substr($gpg_result, index($gpg_result, $key_id_prefix) + length($key_id_prefix));
				$gpg_key = substr($gpg_key, 0, index($gpg_key, $key_id_suffix));

				WriteLog("$gpgCommand --decrypt \"$filePath\"\n");
				$message = `$gpgCommand --decrypt "$filePath"`;

				$isSigned = 1;

				#$fingerprint = GetGpgFingerprint($filePath); #todo
			}

			if (!$isSigned) {
				WriteLog("Decoding signed message fallthrough!!!1 Setting \$verifyError = 1");
				$verifyError = 1;
			}
		}

		if (!$isSigned) {
			$message = $txt;
		}

		$returnValues{'isSigned'} = $isSigned;
		$returnValues{'text'} = $txt;
		$returnValues{'message'} = $message;
		$returnValues{'key'} = $gpg_key;
		$returnValues{'alias'} = $alias;
		$returnValues{'keyExpired'} = $keyExpired;
		$returnValues{'gitHash'} = $gitHash;
		$returnValues{'fingerprint'} = $fingerprint;
		$returnValues{'verifyError'} = $verifyError;

		store \%returnValues, $cachePath;
	}

	WriteLog("GpgParse success! $cachePath");

	WriteLog("===END GPG PARSE===");
	WriteLog("===END GPG PARSE===");

	return %returnValues;
}

sub EncryptMessage {
	my $targetKey = shift;
	# file path
	chomp($targetKey);

	#todo
}

sub AddItemToConfigList {
	my $configList = shift;
	chomp($configList);

	my $item = shift;
	chomp($item);

	my $myHosts = GetConfig($configList);

	if ($myHosts) {

		my @hostsArray = split("\n", $myHosts);

		foreach my $h (@hostsArray) {
			if ($h eq $item) {
				return;
			}
		}

		$myHosts .= "\n";
		$myHosts .= $item;
		$myHosts = trim($myHosts);
		$myHosts .= "\n";
	} else {
		$myHosts = $item . "\n";
	}

	$myHosts =~ s/\n\n/\n/g;

	PutConfig($configList, $myHosts);
}

sub FormatForWeb {
	my $text = shift;

	if (!$text) {
		return '';
	}

	$text = HtmlEscape($text);
	$text =~ s/\n /<br>&nbsp;/g;
	$text =~ s/^ /&nbsp;/g;
	$text =~ s/  / &nbsp;/g;
	$text =~ s/\n/<br>\n/g;

	#htmlspecialchars(
	## nl2br(
	## str_replace(
	## '  ', ' &nbsp;',
	# htmlspecialchars(
	## $quote->quote))))?><? if ($quote->comment) echo(htmlspecialchars('<br><i>Comment:</i> '.htmlspecialchars($quote->comment)
	#));?><?=$tt_c?></description>



	return $text;
}

sub WriteLog {
	#todo sanitize?
	my $text = shift;

	if (!$text) {
		$text = '(empty string)';
	}

	chomp $text;

	my $timestamp = time();

	if (-e "config/debug" && GetConfig("debug") && GetConfig("debug") == 1) {
		AppendFile("log/log.log", $timestamp . " " . $text);
		print $timestamp . " " . $text . "\n";
	}
}


my $lastVersion = GetConfig('current_version');
my $currVersion = GetMyVersion();

if ($lastVersion ne $currVersion) {
	WriteLog("$lastVersion ne $currVersion, posting changelog");

	#my $serverKey = `gpg --list-keys hikeserver`;

	#WriteLog("gpg --list-keys CCEA3752");
	#WriteLog($serverKey);

	my $changeLogFilename = 'changelog_' . time() . '.txt';
	my $changeLogMessage = 'Installed software version has changed from ' . $lastVersion . ' to ' . $currVersion;

	my $changeLogList = `git log --oneline $lastVersion..$currVersion`;
	$changeLogMessage .= "\n\n$changeLogList";

	PutFile("html/txt/$changeLogFilename", $changeLogMessage);

	ServerSign("html/txt/$changeLogFilename");

	PutConfig('current_version', $currVersion);
}

my $lastAdmin = GetConfig('current_admin');
my $currAdmin = GetAdminKey();

if (!$lastAdmin) {
	$lastAdmin = 0;
}

if ($currAdmin) {
	if ($lastAdmin ne $currAdmin) {
		WriteLog("$lastAdmin ne $currAdmin, posting change-admin");

		my $changeAdminFilename = 'changeadmin_' . time() . '.txt';
		my $changeAdminMessage = 'Admin has changed from ' . $lastAdmin . ' to ' . $currAdmin;

		PutFile("html/txt/$changeAdminFilename", $changeAdminMessage);

		ServerSign("html/txt/$changeAdminFilename");

		PutConfig("current_admin", $currAdmin);
	}
}

sub ServerSign {
# Signs a given file with the server's key, if it exists
# Replaces file with signed version
	my $file = shift;

	if (!-e $file) {
		return;
	}

	my $serverKeyId = trim(GetConfig('server_key_id'));

	if (!$serverKeyId) {
		return;
	}

	# verify that key exists in gpg keychain
	WriteLog("gpg --list-keys $serverKeyId");
	my $serverKey = `gpg --list-keys $serverKeyId`;
	WriteLog($serverKey);

	# if public key has not been published yet, do it
	if (!-e "html/txt/server.key") {
		WriteLog("gpg --batch --yes --armor --export $serverKeyId > html/txt/server.key.txt");
		my $gpgOutput = `gpg --batch --yes --armor --export $serverKeyId > html/txt/server.key.txt`;
		WriteLog($gpgOutput);
	}

	if ($serverKey) {
		WriteLog("We have a server key, so go ahead and sign the changelog.");

		WriteLog("gpg --batch --yes --default-key $serverKeyId --clearsign \"$file\"");
		system("gpg --batch --yes --default-key $serverKeyId --clearsign \"$file\"");

		if (-e "$file.asc") {
			WriteLog("Sign appears successful, rename .asc file to .txt");
			rename("$file.asc", "$file");
		} else {
			WriteLog("Tried to sign, but no .asc file. PROBLEM!!!");
		}
	} else {
		#$changeLogMessage .= "\n\n(No server key found, not signing.)";
		WriteLog("No server key found, will not sign changelog.");
	}
}

sub DeleteFile {
	my $fileHash = shift;

	if ($fileHash) {
	}
}

1;
