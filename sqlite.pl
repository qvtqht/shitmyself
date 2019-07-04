#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBD::SQLite;
use DBI;
use Data::Dumper;
use 5.010;

my $SqliteDbName = './cache/' . GetMyVersion() . '/index.sqlite3';
my $dbh;

require './utils.pl';

sub SqliteConnect {
	$dbh = DBI->connect(
		"dbi:SQLite:dbname=$SqliteDbName",
		"",
		"",
		{ RaiseError => 1, AutoCommit => 1 },
	) or die $DBI::errstr;
}
SqliteConnect();

sub SqliteUnlinkDb {
	if ($dbh) {
		$dbh->disconnect();
	}
	rename($SqliteDbName, "$SqliteDbName.prev");
	SqliteConnect();
}

#schema
sub SqliteMakeTables() {

	# added_time
	SqliteQuery2("CREATE TABLE added_time(file_hash, add_timestamp INTEGER);");
	SqliteQuery2("CREATE UNIQUE INDEX added_time_unique ON added_time(file_hash);");


	# added_by (client)
	SqliteQuery2("CREATE TABLE added_by(file_hash, device_fingerprint);");

	# author
	SqliteQuery2("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE, published)");

	# author_alias
	SqliteQuery2("CREATE TABLE author_alias(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		is_admin,
		fingerprint
	)");

	# vote_weight
	SqliteQuery2("CREATE TABLE vote_weight(key, vote_weight)");

	# item
	SqliteQuery2("CREATE TABLE item(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_path UNIQUE,
		item_name,
		author_key,
		file_hash UNIQUE,
		item_type
	)");

	# item_title
	SqliteQuery2("CREATE TABLE item_title(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_hash UNIQUE,
		title
	)");

	# item_parent
	SqliteQuery2("CREATE TABLE item_parent(item_hash, parent_hash)");
	SqliteQuery2("CREATE UNIQUE INDEX item_parent_unique ON item_parent(item_hash, parent_hash)");

	# child_count view
	SqliteQuery2("
		CREATE VIEW child_count AS
		SELECT
			parent_hash AS parent_hash,
			COUNT(*) AS child_count
		FROM
			item_parent
		GROUP BY
			parent_hash
	");

#	# tag
#	SqliteQuery2("CREATE TABLE tag(id INTEGER PRIMARY KEY AUTOINCREMENT, vote_value)");
#	SqliteQuery2("CREATE UNIQUE INDEX tag_unique ON tag(vote_value);");

	# vote
	SqliteQuery2("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, signed_by)");
	SqliteQuery2("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value, signed_by);");

	# item_page
	SqliteQuery2("CREATE TABLE item_page(item_hash, page_type, page_param)");
	SqliteQuery2("CREATE UNIQUE INDEX item_page_unique ON item_page(item_hash, page_type, page_param)");

	#SqliteQuery2("CREATE TABLE item_type(item_hash, type_mask)");

	# event
	SqliteQuery2("CREATE TABLE event(id INTEGER PRIMARY KEY AUTOINCREMENT, item_hash, author_key, event_time, event_duration)");

	# page_touch
	SqliteQuery2("CREATE TABLE page_touch(id INTEGER PRIMARY KEY AUTOINCREMENT, page_name, page_param, touch_time INTEGER)");
	SqliteQuery2("CREATE UNIQUE INDEX page_touch_unique ON page_touch(page_name, page_param)");

	# config
	SqliteQuery2("CREATE TABLE config(key, value, timestamp, reset_flag, source_item)");
	SqliteQuery2("CREATE UNIQUE INDEX config_unique ON config(key, value, timestamp, reset_flag)");
	SqliteQuery2("
		CREATE VIEW config_latest AS
		SELECT key, value, MAX(timestamp) config_timestamp, reset_flag, source_item FROM config GROUP BY key ORDER BY timestamp DESC
	");


#	SqliteQuery2("CREATE TABLE type(type_mask, type_name)");
#	#todo currently unpopulated
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(1, 'text');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(2, 'reply');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(4, 'vote');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(8, 'pubkey');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(16, 'decode_error');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(32, 'image');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(64, 'video');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(128, 'event');");
#	SqliteQuery2("INSERT INTO type(type_mask, type_name) VALUES(256, 'markdown');");


	# parent_count view
	SqliteQuery2("
		CREATE VIEW parent_count AS
		SELECT
			item_hash AS item_hash,
			COUNT(*) AS parent_count
		FROM
			item_parent
		GROUP BY
			item_hash
	");

	SqliteQuery2("CREATE VIEW item_last_bump AS SELECT file_hash, MAX(add_timestamp) add_timestamp FROM added_time GROUP BY file_hash;");


#	SqliteQuery2("
#		CREATE VIEW added_time2 AS
#			SELECT
#
#
#	;");

	SqliteQuery2("
		CREATE VIEW vote_weighed AS
			SELECT
				vote.file_hash,
				vote.ballot_time,
				vote.vote_value,
				vote.signed_by,
				sum(ifnull(vote_weight.vote_weight, 1)) vote_weight
			FROM
				vote
				LEFT JOIN vote_weight ON (vote.signed_by = vote_weight.key)
			GROUP BY
				vote.file_hash,
				vote.ballot_time,
				vote.vote_value,
				vote.signed_by
	");

	SqliteQuery2("
		CREATE VIEW item_flat AS
			SELECT
				item.file_path AS file_path,
				item.item_name AS item_name,
				item.file_hash AS file_hash,
				item.author_key AS author_key,
				IFNULL(child_count.child_count, 0) AS child_count,
				IFNULL(parent_count.parent_count, 0) AS parent_count,
				added_time.add_timestamp AS add_timestamp,
				IFNULL(item_title.title, '') AS item_title,
				IFNULL(item_score.item_score, 0) AS item_score,
				item.item_type AS item_type
			FROM
				item
				LEFT JOIN child_count ON ( item.file_hash = child_count.parent_hash)
				LEFT JOIN parent_count ON ( item.file_hash = parent_count.item_hash)
				LEFT JOIN added_time ON ( item.file_hash = added_time.file_hash)
				LEFT JOIN item_title ON ( item.file_hash = item_title.file_hash)
				LEFT JOIN item_score ON ( item.file_hash = item_score.file_hash)
	");
	SqliteQuery2("
		CREATE VIEW event_future AS
			SELECT
				*
			FROM
				event
			WHERE
				event.event_time > strftime('%s','now');
	");
#	SqliteQuery2("
#		CREATE VIEW event_future AS
#			SELECT
#				event.item_hash AS item_hash,
#				event.event_time AS event_time,
#				event.event_duration AS event_duration
#			FROM
#				event
#			WHERE
#				event.event_time > strftime('%s','now');
#	");
	SqliteQuery2("
		CREATE VIEW item_vote_count AS
			SELECT
				file_hash,
				vote_value AS vote_value,
				COUNT(file_hash) AS vote_count
			FROM vote
			GROUP BY file_hash, vote_value
			ORDER BY vote_count DESC
	");

	SqliteQuery2("
		CREATE VIEW 
			author_flat 
		AS 
		SELECT 
			author.key AS author_key, 
			SUM(vote_weight.vote_weight) AS vote_weight, 
			author_alias.alias AS author_alias,
			IFNULL(author_score.author_score, 0) AS author_score
		FROM
			author 
			LEFT JOIN vote_weight
				ON (author.key = vote_weight.key)
			LEFT JOIN author_alias
				ON (author.key = author_alias.key)
			LEFT JOIN author_score
				ON (author.key = author_score.author_key)
		GROUP BY
			author.key, author_alias.alias
	");



	SqliteQuery2("
		CREATE VIEW
			item_score
		AS
			SELECT
				item.file_hash AS file_hash,
				COUNT(vote.vote_value) AS item_score
			FROM
				vote
				LEFT JOIN item
					ON (vote.file_hash = item.file_hash)
			GROUP BY
				item.file_hash

	");


	SqliteQuery2("
		CREATE VIEW
			author_score
		AS
			SELECT
				item_flat.author_key AS author_key,
				SUM(item_flat.item_score) AS author_score
			FROM
				item_flat
			GROUP BY
				item_flat.author_key

	");
}

sub SqliteQuery2 {
#params: $query, @queryParams
#returns array ref
	my $query = shift;
	chomp $query;

	if ($query) {
		WriteLog($query);

		my $sth = $dbh->prepare($query);
		$sth->execute(@_);

		my $aref = $sth->fetchall_arrayref();

		$sth->finish();

		return $aref;
	}
}

sub EscapeShellChars {
	my $string = shift;
	chomp $string;

	$string =~ s/([\"|\$`\\])/\\$1/g;
	# " | $ ` \

	return $string;
}

# sub SqliteQuery {
# 	my $query = shift;
#
# 	if (!$query) {
# 		WriteLog("SqliteQuery called without query");
#
# 		return;
# 	}
#
# 	chomp $query;
#
# 	$query = EscapeShellChars($query);
#
# 	WriteLog( "$query\n");
#
# 	my $results = `sqlite3 "$SqliteDbName" "$query"`;
#
# 	return $results;
# }

#
#sub DBGetVotesTable {
#	my $fileHash = shift;
#
#	if (!IsSha1($fileHash) && $fileHash) {
#		WriteLog("DBGetVotesTable called with invalid parameter! returning");
#		WriteLog("$fileHash");
#		return '';
#	}
#
#	my $query;
#	my @queryParams = ();
#
#	if ($fileHash) {
#		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed WHERE file_hash = ?;";
#		@queryParams = ($fileHash);
#	} else {
#		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed;";
#	}
#
#	my $result = SqliteQuery2($query, @queryParams);
#
#	return $result;
#}

sub DBGetVotesForItem {
	my $fileHash = shift;

	if (!IsSha1($fileHash)) {
		WriteLog("DBGetVotesTable called with invalid parameter! returning");
		WriteLog("$fileHash");
		return '';
	}

	my $query;
	my @queryParams;

	$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed WHERE file_hash = ?;";
	@queryParams = ($fileHash);

	my $result = SqliteQuery2($query, @queryParams);

	return $result;
}

sub DBGetEventsAfter {
	my $time = shift;

	if (!$time) {
		$time = time();
	}

	my $query;
	my @queryParams;

	$query = "SELECT * FROM event WHERE (event_time + event_duration) > ?";
	@queryParams = ($time);

	my $result = SqliteQuery2($query, @queryParams);

	return $result;

}

sub DBGetLatestConfig {
	my $query = "SELECT * FROM config_latest";
	#todo write out the fields

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}


#sub SqliteGetHash {
#	my $query = shift;
#	chomp $query;
#
#	my @results = split("\n", SqliteQuery($query));
#
#	my %hash;
#
#	foreach (@results) {
#		chomp;
#
#		my ($key, $value) = split(/\|/, $_);
#
#		$hash{$key} = $value;
#	}
#
#	return %hash;
#}

sub SqliteGetValue {
	my $query = shift;
	chomp $query;

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @aref = $sth->fetchrow_array();

	$sth->finish();

	return $aref[0];
}

sub DBGetAuthorCount {
	my $whereClause = shift;

	my $authorCount;
	if ($whereClause) {
		$authorCount = SqliteGetValue("SELECT COUNT(*) FROM author_flat WHERE $whereClause");
	} else {
		$authorCount = SqliteGetValue("SELECT COUNT(*) FROM author_flat");
	}
	chomp($authorCount);

	return $authorCount;

}

sub DBGetItemCount {
	my $whereClause = shift;

	my $itemCount;
	if ($whereClause) {
		$itemCount = SqliteGetValue("SELECT COUNT(*) FROM item_flat WHERE $whereClause");
	} else {
		$itemCount = SqliteGetValue("SELECT COUNT(*) FROM item_flat");
	}
	chomp($itemCount);

	return $itemCount;
}

sub DBGetReplyCount {
	my $parentHash = shift;

	if (!IsSha1($parentHash)) {
		WriteLog('WARNING: DBGetReplyCount() called with invalid parameter');
	}

	my $itemCount = SqliteGetValue("SELECT COUNT(*) FROM item_parent WHERE parent_hash = '$parentHash'");
	chomp($itemCount);

	return $itemCount;
}

sub DBGetItemParents {
	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemParents called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_child WHERE item_hash = '$itemHash')";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp"; #todo this should be by timestamp

	return DBGetItemList(\%queryParams);
}

sub DBGetItemReplies {
	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemReplies called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash')";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp"; #todo this should be by timestamp

	return DBGetItemList(\%queryParams);
}

sub SqliteEscape {
	my $text = shift;

	if (defined $text) {
		$text =~ s/'/''/g;
	} else {
		$text = '';
	}

	return $text;
}

#sub SqliteAddKeyValue {
#	my $table = shift;
#	my $key = shift;
#	my $value = shift;
#
#	$table = SqliteEscape ($table);
#	$key = SqliteEscape($key);
#	$value = SqliteEscape($value);
#
#	SqliteQuery("INSERT INTO $table(key, alias) VALUES ('$key', '$value');");
#
#}

# sub DBGetAuthor {
# 	my $query = "SELECT author_key, author_alias, vote_weight FROM author_flat";
#
# 	my $authorInfo = SqliteQuery2($query);
#
# 	return $authorInfo;
# }


sub DBAddConfigValue {
	state $query;
	state @queryParams;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DBAddConfigValue(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 2048 || scalar(@queryParams) > 50)) {
		DBAddAuthor('flush');
		$query = '';
		@queryParams = ();
	}

	#todo sanity checks
	#todo technically, this should not override newer config

	my $value = shift;
	my $timestamp = shift;
	my $resetFlag = shift;
	my $sourceItem = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO config(key, value, timestamp, reset_flag, source_item) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $key, $value, $timestamp, $resetFlag, $sourceItem;

	return;
}

sub DBAddTitle {
	state $query;
	state @queryParams;

	my $hash = shift;
	if ($hash eq 'flush') {
		WriteLog('DBAddTitle(flush)');

		if ($query) {
			$query .= ';';
			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	my $title = shift;

	if ($query && (length($query) > 2048 || scalar(@queryParams) > 50)) {
		DBAddTitle('flush');
		$query = '';
		@queryParams = ();
	}

	#todo sanity checks

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_title(file_hash, title) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?)';
	push @queryParams, $hash, $title;
}

sub DBAddAuthor {
	state $query;
	state @queryParams;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DBAddAuthor(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 2048 || scalar(@queryParams) > 50)) {
		DBAddAuthor('flush');
		$query = '';
		@queryParams = ();
	}

	#todo sanity checks

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author(key) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?)';
	push @queryParams, $key;
}

sub DBGetTouchedPages {
	my $lastTouch = shift;

	WriteLog("DBGetTouchedPages($lastTouch)");

	my $query = "
		SELECT page_name, page_param, touch_time
		FROM page_touch
		WHERE touch_time >= ?
		ORDER BY touch_time
	";

	my @params;
	push @params, $lastTouch;

	my $results = SqliteQuery2($query, @params);

	return $results;
}

# adds to item_page table
# purpose of table is to track which items are on which pages
sub DBAddItemPage {
	state $query;
	state @queryParams;

	my $itemHash = shift;

	if ($itemHash eq 'flush') {
		if ($query) {
			WriteLog("DBAddItemPage(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 100)) {
		DBAddItemPage('flush');
		$query = '';
		@queryParams = ();
	}

	my $pageType = shift;
	my $pageParam = shift;

	if (!$pageParam) {
		$pageParam = '';
	}

	WriteLog("DBAddItemPage($itemHash, $pageType, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_page(item_hash, page_type, page_param) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?, ?)';
	push @queryParams, $itemHash, $pageType, $pageParam;
}

sub DBAddPageTouch {
	state $query;
	state @queryParams;

	my $pageName = shift;

	if ($pageName eq 'tag') {
		DBAddPageTouch('tags', '0');
	}

	if ($pageName eq 'flush') {
		if ($query) {
			WriteLog("DBAddPageTouch(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 100)) {
		DBAddPageTouch('flush');
		$query = '';
		@queryParams = ();
	}

	my $pageParam = shift;
	my $touchTime = time();

	WriteLog("DBAddPageTouch($pageName, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO page_touch(page_name, page_param, touch_time) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?, ?)';
	push @queryParams, $pageName, $pageParam, $touchTime;
}

sub DBGetVoteCounts {
	my $query = "SELECT vote_value, COUNT(vote_value) AS vote_count FROM vote GROUP BY vote_value ORDER BY vote_count DESC;";

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	return $ref;
}

#sub GetTopItemsForTag {
#	my $tag = shift;
#	chomp($tag);
#
#	my $query = "
#		SELECT * FROM item_flat WHERE file_hash IN (
#			SELECT file_hash FROM (
#				SELECT file_hash, COUNT(vote_value) AS vote_count
#				FROM vote WHERE vote_value = '" . SqliteEscape($tag) . "'
#				GROUP BY file_hash
#				ORDER BY vote_count DESC
#			)
#		);
#	";
#
#	return $query;
#}

sub DBAddKeyAlias {
	state $query;
	state @queryParams;

	my $key = shift;

	if ($key eq 'flush') {
		if ($query) {
			WriteLog("DBAddKeyAlias(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = "";
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 100)) {
		DBAddKeyAlias('flush');
		$query = '';
		@queryParams = ();
	}

	my $alias = shift;
	my $fingerprint = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author_alias(key, alias, fingerprint) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "(?, ?, ?)";
	push @queryParams, $key, $alias, $fingerprint;
}

sub DBAddItemParent {
	state $query;
	state @queryParams;

	my $itemHash = shift;

	if ($itemHash eq 'flush') {
		if ($query) {
			WriteLog('DBAddItemParent(flush)');

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 32)) {
		DBAddItemParent('flush');
		$query = '';
		@queryParams = ();
	}

	my $parentHash = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_parent(item_hash, parent_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?)';
	push @queryParams, $itemHash, $parentHash;
}

sub DBAddItem {
	state $query;
	state @queryParams;

	my $filePath = shift;

	if ($filePath eq 'flush') {
		if ($query) {
			WriteLog("DBAddItem(flush)");

			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 100)) {
		DBAddItem('flush');
		$query = '';
		@queryParams = ();
	}

	my $itemName = shift;
	my $authorKey = shift;
	my $fileHash = shift;
	my $itemType = shift;

	WriteLog("DBAddItem($filePath, $itemName, $authorKey, $fileHash, $itemType);");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, item_type) VALUES ";
	} else {
		$query .= ",";
	}

	push @queryParams, $filePath, $itemName, $authorKey, $fileHash, $itemType;

	$query .= "(?, ?, ?, ?, ?)";
}

sub DBAddVoteWeight {
	state $query;
	state @queryParams;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DbAddVoteWeight(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 1024 || scalar(@queryParams) > 100)) {
		DBAddVoteWeight('flush');
		$query = '';
		@queryParams = ();
	}

	my $weight = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote_weight(key, vote_weight) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?)';
	push @queryParams, $key, $weight;
}

sub DBAddEventRecord {
# DBAddEventRecord
# $gitHash, $eventTime, $eventDuration, $signedBy

	state $query;
	state @queryParams;

	WriteLog("DBAddEventRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddEventRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 32)) {
		DBAddEventRecord('flush');
		$query = '';
		@queryParams = ();
	}	

	my $eventTime = shift;
	my $eventDuration = shift;
	my $signedBy = shift;

	chomp $eventTime;
	chomp $eventDuration;
	chomp $signedBy;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO event(item_hash, event_time, event_duration, author_key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $fileHash, $eventTime, $eventDuration, $signedBy;
}

sub DBAddVoteRecord {
# DBAddVoteRecord
# $fileHash
# $ballotTime
# $voteValue
# $signedBy
	state $query;
	state @queryParams;

	WriteLog("DBAddVoteRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddVoteRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!$fileHash) {
		WriteLog("DBAddVoteRecord() called without \$fileHash! Returning.");
	}

	if ($query && (length($query) > 10240 && scalar(@queryParams) > 32)) {
		DBAddVoteRecord('flush');
		$query = '';
	}

	my $ballotTime = shift;
	my $voteValue = shift;
	my $signedBy = shift;

	if (!$ballotTime) {
		WriteLog("DBAddVoteRecord() called without \$ballotTime! Returning.");
	}

	if (!$signedBy) {
		WriteLog("DBAddVoteRecord() called without \$signedBy! Returning.");
	}

	chomp $fileHash;
	chomp $ballotTime;
	chomp $voteValue;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value, signed_by) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $fileHash, $ballotTime, $voteValue, $signedBy;
}

sub DBAddAddedTimeRecord {
	# Adds a new record to added_time, typically from log/added.log
	# This records the time that the file was first submitted or picked up by the indexer
	#	$fileHash = file's hash
	#	$addedTime = time it was added
	#
	state $query;
	state @queryParams;

	my $fileHash = shift;
	chomp $fileHash;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddAddedTimeRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!IsSha1($fileHash)) {
		WriteLog('DBAddAddedTimeRecord called with invalid parameter! returning');
		return;
	}

	my $addedTime = shift;
	chomp $addedTime;

	if (!$addedTime =~ m/\d{9,10}/) { #todo is this clean enough?
		WriteLog('DBAddAddedTimeRecord called with invalid parameter! returning');
		return;
	}

	if ($query && length($query) > 1024 || scalar(@queryParams) > 64) {
		DBAddAddedTimeRecord('flush');
		$query = '';
		@queryParams = ();
	}

	$fileHash = SqliteEscape($fileHash);
	$addedTime = SqliteEscape($addedTime);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO added_time(file_hash, add_timestamp) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?)';
	push @queryParams, $fileHash, $addedTime;
}

sub DBAddItemClient {
	# Adds a new record to added_time, typically from log/added.log
	# This records the time that the file was first submitted or picked up by the indexer
	#	$fileHash = file's hash
	#	$addedTime = time it was added
	#
	state $query;
	state @queryParams;

	my $fileHash = shift;
	chomp $fileHash;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddItemClient(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!IsSha1($fileHash)) {
		WriteLog('DBAddItemClient called with invalid parameter! returning');
		return;
	}

	my $addedClient = shift;
	chomp $addedClient;

	if (!$addedClient =~ m/\[0-9a-f]{32}/) { #todo is this clean enough?
		WriteLog('DBAddItemClient called with invalid parameter! returning');
		return;
	}

	if ($query && length($query) > 1024 || scalar(@queryParams) > 32) {
		DBAddItemClient('flush');
		$query = '';
		@queryParams = ();
	}

	$fileHash = SqliteEscape($fileHash);
	$addedClient = SqliteEscape($addedClient);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO added_by(file_hash, device_fingerprint) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?)';
	push @queryParams, $fileHash, $addedClient;
}

sub DBGetAddedTime {
	my $fileHash = shift;
	chomp ($fileHash);

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetAddedTime called with invalid parameter! returning');
		return;
	}

	if (!IsSha1($fileHash) || $fileHash ne SqliteEscape($fileHash)) {
		die('DBGetAddedTime() this should never happen');
	} #todo ideally this should verify it's a proper hash too

	my $query = "SELECT add_timestamp FROM added_time WHERE file_hash = '$fileHash'";

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @aref = $sth->fetchrow_array();

	$sth->finish();

	my $resultUnHacked = $aref[0];
	#todo do this properly

	return $resultUnHacked;
}

# sub DBGetItemsForTag {
# 	my $tag = shift;
# 	chomp($tag);
#
# 	$tag = SqliteEscape($tag);
#
# 	my $query = "
# 		SELECT file_hash FROM (
# 			SELECT
# 				file_hash,
# 				COUNT(file_hash) AS vote_count
# 			FROM vote
# 			WHERE
# 				vote_value = '$tag'
# 			GROUP BY file_hash
# 			ORDER BY vote_count DESC
# 		) AS item_tag
# 	"; #todo rewrite this query
#
# 	my $result = SqliteQuery($query);
#
# 	my @itemsArray = split("\n", $result);
#
# 	return @itemsArray;
# }

sub DBGetItemList {
	my $paramHashRef = shift;
	my %params = %$paramHashRef;

	#supported params:
	#where_clause = where clause for sql query
	#order_clause
	#limit_clause

	my $query;
	my $itemFields = DBGetItemFields();
	$query = "
		SELECT
			$itemFields
		FROM
			item_flat
	";

	if (defined ($params{'join_clause'})) {
		$query .= " " . $params{'join_clause'};
	}
	if (defined ($params{'where_clause'})) {
		$query .= " " . $params{'where_clause'};
	}
	if (defined ($params{'group_by_clause'})) {
		$query .= " " . $params{'group_by_clause'};
	}
	if (defined ($params{'order_clause'})) {
		$query .= " " . $params{'order_clause'};
	}
	if (defined ($params{'limit_clause'})) {
		$query .= " " . $params{'limit_clause'};
	}

	WriteLog("DBGetItemList");
	WriteLog("$query");

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetItemListForAuthor {
	my $author = shift;
	chomp($author);

	if (!IsFingerprint($author)) {
		WriteLog('DBGetItemListForAuthor called with invalid parameter! returning');
		return;
	}
	$author = SqliteEscape($author);

	my %params = {};

	$params{'where_clause'} = "WHERE author_key = '$author'";

	return DBGetItemList(\%params);
}

sub DBGetAuthorList {
	my $query = "SELECT key FROM author";

    my $sth = $dbh->prepare($query);

    $sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetAuthorAlias {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('DBGetAuthorAlias called with invalid parameter! returning');
		return;
	}

	state %aliasCache;
	if (exists($aliasCache{$key})) {
		return $aliasCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) {
		my $query = "SELECT alias FROM author_alias WHERE key = '$key'";
		$aliasCache{$key} = SqliteGetValue($query);
		return $aliasCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorScore {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('DBGetAuthorScore called with invalid parameter! returning');
		return;
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) {
		my $query = "SELECT author_score FROM author_score WHERE author_key = '$key'";
		$scoreCache{$key} = SqliteGetValue($query);
		return $scoreCache{$key};
	} else {
		return "";
	}
}


sub DBGetItemFields {
	my $itemFields = "
		item_flat.file_path file_path,
		item_flat.item_name item_name,
		item_flat.file_hash file_hash,
		item_flat.author_key author_key,
		item_flat.child_count child_count,
		item_flat.parent_count parent_count,
		item_flat.add_timestamp add_timestamp,
		item_flat.item_title item_title,
		item_flat.item_score item_score
	";

	return $itemFields;
}

sub DBGetTopAuthors {
	my $query = "
		SELECT
			author_key,
			author_alias,
			author_score
		FROM author_flat
		ORDER BY author_score DESC
		LIMIT 50;
	";

	my @queryParams;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	return $ref;
}

sub DBGetTopItems {
	my $itemFields = DBGetItemFields();

	my $query = "
		SELECT
			$itemFields
		FROM
			item_flat
		WHERE
			item_title != ''
		ORDER BY
			item_score DESC
		LIMIT 50;
	";

	my @queryParams;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	return $ref;
}

sub DBGetItemVoteTotals {
	my $fileHash = shift;
	chomp $fileHash;

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetItemVoteTotals called with invalid $fileHash! returning');
		return;
	}

	my $query = "
		SELECT
			vote_value,
			SUM(IFNULL(vote_weight,1)) AS vote_weight
		FROM
			vote_weighed
		WHERE
			file_hash = ?
		GROUP BY
			vote_value
		ORDER BY
			vote_weight DESC;
	";

	my @queryParams;
	push @queryParams, $fileHash;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my %voteTotals;

	my $tagTotal;
	while ($tagTotal = $sth->fetchrow_arrayref()) {
		$voteTotals{@$tagTotal[0]} = @$tagTotal[1];
	}

	$sth->finish();

	return %voteTotals;
}

1;
