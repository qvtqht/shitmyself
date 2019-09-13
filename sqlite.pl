#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBD::SQLite;
use DBI;
use Data::Dumper;
use 5.010;

my $SqliteDbName = './cache/' . GetMyVersion() . '/index.sqlite3'; # path to sqlite db

my $dbh; # handle for sqlite interface

require './utils.pl';

sub SqliteConnect { # Establishes connection to sqlite db
	$dbh = DBI->connect(
		"dbi:SQLite:dbname=$SqliteDbName",
		"",
		"",
		{ RaiseError => 1, AutoCommit => 1 },
	) or die $DBI::errstr;
}
SqliteConnect();

sub DBMaxQueryLength { # Returns max number of characters to allow in sqlite query
	return 10240;
}

sub DBMaxQueryParams { # Returns max number of parameters to allow in sqlite query
	return 128;
}

sub SqliteUnlinkDb { # Removes sqlite database by renaming it to ".prev"
	if ($dbh) {
		$dbh->disconnect();
	}
	rename($SqliteDbName, "$SqliteDbName.prev");
	SqliteConnect();
}

sub SqliteMakeTables() { # creates sqlite schema 

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
		item_type,
		verify_error
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
	SqliteQuery2("CREATE UNIQUE INDEX event_unique ON event(item_hash, event_time, event_duration);");

	# location
	SqliteQuery2("
		CREATE TABLE location(
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			item_hash,
			author_key,
			latitude,
			longitude
		);
	");

	# brc
	SqliteQuery2("
		CREATE TABLE brc(
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			item_hash,
			author_key,
			hours,
			minutes,
			street
		);
	");

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

sub SqliteQuery2 { # calls sqlite with query, and returns result as array reference
# #params: $query, @queryParams

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

sub EscapeShellChars { # escapes string for including in shell command
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

sub DBGetVotesForItem { # Returns all votes (weighed) for item

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
			item_flat.author_key AS author_key,
			item_flat.file_path AS file_path
		FROM
			event
			LEFT JOIN item_flat ON (event.item_hash = item_flat.file_hash)
		ORDER BY
			event_time
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

sub DBGetAuthorFriends { # Returns list of authors which $authorKey has tagged as friend
# Looks for vote_value = 'friend' and items that contain 'pubkey' tag
	my $authorKey = shift;
	chomp $authorKey;

	if (!$authorKey) {
		return;
	}

	if (!IsFingerprint($authorKey)) {
		return;
	}

	my $query = "
		SELECT
			DISTINCT item_flat.author_key
		FROM
			vote
			LEFT JOIN item_flat ON (vote.file_hash = item_flat.file_hash)
		WHERE
			signed_by = ?
			AND vote_value = 'friend'
			AND ',' || item_flat.tags_list || ',' LIKE '%,pubkey,%'
		;
	";

	my @queryParams = ();
	push @queryParams, $authorKey;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetLatestConfig { # Returns everything from config_latest view
# config_latest contains the latest set value for each key stored

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

sub SqliteGetValue { # Returns the first column from the first row returned by sqlite $query
	my $query = shift;
	chomp $query;

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @aref = $sth->fetchrow_array();

	$sth->finish();

	return $aref[0];
}

sub DBGetAuthorCount { # Returns author count.
# By default, all authors, unless $whereClause is specified

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

sub DBGetItemCount { # Returns item count.
# By default, all items, unless $whereClause is specified
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

sub DBGetReplyCount { # Returns reply (child) count for an item 
	my $parentHash = shift;

	if (!IsSha1($parentHash)) {
		WriteLog('WARNING: DBGetReplyCount() called with invalid parameter');
	}

	my $itemCount = SqliteGetValue("SELECT COUNT(*) AS reply_count FROM item_parent WHERE parent_hash = '$parentHash'");
	chomp($itemCount);

	return $itemCount;
}

sub DBGetItemParents {# Returns all item's parents
# $itemHash = item's hash/identifier
# Sets up parameters and calls DBGetItemList
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

sub DBGetItemReplies { # Returns replies for item (actually returns all child items)
# $itemHash = item's hash/identifier
# Sets up parameters and calls DBGetItemList

	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemReplies called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash')";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp";

	return DBGetItemList(\%queryParams);
}

sub SqliteEscape { # Escapes supplied text for use in sqlite query
# Just changes ' to ''
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

sub DBGetItemTitle { # get title for item ($itemhash)
	my $itemHash = shift;

	if (!$itemHash || !IsItem($itemHash)) {
		return;
	}

	my $query = 'SELECT title FROM item_title WHERE file_hash = ?';
	my @queryParams = ();

	push @queryParams, $itemHash;

	my $itemTitle = SqliteGetValue($query, @queryParams);

	return $itemTitle;
}

sub DBGetItemAuthor { # get author for item ($itemhash)
	my $itemHash = shift;

	if (!$itemHash || !IsItem($itemHash)) {
		return;
	}

	my $query = 'SELECT author_key FROM item WHERE file_hash = ?';
	my @queryParams = ();

	push @queryParams, $itemHash;

	my $authorKey = SqliteGetValue($query, @queryParams);

	return $authorKey;
}


sub DBAddConfigValue { # add value to the config table ($key, $value)
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

sub DBAddTitle { # Add entry to item_title table
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

sub DBAddAuthor { # adds author entry to index database ; $key (gpg fingerprint)
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

sub DBGetTouchedPages { # Returns items from page_touch table, used for prioritizing which pages need rebuild
# index, rss, scores, stats, tags, and top are returned first
# hard-coded at limit 50
	my $lastTouch = shift;

	WriteLog("DBGetTouchedPages($lastTouch)");

	#todo remove hardcoding
	my $query = "
		SELECT 
			page_name, 
			page_param, 
			touch_time, 
			(page_name IN ('index', 'rss', 'scores' , 'stats' , 'tags', 'top')) AS priority_page
		FROM page_touch
		WHERE touch_time >= ?
		ORDER BY priority_page desc, touch_time
		LIMIT 50;
	";

#	my $query = "
#		SELECT page_name, page_param, touch_time
#		FROM page_touch
#		WHERE touch_time >= ?
#		ORDER BY touch_time
#	";
#
	my @params;
	push @params, $lastTouch;

	my $results = SqliteQuery2($query, @params);

	return $results;
}

sub DBAddItemPage { # adds an entry to item_page table
# purpose of table is to track which items are on which pages

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

sub DBResetPageTouch { # Clears the page_touch table
# Called by clean-build, since it rebuilds the entire site
	WriteMessage("DBResetPageTouch() begin");

	my $query = "DELETE FROM page_touch WHERE 1";
	my @queryParams = ();

	SqliteQuery2($query, @queryParams);

	WriteMessage("DBResetPageTouch() end");
}

sub DBDeletePageTouch { # deletes page_touch entry ;  $pageName, $pageParam
#todo optimize
	my $query = 'DELETE FROM page_touch WHERE page_name = ? AND page_param = ?';
	
	my $pageName = shift;
	my $pageParam = shift;
	
	 my @queryParams = ($pageName, $pageParam);
	 
	  SqliteQuery2($query, @queryParams); 
}

sub DBAddPageTouch { # Adds an entry to page_touch table
# page_touch table is used for determining which pages need to be refreshed
# DBAddPageTouch is called from IndexTextFile to schedule updates for pages affected by a newly indexed item
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

sub DBGetVoteCounts { # Get total vote counts by tag value
# Takes $orderBy as parameter, with vote_count being default;
# todo can probably be converted to parameterized query
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

#todo
#	my @resultsArray = ();
#
#	while (my $row = $sth->fetchrow_hashref()) {
#		push @resultsArray, $row;
#	}
#
#	return @resultsArray;

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my $ref = $sth->fetchall_arrayref();

	$sth->finish();

	return $ref;
}

sub DBGetItemLatestAction { # returns highest timestamp in all of item's children
# $itemHash is the item's identifier

	my $itemHash = shift;
	my @queryParams = ();

	# this is my first recursive sql query
	my $query = '
	SELECT MAX(add_timestamp) AS add_timestamp
	FROM item_flat
	WHERE file_hash IN (
		WITH RECURSIVE item_threads(x) AS (
			SELECT ?
			UNION ALL
			SELECT item_parent.item_hash
			FROM item_parent, item_threads
			WHERE item_parent.parent_hash = item_threads.x
		)
		SELECT * FROM item_threads
	)
	';
	
	push @queryParams, $itemHash;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @aref = $sth->fetchrow_array();

	$sth->finish();

	return $aref[0];
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

sub DBAddKeyAlias { # adds new author-alias record $key, $alias, $pubkeyFileHash
	# $key = gpg fingerprint
	# $alias = author alias/name
	# $pubkeyFileHash = hash of file in which pubkey resides
	
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

sub DBAddItemParent { # Add item parent record. $itemHash, $parentItemHash ;
# Usually this is when item references parent item, by being a reply or a vote, etc.
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

sub DBAddItem { # Adds a new item to database
# $filePath = path to text file
# $itemName = item's 'name' (currently hash)
# $authorKey = author's gpg fingerprint
# $fileHash = hash of item
# $itemType = type of item (currently 'txt' is supported)
# $verifyError = whether there was an error with gpg verification of item

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
	my $verifyError = shift;

	if (!$authorKey) {
		$authorKey = '';
	}

	WriteLog("DBAddItem($filePath, $itemName, $authorKey, $fileHash, $itemType, $verifyError);");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, item_type, verify_error) VALUES ";
	} else {
		$query .= ",";
	}

	push @queryParams, $filePath, $itemName, $authorKey, $fileHash, $itemType, $verifyError;

	$query .= "(?, ?, ?, ?, ?, ?)";
}

sub DBAddVoteWeight { # Adds a vote weight record for a user, based on vouch/ token 
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

sub DBAddEventRecord { # add event record to database; $gitHash, $eventTime, $eventDuration, $signedBy
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


sub DBAddLocationRecord { # Adds new location record from latlong token
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

sub DBAddBrcRecord { #adds record to brc table
# $gitHash, $hours, $minutes, $street, $signedBy

	state $query;
	state @queryParams;

	WriteLog("DBAddBrcRecord()");

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddBrcRecord(flush)");

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
		DBAddBrcRecord('flush');
		$query = '';
		@queryParams = ();
	}

	my $hours = shift;
	my $minutes = shift;
	my $street = shift;
	my $signedBy = shift;

	#todo sanity check here

	chomp $hours;
	chomp $minutes;
	chomp $street;

	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO brc(item_hash, hours, minutes, street, author_key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $fileHash, $hours, $minutes, $street, $signedBy;
}

###

sub DBAddVoteRecord { # Adds a new vote (tag) record to an item based on vote/ token
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



sub DBAddItemAttribute { # adds record to item_attribute table ; currently unused
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


sub DBAddAddedTimeRecord { # Adds a new record to added_time, typically from log/added.log or from an addedtime token
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

sub DBAddItemClient { # Adds a new record to added_by, which stores client fingerprint attached to item
# $fileHash = item identifier
# $addedClient = client identifier
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

sub DBGetAddedTime { # return added time for item specified
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

sub DBGetItemList { # get list of items from database. takes reference to hash of parameters
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
	
	#todo bind params and use hash of parameters

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

sub DBGetAllAppliedTags { # return all tags that have been used at least once
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

sub DBGetItemListForAuthor { # return all items attributed to author 
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

sub DBGetAuthorList { # returns list of all authors' gpg keys as array
	my $query = "SELECT key FROM author";

    my $sth = $dbh->prepare($query);

    $sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetAuthorAlias { # returns author's alias by gpg key
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

sub DBGetAuthorScore { # returns author's total score, or the sum of all the author's items' scores
# $key = author's gpg key  
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

sub DBGetAuthorItemCount { # returns number of items attributed to author identified by $key
# $key = author's gpg key  
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

sub DBGetAuthorLastSeen { # return timestamp of last item attributed to author
# $key = author's gpg key
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


sub DBGetAuthorPublicKeyHash { # Returns the hash/identifier of the file containing the author's public key
# $key = author's gpg fingerprint
# cached in hash called %authorPubKeyCache

	my $key = shift;
	chomp ($key);

	if (!IsFingerprint($key)) {
		WriteLog('Problem! DBGetAuthorPublicKeyHash called with invalid parameter! returning');
		return;
	}

	state %authorPubKeyCache;
	if (exists($authorPubKeyCache{$key})) {
		return $authorPubKeyCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(author_alias.pubkey_file_hash) AS pubkey_file_hash FROM author_alias WHERE key = '$key'";
		$authorPubKeyCache{$key} = SqliteGetValue($query);
		return $authorPubKeyCache{$key};
	} else {
		return "";
	}
}

sub DBGetAuthorWeight { # returns author's weight from vote_weight table
# Determined by vouch/ tokens  
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


sub DBGetItemFields { # Returns fields we typically need to request from item_flat table
	my $itemFields =
		"item_flat.file_path file_path,
		item_flat.item_name item_name,
		item_flat.file_hash file_hash,
		item_flat.author_key author_key,
		item_flat.child_count child_count,
		item_flat.parent_count parent_count,
		item_flat.add_timestamp add_timestamp,
		item_flat.item_title item_title,
		item_flat.item_score item_score,
		item_flat.tags_list tags_list";

	return $itemFields;
}

#sub DBGetTopAuthors {
#	my $query = "
#		SELECT
#			author_key,
#			author_alias,
#			author_score,
#			author_weight,
#			last_seen,
#			item_count
#		FROM author_flat
#		ORDER BY author_score DESC
#		LIMIT 50;
#	";
#
#	my @queryParams;
#
#	my $sth = $dbh->prepare($query);
#	$sth->execute(@queryParams);
#
#	my $ref = $sth->fetchall_arrayref();
#
#	$sth->finish();
#
#	return $ref;
#}

sub DBGetTopAuthors { # Returns top-scoring authors from the database
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

	my @queryParams = ();

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
}

sub DBGetTopItems { # get top items minus changelog and flag (hard-coded for now)
	my $itemFields = DBGetItemFields();

	my $whereClause;

	$whereClause = "
		WHERE 
			item_title != '' AND 
			parent_count = 0 AND 
			',' || tags_list || ',' NOT LIKE '%,changelog,%' 
			AND  ',' || tags_list || ',' NOT LIKE '%flag%'
	"; #todo remove hardcoding here

	# not sure what this is supposed to be for...
#	my $additionalWhereClause = shift;
#	if ($additionalWhereClause) {
#		$whereClause .= ' AND ' . $additionalWhereClause;
#	}

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

sub DBGetItemVoteTotals { # get tag counts for specified item, returned as hash of [tag] -> count
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
