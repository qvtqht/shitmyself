#!/usr/bin/perl -T

use strict;
use 5.010;
use utf8;

require('./utils.pl');

sub GetConfig { # $configName || 'unmemo', $token, [$parameter] ;  gets configuration value based for $key
	# $token eq 'unmemo'
	#    removes it from %configLookup
	# $token eq 'override'
	# 	instead of regular lookup, overrides value
	#		overridden value is stored in local sub memo
	#			this means all subsequent lookups now return $parameter
	#
#	this is janky, and doesn't work as expected
#	eventually, it will be nice for dev mode to not rewrite
#	the entire config tree on every rebuild
#	and also not require a rebuild after a default change
#	#todo

	my $configName = shift;
	chomp $configName;

	WriteLog("GetConfig($configName)");

	#	if ($configName =~ /^[a-z0-9_\/]{1,255}$/) {
	#		WriteLog("GetConfig: warning: Sanity check failed!");
	#		WriteLog("\$configName = $configName");
	#		return;
	#	}
	#
	state %configLookup;

	if ($configName && $configName eq 'unmemo') {
		undef %configLookup;
		return '';
	}

	my $token = shift;
	if ($token) {
		chomp $token;
	}

	if ($token && $token eq 'unmemo') {
		WriteLog('GetConfig: unmemo requested, complying');
		# unmemo token to remove memoized value
		if (exists($configLookup{$configName})) {
			delete($configLookup{$configName});
		}
	}

	if ($token && $token eq 'override') {
		my $parameter = shift;
		if ($parameter) {
			$configLookup{$configName} = $parameter;
		} else {
			WriteLog('GetConfig: warning: $token was override, but no parameter. sanity check failed.');
			return '';
		}
	}

	if (exists($configLookup{$configName})) {
		# found in memo
		WriteLog('GetConfig: $configLookup already contains value, returning that...');
		WriteLog('GetConfig: $configLookup{$configName} is ' . $configLookup{$configName});
		return $configLookup{$configName};
	}

	WriteLog("GetConfig: Looking for config value in config/$configName ...");

	my $acceptableValues;
	if ($configName eq 'html/clock_format') {
		if (substr($configName, -5) ne '.list') {
			my $configList = GetConfig("$configName.list");
			if ($configList) {
				$acceptableValues = $configList;
			}
		}
	} else {
		$acceptableValues = 0;
	}

	if (-d "config/$configName") {
		WriteLog('GetConfig: warning: $configName was a directory, returning');
		return;
	}

	if (-e "config/$configName") {
		# found a match in config directory
		WriteLog("GetConfig: -e config/$configName returned true, proceeding to GetFile(), set \$configLookup{}, and return \$configValue");
		my $configValue = GetFile("config/$configName");
		if (substr($configName, 0, 9) eq 'template/') {
			# do not trim templates
		} else {
			# trim() resulting value (removes whitespace)
			$configValue = trim($configValue);
		}
		$configLookup{$configValue} = $configValue;
		if ($acceptableValues) {
			# there is a list of acceptable values
			# check to see if value is in that list
			# if not, issue warning and return 0
			if (index($configValue, $acceptableValues)) {
				return $configValue;
			} else {
				WriteLog('GetConfig: warning: $configValue was not in $acceptableValues');
				return 0; #todo should return default, perhaps via $param='default'
			}
		} else {
			return $configValue;
		}
	} # found in config/
	else {
		WriteLog("GetConfig: -e config/$configName returned false, looking in defaults...");

		if (-e "default/$configName") {
			# found default, return that
			WriteLog("GetConfig: -e default/$configName returned true, proceeding to GetFile(), etc...");
			my $configValue = GetFile("default/$configName");
			$configValue = trim($configValue);
			$configLookup{$configName} = $configValue;

			if (!GetConfig('admin/dev/skip_putconfig')) {
				# this preserves default settings, so that even if defaults change in the future
				# the same value will remain for current instance
				# this also saves much time not having to run ./clean_dev when developing
				WriteLog('GetConfig: calling PutConfig(' . $configName . ', ' . $configValue .');');
				PutConfig($configName, $configValue);
			} else {
				WriteLog('GetConfig: skip_putconfig is TRUE, not calling PutConfig()');
			}

			return $configValue;
		} # return default/
		else {
			WriteLog("GetConfig: warning: Tried to get undefined config with no default: $configName");
			return;
		}
	} # not found in config/

	WriteLog('GetConfig: warning: reached end of function, which should not happen');
	return;
} # GetConfig()

sub ConfigKeyValid { #checks whether a config key is valid
	# valid means passes character sanitize
	# and exists in default/
	my $configName = shift;

	if (!$configName) {
		WriteLog('ConfigKeyValid: warning: $configName parameter missing');
		return 0;
	}

	WriteLog("ConfigKeyValid($configName)");

	if (! ($configName =~ /^[a-z0-9_\/]{1,64}$/) ) {
		WriteLog("ConfigKeyValid: warning: sanity check failed!");
		return 0;
	}

	WriteLog('ConfigKeyValid: $configName sanity check passed:');

	if (-e "default/$configName") {
		WriteLog("ConfigKeyValid: default/$configName exists, return 1");
		return 1;
	} else {
		WriteLog("ConfigKeyValid: default/$configName NOT exist, return 0");
		return 0;
	}
} # ConfigKeyValid()


sub ResetConfig { # Resets $configName to default by removing the config/* file
	# Does a ConfigKeyValid() sanity check first
	my $configName = shift;

	if (ConfigKeyValid($configName)) {
		unlink("config/$configName");
	}
}

sub PutConfig { # $configName, $configValue ; writes config value to config storage
	# $configName = config name/key (file path)
	# $configValue = value to write for key
	# Uses PutFile()
	#
	my $configName = shift;
	my $configValue = shift;

	WriteLog("PutConfig($configName, $configValue)");

	if (index($configName, '..') != -1) {
		WriteLog('PutConfig: warning: sanity check failed: $configName contains ".."');
		WriteLog('PutConfig: warning: sanity check failed: $configName contains ".."');
		return '';
	}

	chomp $configValue;

	my $putFileResult = PutFile("config/$configName", $configValue);

	# ask GetConfig() to remove memo-ized value it stores inside
	GetConfig($configName, 'unmemo');

	return $putFileResult;
} # PutConfig()

if (0) { #tests
	print GetConfig('current_version');
}

1;
