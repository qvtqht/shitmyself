#!/usr/bin/perl

use strict;
use 5.010;
use utf8;
#use warnings FATAL => 'all';

require './utils.pl';

sub GetYes { # $message, $defaultYes ; print $message, and get Y response from the user
	# $message is printed to output
	# $defaultYes true:  allows pressing enter
	# $defaultYes false: user must type Y or y

	my $message = shift;
	chomp $message;

	my $defaultYes = shift;
	chomp $defaultYes;

	print $message;
	if ($defaultYes) {
		print ' [Y] ';
	} else {
		print " Enter 'Y' to proceed: ";
	}

	my $input = <STDIN>;
	chomp $input;

	if ($input eq 'Y' || $input eq 'y' || ($defaultYes && $input eq '')) {
		print "====================================================\n";
		print "====== Thank you for your vote of confidence! ======\n";
		print "====================================================\n";

		return 1;
	}
	return 0;
}

if (!GetConfig('admin/lighttpd/enable')) {
	if (GetConfig('admin/dev/dont_confirm') || GetYes('admin/lighttpd/enable is false, set to true?', 1)) {
		PutConfig('admin/lighttpd/enable', 1);
	}
}

if (!GetConfig('admin/dev/dont_confirm') || GetYes('kill existing lighttpd process?', 1)) {
	`killall lighttpd`;
}

sub StartLighttpd {
	if (!-e './log') {
		mkdir('./log');
	}

#	my $pathLighttpd = `which lighttpd`;
	my $pathLighttpd = '/usr/sbin/lighttpd';
	WriteLog('$pathLighttpd = ' . $pathLighttpd);

	if ($pathLighttpd =~ m/^([^\s]+)$/) {
		$pathLighttpd = $1;
		system("$pathLighttpd -D -f config/lighttpd.conf");
	} else {
		WriteMessage('lighttpd path missing or failed sanity check');
	}
}

sub GetLighttpdConfig {
	my $conf = GetTemplate('lighttpd/lighttpd.conf.template');
	print $conf;

#	my $pwd = `pwd`;
	my $pwd = cwd();
	chomp $pwd; # get rid of tailing newline

	my $docRoot = $pwd . '/' . 'html' . '/';
	my $serverPort = GetConfig('admin/lighttpd/port') || 2784;
	my $errorFilePrefix = $docRoot . 'error/error-';

	$conf =~ s/\$serverDocumentRoot/$docRoot/;
	$conf =~ s/\$serverPort/$serverPort/;
	$conf =~ s/\$errorFilePrefix/$errorFilePrefix/;

	if (GetConfig('admin/php/enable')) {
		my $phpConf = GetTemplate('lighttpd/lighttpd_php.conf.template');

		my $phpCgiPath = `which php-cgi`;
        chomp($phpCgiPath);

		if ($phpCgiPath) {
    		$phpConf =~ s/\/bin\/php-cgi/$phpCgiPath/g;
        } else {
            WriteLog('GetLighttpdConfig: warning: php enabled with lighttpd, but php-cgi missing');
        }

		WriteLog('$phpConf beg =====');
		WriteLog($phpConf);
		WriteLog('$phpConf end =====');

		$conf .= "\n" . $phpConf;

		my $rewriteSetting = GetConfig('admin/php/rewrite');
		if ($rewriteSetting) {
			if ($rewriteSetting eq 'all') {
				my $phpRewriteAllConf = GetTemplate('lighttpd/lighttpd_php_rewrite_all.conf.template');
				$conf .= "\n" . $phpRewriteAllConf;
			}
			if ($rewriteSetting eq 'query') {
				my $phpRewriteQueryConf = GetTemplate('lighttpd/lighttpd_php_rewrite_query.conf.template');
				$conf .= "\n" . $phpRewriteQueryConf;
			}
		}
	}

	if (GetConfig('admin/ssi/enable')) {
		my $ssiConf = GetTemplate('lighttpd/lighttpd_ssi.conf.template');

		WriteLog('$ssiConf beg =====');
		WriteLog($ssiConf);
		WriteLog('$ssiConf end =====');

		$conf .= "\n" . $ssiConf;
	}
	if (GetConfig('admin/http_auth/enable')) {
		my $basicAuthConf = GetTemplate('lighttpd/lighttpd_basic_auth.conf.template');

		WriteLog('$basicAuthConf beg =====');
		WriteLog($basicAuthConf);
		WriteLog('$basicAuthConf end =====');

		$conf .= "\n" . $basicAuthConf;
	}

	return $conf;
} # GetLighttpdConfig()

if (GetConfig('admin/lighttpd/enable')) {
	WriteMessage("admin/lighttpd/enable was true");
	my $lighttpdConf = GetLighttpdConfig();

	WriteLog('===== beg $lighttpdConf =====');
	WriteLog($lighttpdConf);
	WriteLog('===== end $lighttpdConf =====');

	WriteMessage('PutFile(\'config/lighttpd.conf\', $lighttpdConf);');
	PutFile('config/lighttpd.conf', $lighttpdConf);

	if (GetConfig('admin/http_auth/enable')) {
		my $basicAuthUserFile = GetTemplate('lighttpd/lighttpd_password.template');
		PutFile('config/lighttpd_password.conf', $basicAuthUserFile);

		my $htpasswdAuthUserFile = GetConfig('admin/http_auth/htpasswd');
		PutFile('config/lighttpd_htpasswd.conf', $htpasswdAuthUserFile);
	}

	StartLighttpd();
} else {
	WriteMessage("admin/lighttpd/enable was false");
}

1;
