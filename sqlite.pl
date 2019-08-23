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

sub DBMaxQueryLength {
	return 10240;
}

sub DBMaxQueryParams {
	return 128;
}

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
	SqliteQuery2("CREATE UNIQUE INDEX added_by_unique ON added_by(file_hash)");

	# author
	SqliteQuery2("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE)");

	# author_alias
	SqliteQuery2("CREATE TABLE author_alias(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		fingerprint,
		pubkey_file_hash
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
		file_hash,
		title
	)");
	SqliteQuery2("CREATE UNIQUE INDEX item_title_unique ON item_title(file_hash)");

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
	SqliteQuery2("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, signed_by);");
	SqliteQuery2("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value, signed_by);");

	# item_attribute
	SqliteQuery2("CREATE TABLE item_attribute(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, attribute);");
	SqliteQuery2("CREATE UNIQUE INDEX item_attribute_unique ON item_attribute (file_hash, attribute);");

	# item_page
	SqliteQuery2("CREATE TABLE item_page(item_hash, page_type, page_param);");
	SqliteQuery2("CREATE UNIQUE INDEX item_page_unique ON item_page(item_hash, page_type, page_param);");

	#SqliteQuery2("CREATE TABLE item_type(item_hash, type_mask)");

	# event
	SqliteQuery2("CREATE TABLE event(id INTEGER PRIMARY KEY AUTOINCREMENT, item_hash, author_key, event_time, event_duration);");

	# location
	SqliteQuery2("CREATE TABLE location(id INTEGER PRIMARY KEY AUTOINCREMENT, item_hash, author_key, latitude, longitude);");

	# page_touch
	SqliteQuery2("CREATE TABLE page_touch(id INTEGER PRIMARY KEY AUTOINCREMENT, page_name, page_param, touch_time INTEGER);");
	SqliteQuery2("CREATE UNIQUE INDEX page_touch_unique ON page_touch(page_name, page_param);");

	# config
	SqliteQuery2("CREATE TABLE config(key, value, timestamp, reset_flag, source_item);");
	SqliteQuery2("CREATE UNIQUE INDEX config_unique ON config(key, value, timestamp, reset_flag);");
	SqliteQuery2("
		CREATE VIEW config_latest AS
		SELECT key, value, MAX(timestamp) config_timestamp, reset_flag, source_item FROM config GROUP BY key ORDER BY timestamp DESC
	;");


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
			COUNT(parent_hash) AS parent_count
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
				SUM(IFNULL(vote_weight.vote_weight, 1)) vote_weight
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
			item_tags_list
		AS
		SELECT
			file_hash,
			GROUP_CONCAT(DISTINCT vote_value) AS tags_list
		FROM vote
		GROUP BY file_hash
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
				item.item_type AS item_type,
				added_by.device_fingerprint AS added_by,
				tags_list AS tags_list
			FROM
				item
				LEFT JOIN child_count ON ( item.file_hash = child_count.parent_hash)
				LEFT JOIN parent_count ON ( item.file_hash = parent_count.item_hash)
				LEFT JOIN added_time ON ( item.file_hash = added_time.file_hash)
				LEFT JOIN item_title ON ( item.file_hash = item_title.file_hash)
				LEFT JOIN item_score ON ( item.file_hash = item_score.file_hash)
				LEFT JOIN added_by ON ( item.file_hash = added_by.file_hash)
				LEFT JOIN item_tags_list ON ( item.file_hash = item_tags_list.file_hash )
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
			author_weight
		AS
		SELECT
			vote_weight.key AS key,
			SUM(vote_weight.vote_weight) AS vote_weight
		FROM
			vote_weight
		GROUP BY
			vote_weight.key
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

	SqliteQuery2("
		CREATE VIEW 
			author_flat 
		AS 
		SELECT 
			author.key AS author_key, 
			author_weight.vote_weight AS author_weight,
			author_alias.alias AS author_alias,
			IFNULL(author_score.author_score, 0) AS author_score,
			MAX(item_flat.add_timestamp) AS last_seen,
			COUNT(item_flat.file_hash) AS item_count,
			author_alias.pubkey_file_hash AS pubkey_file_hash
		FROM
			author 
			LEFT JOIN author_weight
				ON (author.key = author_weight.key)
			LEFT JOIN author_alias
				ON (author.key = author_alias.key)
			LEFT JOIN author_score
				ON (author.key = author_score.author_key)
			LEFT JOIN item_flat
				ON (author.key = item_flat.author_key)
		GROUP BY
			author.key, author_alias.alias, pubkey_file_hash
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

	$query = "
		SELECT
			file_hash,
			ballot_time,
			vote_value,
			signed_by,
			vote_weight
		FROM vote_weighed
		WHERE file_hash = ?
	";
	@queryParams = ($fileHash);

	my $result = SqliteQuery2($query, @queryParams);

	return $result;
}

sub DBGetEvents { #gets events list
	WriteLog('DBGetEvents()');

	my $query;

	$query = "
		SELECT
			item_flat.item_title AS event_title,
			event.event_time AS event_time,
			event.event_duration AS event_duration,
			item_flat.file_hash AS file_hash,
			item_flat.author_key AS author_key
		FROM
			event
			LEFT JOIN item_flat ON (event.item_hash = item_flat.file_hash)
	";

	my @queryParams = ();
#	push @queryParams, $time;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	WriteLog('DBGetEvents: ' . scalar(@{$ref}) . ' items returned');

	return $ref;
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

sub DBResetPageTouch {
	my $query = "DELETE FROM page_touch WHERE 1";
	my @queryParams = ();

	SqliteQuery2($query, @queryParams);
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddPageTouch('flush');
		$query = '';
		@queryParams = ();
	}

	my $pageParam = shift;
	my $touchTime = GetTime();

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
	my $orderBy = shift;
	if ($orderBy) {
	} else {
		$orderBy = 'ORDER BY vote_count DESC';
	}

	#todo make this by item, not vote count
	my $query = "
		SELECT
			vote_value,
			COUNT(vote_value) AS vote_count
		FROM
			vote
		GROUP BY
			vote_value
		$orderBy;
	";

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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddKeyAlias('flush');
		$query = '';
		@queryParams = ();
	}

	my $alias = shift;
	my $pubkeyFileHash = shift;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author_alias(key, alias, pubkey_file_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "(?, ?, ?)";
	push @queryParams, $key, $alias, $pubkeyFileHash;
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItem('flush');
		$query = '';
		@queryParams = ();
	}

	my $itemName = shift;
	my $authorKey = shift;
	my $fileHash = shift;
	my $itemType = shift;

	if (!$authorKey) {
		$authorKey = '';
	}

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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddEventRecord('flush');
		$query = '';
		@queryParams = ();
	}

	my $eventTime = shift;
	my $eventDuration = shift;
	my $signedBy = shift;

	if (!$eventTime || !$eventDuration) {
		WriteLog('DBAddEventRecord() sanity check failed! Missing $eventTime or $eventDuration');
		return;
	}

	chomp $eventTime;
	chomp $eventDuration;

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


sub DBAddLocationRecord {
	# DBAddLocationRecord
	# $gitHash, $latitude, $longitude, $signedBy

	state $query;
	state @queryParams;

	WriteLog("DBAddLocationRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddLocationRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (
		$query
			&&
		(
			length($query) >= DBMaxQueryLength()
				||
			scalar(@queryParams) > DBMaxQueryParams()
		)
	) {
		DBAddLocationRecord('flush');
		$query = '';
		@queryParams = ();
	}

	my $latitude = shift;
	my $longitude = shift;
	my $signedBy = shift;

	if (!$latitude || !$longitude) {
		WriteLog('DBAddLocationRecord() sanity check failed! Missing $latitude or $longitude');
		return;
	}

	chomp $latitude;
	chomp $longitude;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO location(item_hash, latitude, longitude, author_key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?)';
	push @queryParams, $fileHash, $latitude, $longitude, $signedBy;
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

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddVoteRecord('flush');
		$query = '';
	}

	my $ballotTime = shift;
	my $voteValue = shift;
	my $signedBy = shift;

	if (!$ballotTime) {
		WriteLog("DBAddVoteRecord() called without \$ballotTime! Returning.");
	}

#	if (!$signedBy) {
#		WriteLog("DBAddVoteRecord() called without \$signedBy! Returning.");
#	}

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



sub DBAddItemAttribute {
	# DBAddItemAttribute
	# $fileHash
	# $attribute

	state $query;
	state @queryParams;

	WriteLog("DBAddItemAttribute()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddItemAttribute(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery2($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if (!$fileHash) {
		WriteLog("DBAddItemAttribute() called without \$fileHash! Returning.");
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItemAttribute('flush');
		$query = '';
	}

	my $attribute = shift;

	chomp $fileHash;
	chomp $attribute;

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_attribute(file_hash, attribute) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?)';
	push @queryParams, $fileHash, $attribute;
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

	if ($query && length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams()) {
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

	WriteLog('DBAddItemClient()');

	my $fileHash = shift;
	chomp $fileHash;

	WriteLog('DBAddItemClient(' . $fileHash . ')');

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

#	if (!IsSha1($fileHash)) {
#		WriteLog('DBAddItemClient called with invalid parameter! returning');
#		return;
#	}

	my $addedClient = shift;
	chomp $addedClient;



	WriteLog("DBAddItemClient($fileHash, $addedClient)");
#
#	if (!($addedClient =~ m/\[0-9a-f]{32}/)) { #todo is this clean enough?
#		WriteLog('DBAddItemClient() called with invalid parameter! returning');
#		return;
#	}

	if ($query && length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams()) {
		DBAddItemClient('flush');

		$query = '';
		@queryParams = ();
	}

	#todo is this redundant?
#	$fileHash = SqliteEscape($fileHash);
#	$addedClient = SqliteEscape($addedClient);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO added_by(file_hash, device_fingerprint) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?)';
	push @queryParams, $fileHash, $addedClient;

	WriteLog($query);
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

	WriteLog($query);

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

sub DBGetItemListByTagList { #get list of items by taglist (as array)
# uses DBGetItemList()
#	my @tagListArray = shift;

#	if (scalar(@tagListArray) < 1) {
#		return;
#	}

	#todo sanity checks

	my @tagListArray = @_;

	my $tagListCount = scalar(@tagListArray);

	my $tagListArrayText = "'" . join ("','", @tagListArray) . "'";

	my %queryParams;
	my $whereClause = "
		WHERE file_hash IN (
			SELECT file_hash FROM (
				SELECT
					COUNT(id) AS vote_count,
						file_hash
				FROM vote
				WHERE vote_value IN ($tagListArrayText)
				GROUP BY file_hash
			) WHERE vote_count >= $tagListCount
		)
	";
	WriteLog("DBGetItemListByTagList");
	WriteLog("$whereClause");

	$queryParams{'where_clause'} = $whereClause;

			#todo do it correctly like this:
#	$sth = $dbh->prepare( "
#            SELECT name, location
#            FROM megaliths
#            WHERE name = ?
#            AND mapref = ?
#            AND type LIKE ?
#        " );
#	$sth->bind_param( 1, "Avebury" );
#	$sth->bind_param( 2, $mapreference );
#	$sth->bind_param( 3, "%Stone Circle%" );

	return DBGetItemList(\%queryParams);
}

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

	#todo sanity check: typically, none of these should have a semicolon?
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

sub DBGetAllAppliedTags {
	my $query = "SELECT DISTINCT vote_value FROM vote";

	my $sth = $dbh->prepare($query);

	my @ary;

	$sth->execute();

	$sth->bind_columns(\my $val1);

	while ($sth->fetch) {
		push @ary, $val1;
	}

	return @ary;
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
		WriteLog('Problem! DBGetAuthorScore called with invalid parameter! returning');
		return;
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT author_score FROM author_score WHERE author_key = '$key'";
		$scoreCache{$key} = SqliteGetValue($query);
		return $scoreCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorItemCount {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorScore called with invalid parameter! returning');
		return;
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT COUNT(file_hash) item_count FROM item_flat WHERE author_key = '$key'";
		$scoreCache{$key} = SqliteGetValue($query);
		return $scoreCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorLastSeen {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorLastSeen called with invalid parameter! returning');
		return;
	}

	state %lastSeenCache;
	if (exists($lastSeenCache{$key})) {
		return $lastSeenCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(item_flat.add_timestamp) AS last_seen FROM item_flat WHERE author_key = '$key'";
		$lastSeenCache{$key} = SqliteGetValue($query);
		return $lastSeenCache{$key};
	} else {
		return "";
	}
}


sub DBGetAuthorPublicKeyHash {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorPublicKeyHash called with invalid parameter! returning');
		return;
	}

	state %lastSeenCache;
	if (exists($lastSeenCache{$key})) {
		return $lastSeenCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(author_alias.pubkey_file_hash) AS pubkey_file_hash FROM author_alias WHERE key = '$key'";
		$lastSeenCache{$key} = SqliteGetValue($query);
		return $lastSeenCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorWeight {
	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorWeight called with invalid parameter! returning');
		return;
	}

	state %weightCache;
	if (exists($weightCache{$key})) {
		return $weightCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT SUM(vote_weight) FROM vote_weight WHERE key = '$key'";
		$weightCache{$key} = SqliteGetValue($query);

		if (!defined($weightCache{$key}) || $weightCache{$key} < 1) {
			$weightCache{$key} = 1;
		}

		return $weightCache{$key};
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
		item_flat.item_score item_score,
		item_flat.tags_list tags_list
	";

	return $itemFields;
}

sub DBGetTopAuthors {
	my $query = "
		SELECT
			author_key,
			author_alias,
			author_score,
			author_weight,
			last_seen,
			item_count
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

	my $whereClause;

	$whereClause = "WHERE item_title != '' AND parent_count = 0";

	my $additionalWhereClause = shift;

	if ($additionalWhereClause) {
		$whereClause .= ' AND ' . $additionalWhereClause;
	}

	my $query = "
		SELECT
			$itemFields
		FROM
			item_flat
		$whereClause
		ORDER BY
			item_score DESC
		LIMIT 50;
	";

	WriteLog('DBGetTopItems()');

	WriteLog($query);

	my @queryParams;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	return $ref;
}

sub DBGetItemVoteTotals {
	my $fileHash = shift;

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetItemVoteTotals called with invalid $fileHash! returning');
		return;
	}

	chomp $fileHash;

	my $query = "
		SELECT
			vote_value,
			SUM(IFNULL(vote_weight,1)) AS vote_weight_sum
		FROM
			vote_weighed
		WHERE
			file_hash = ?
		GROUP BY
			vote_value
		ORDER BY
			vote_weight_sum DESC;
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
