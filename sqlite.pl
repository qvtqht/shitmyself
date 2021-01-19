#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use DBD::SQLite;
use DBI;
use Data::Dumper;
use 5.010;

sub GetSqliteDbName {
	my $cacheDir = GetDir('cache');
	my $SqliteDbName = "$cacheDir/index.sqlite3"; # path to sqlite db
	return $SqliteDbName;
}

my $dbh; # handle for sqlite interface

sub SqliteConnect { # Establishes connection to sqlite db
	my $SqliteDbName = GetSqliteDbName();
	EnsureSubdirs($SqliteDbName);
	if (!
		(
			(
				GetConfig('admin/debug')
					&&
				(
					$dbh = DBI->connect(
						"dbi:SQLite:dbname=$SqliteDbName",
						"", # username (unused)
						"", # password (unused)
						{
							RaiseError => 1,
							AutoCommit => 1
						}
					)
				)
			)
				||
			(
				$dbh = DBI->connect(
					"dbi:SQLite:dbname=$SqliteDbName",
					"", # username
					"", # password
					{
						AutoCommit => 1
					}
				)
			)
		) # ! (not)
	) { # if
		WriteLog('SqliteConnect: warning: problem connecting to database: ' . $DBI::errstr);

		state $retries;
		if (!$retries) {
			$retries = 1;
		} else {
			$retries = $retries + 1;
		}

		if ($retries < 5) {
			return SqliteConnect();
		}
	}
}
SqliteConnect();

sub DBMaxQueryLength { # Returns max number of characters to allow in sqlite query
	return 10240;
}

sub DBMaxQueryParams { # Returns max number of parameters to allow in sqlite query
	return 128;
}

sub SqliteUnlinkDb { # Removes sqlite database by renaming it to ".prev"
	my $SqliteDbName = GetSqliteDbName();
	if ($dbh) {
		$dbh->disconnect();
	}
	rename($SqliteDbName, "$SqliteDbName.prev");
	SqliteConnect();
}

sub SqliteMakeTables { # creates sqlite schema
	my $existingTables = SqliteQuery3('.tables');
	if ($existingTables) {
		WriteLog('SqliteMakeTables: warning: tables already exist');
		return;
	}

	# wal
	# this switches to write-ahead log mode for sqlite
	# reduces problems with concurrent access
	SqliteQuery2("PRAGMA journal_mode=WAL;");

	# author
	SqliteQuery2("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE)");

	# author_alias
	SqliteQuery2("CREATE TABLE author_alias(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		fingerprint,
		file_hash
	)");

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

	# item_attribute
	SqliteQuery2("
		CREATE TABLE item_attribute(
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			file_hash,
			attribute,
			value,
			epoch,
			source
		)
	");
	SqliteQuery2("
		CREATE UNIQUE INDEX item_attribute_unique ON item_attribute (
			file_hash,
			attribute,
			value,
			epoch,
			source
		)
	");
	SqliteQuery2("
		CREATE VIEW item_attribute_latest AS
		SELECT
			file_hash,
			attribute,
			value,
			source,
			MAX(epoch) AS epoch
		FROM item_attribute
		GROUP BY file_hash, attribute
		ORDER BY epoch DESC
	;");



	# added_time
	SqliteQuery("
		CREATE VIEW added_time AS
		SELECT
			file_hash,
			value AS add_timestamp
		FROM item_attribute_latest
		WHERE attribute = 'chain_timestamp'
	");

	# item_title
	SqliteQuery("
		CREATE VIEW item_title AS
		SELECT
			file_hash,
			value AS title
		FROM item_attribute_latest
		WHERE attribute = 'title'
	");
#
# 	SqliteQuery2("
# 		CREATE VIEW item_title_latest AS
# 		SELECT
# 			file_hash,
# 			title,
# 			source_item_hash,
# 			MAX(source_item_timestamp) AS source_item_timestamp
# 		FROM item_title
# 		GROUP BY file_hash
# 		ORDER BY source_item_timestamp DESC
# 	;");
# 	#SqliteQuery2("CREATE UNIQUE INDEX item_title_unique ON item_title(file_hash)");

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
	SqliteQuery2("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, author_key, ballot_hash);");
	SqliteQuery2("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value, author_key);");

	# item_page
	SqliteQuery2("CREATE TABLE item_page(item_hash, page_name, page_param);");
	SqliteQuery2("CREATE UNIQUE INDEX item_page_unique ON item_page(item_hash, page_name, page_param);");

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

	SqliteQuery2("
		CREATE TABLE user_agent(
			user_agent_string
		);
	");

	# task
	SqliteQuery2("CREATE TABLE task(id INTEGER PRIMARY KEY AUTOINCREMENT, task_type, task_name, task_param, touch_time INTEGER, priority DEFAULT 1);");
	SqliteQuery2("CREATE UNIQUE INDEX task_unique ON task(task_type, task_name, task_param);");

	# # task/queue
	# SqliteQuery2("CREATE TABLE task(id INTEGER PRIMARY KEY AUTOINCREMENT, action, param, touch_time INTEGER, priority DEFAULT 1);");
	# SqliteQuery2("CREATE UNIQUE INDEX task_touch_unique ON task(action, param);");
	#
	# action      param           touch_time     priority
	# make_page   author/abc
	# index_file  path/abc.txt
	# read_log    log/access.log
	# find_new_files
	# make_thumb  path/abc.jpg
	# annotate_votes   (vote starts with valid=0, must be annotated)
	#



	# config
	SqliteQuery2("CREATE TABLE config(key, value, timestamp, reset_flag, file_hash);");
	SqliteQuery2("CREATE UNIQUE INDEX config_unique ON config(key, value, timestamp, reset_flag);");
	SqliteQuery2("
		CREATE VIEW config_latest AS
		SELECT key, value, MAX(timestamp) config_timestamp, reset_flag, file_hash FROM config GROUP BY key ORDER BY timestamp DESC
	;");


	### VIEWS BELOW ############################################
	############################################################

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

	{ #todo clean up vote_value #scaffold
		SqliteQuery2("
			create table vote_value(vote, value);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('good', 1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('textart', 1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('meta', 1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('textart', 1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('noise', -1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('funny', 1);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('puzzle', 5);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('approve', 10);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('stop', -1023);
		");

		SqliteQuery2("
			insert into vote_value(vote, value) values('report', -1023);
		");
	}

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
				tags_list AS tags_list
			FROM
				item
				LEFT JOIN child_count ON ( item.file_hash = child_count.parent_hash)
				LEFT JOIN parent_count ON ( item.file_hash = parent_count.item_hash)
				LEFT JOIN added_time ON ( item.file_hash = added_time.file_hash)
				LEFT JOIN item_title ON ( item.file_hash = item_title.file_hash)
				LEFT JOIN item_score ON ( item.file_hash = item_score.file_hash)
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
			author_alias.alias AS author_alias,
			IFNULL(author_score.author_score, 0) AS author_score,
			MAX(item_flat.add_timestamp) AS last_seen,
			COUNT(item_flat.file_hash) AS item_count,
			author_alias.file_hash AS file_hash
		FROM
			author 
			LEFT JOIN author_alias
				ON (author.key = author_alias.key)
			LEFT JOIN author_score
				ON (author.key = author_score.author_key)
			LEFT JOIN item_flat
				ON (author.key = item_flat.author_key)
		GROUP BY
			author.key, author_alias.alias, author_alias.file_hash
	");


    	#todo deconfusify
    	SqliteQuery2("
    		CREATE VIEW
    			item_score
    		AS
    			SELECT
    				item.file_hash AS file_hash,
    				IFNULL(SUM(vote_value.value), 0) AS item_score
    			FROM
    				vote
    				LEFT JOIN item
    					ON (vote.file_hash = item.file_hash)
    				LEFT JOIN vote_value
    					ON (vote.vote_value = vote_value.vote)
    			GROUP BY
    				item.file_hash
    	");


	my $SqliteDbName = GetSqliteDbName();

	my $schemaHash = `sqlite3 "$SqliteDbName" ".schema" | sha1sum | awk '{print \$1}' > config/sqlite3_schema_hash`;
	# this can be used as cache "version"
	# only problem is first time it changes, now cache must be regenerated
	# so need to keep track of the previous one and recursively call again or copy into new location
} # SqliteMakeTables()

sub SqliteQuery2 { # $query, @queryParams; calls sqlite with query, and returns result as array reference
	WriteLog('SqliteQuery2() begin');

	my $query = shift;
	chomp $query;

	my @queryParams = @_;

	if ($query) {
		my $queryOneLine = $query;
		$queryOneLine =~ s/\s+/ /g;

		WriteLog('SqliteQuery2: $query = ' . $queryOneLine);
		WriteLog('SqliteQuery2: @queryParams: ' . join(', ', @queryParams));

		if ($dbh) {
			WriteLog('SqliteQuery2: $dbh was found, proceeding...');

			my $aref;
			my $sth;

			# try {
			#
			# } catch {
			# 	WriteMessage('SqliteQuery2: warning: error');
			# 	WriteMessage('SqliteQuery2: query: ' . $query);
			#
			# 	WriteLog('SqliteQuery2: warning: error');
			# 	WriteLog('SqliteQuery2: query: ' . $query);
			#
			# 	return;
			# };

			$sth = $dbh->prepare($query);
			my $execResult = $sth->execute(@queryParams);

			WriteLog('SqliteQuery2: $execResult = ' . $execResult);

			$aref = $sth->fetchall_arrayref();
			$sth->finish();

			return $aref;
		} else {
			WriteLog('SqliteQuery2: warning: $dbh is missing');
		}
	}
	else {
		WriteLog('SqliteQuery2: warning: $query is missing!');
		return '';
	}
}

sub EscapeShellChars { # $string ; escapes string for including as parameter in shell command
	#todo this is still probably not safe and should be improved upon #security
	my $string = shift;
	chomp $string;

	$string =~ s/([\"|\$`\\])/\\$1/g;
	# chars are: " | $ ` \

	return $string;
} # EscapeShellChars()

sub SqliteQuery { # performs sqlite query via sqlite3 command
#todo add parsing into array?
	my $query = shift;
	if (!$query) {
		WriteLog('SqliteQuery: warning: called without $query');
		return;
	}
	my $queryOneLine = $query;
	$queryOneLine =~ s/\s+/ /g;

	chomp $query;
	$query = EscapeShellChars($query);
	WriteLog('SqliteQuery: $query = ' . $queryOneLine);

	my $SqliteDbName = GetSqliteDbName();

	my $results = `sqlite3 "$SqliteDbName" "$query"`;
	return $results;
} # SqliteQuery()

sub SqliteQuery3 { # performs sqlite query via sqlite3 command
# CacheSqliteQuery { keyword
# #todo add parsing into array?
	my $query = shift;
	if (!$query) {
		WriteLog('SqliteQuery3: warning: called without $query');
		return;
	}
	chomp $query;
	$query = EscapeShellChars($query);
	WriteLog('SqliteQuery3: $query = ' . $query);

	my $cachePath = md5_hex($query);
	if ($cachePath =~ m/^([0-9a-f]{32})$/) {
		$cachePath = $1;
	} else {
		WriteLog('SqliteQuery3: warning: $cachePath sanity check failed');
	}
	my $cacheTime = GetTime();

	# this limits the cache to expiration of 1-100 seconds
	$cacheTime = substr($cacheTime, 0, length($cacheTime) - 2);
	$cachePath = "$cacheTime/$cachePath";

	WriteLog('SqliteQuery3: $cachePath = ' . $cachePath);
	my $results = GetCache("sqlitequery3/$cachePath");

	if ($results) {
		return $results;
	} else {

		my $SqliteDbName = GetSqliteDbName();
		$results = `sqlite3 "$SqliteDbName" "$query"`;
		PutCache('sqlitequery3/'.$cachePath, $results);
		return $results;
	}
} # SqliteQuery3()

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
#		$query = "SELECT file_hash, ballot_time, vote_value, author_key FROM vote_weighed WHERE file_hash = ?;";
#		@queryParams = ($fileHash);
#	} else {
#		$query = "SELECT file_hash, ballot_time, vote_value, author_key FROM vote_weighed;";
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
			author_key
		FROM vote
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

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
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
			vote.author_key = ?
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

	if ($dbh) {
		my $sth = $dbh->prepare($query);
		$sth->execute();
		my @resultsArray = ();
		while (my $row = $sth->fetchrow_hashref()) {
			push @resultsArray, $row;
		}
		return @resultsArray;
	} else {
		WriteLog('DBGetLatestConfig: warning: $dbh was false');
		return 0;
	}
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
	#todo perhaps use SqliteQuery2() ?
	#todo perhaps add params array?

	my $query = shift;
	chomp $query;

	WriteLog('SqliteGetValue: ' . $query);

	my $sth = $dbh->prepare($query);
	$sth->execute(@_);

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
	if (!IsItem($itemHash)) {
		WriteLog('DBGetItemReplies: warning: sanity check failed, returning');
		return '';
	}
	if ($itemHash ne SqliteEscape($itemHash)) {
		WriteLog('DBGetItemReplies: warning: $itemHash contains escapable characters');
		return '';
	}
	WriteLog("DBGetItemReplies($itemHash)");

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash') AND ','||tags_list||',' NOT LIKE '%,meta,%'";
	$queryParams{'order_clause'} = "ORDER BY (tags_list NOT LIKE '%hastext%'), add_timestamp";

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
# 	my $query = "SELECT author_key, author_alias FROM author_flat";
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

	chomp $itemHash;

	WriteLog('DBGetItemAuthor(' . $itemHash . ')');

	my $query = 'SELECT author_key FROM item WHERE file_hash = ?';
	my @queryParams = ();
	#
	push @queryParams, $itemHash;

	WriteLog('DBGetItemAuthor: $query = ' . $query);

	my $authorKey = SqliteGetValue($query, @queryParams);

	if ($authorKey) {
		return $authorKey;
	} else {
		return;
	}
}


sub DBAddConfigValue { # add value to the config table ($key, $value)
	state $query;
	state @queryParams;

	my $key = shift;

	if (!$key) {
		WriteLog('DBAddConfigValue: warning: sanity check failed');
		return '';
	}

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

	my $value = shift;
	my $timestamp = shift;
	my $resetFlag = shift;
	my $sourceItem = shift;

	if ($key =~ m/^([a-z0-9_\/.]+)$/) {
		# sanity success
		$key = $1;
	} else {
		WriteLog('DBAddConfigValue: warning: sanity check failed on $key = ' . $key);
		return '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO config(key, value, timestamp, reset_flag, file_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $key, $value, $timestamp, $resetFlag, $sourceItem;

	return;
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

	DBAddPageTouch('author', $key);
	DBAddPageTouch('authors');
	DBAddPageTouch('stats');
}

sub DBGetTouchedPages { # Returns items from task table, used for prioritizing which pages need rebuild
# index, rss, authors, stats, tags, and top are returned first

	my $touchedPageLimit = shift;

	WriteLog("DBGetTouchedPages($touchedPageLimit)");

	# sorted by most recent (touch_time DESC) so that most recently touched pages are updated first.
	# this allows us to call a shallow update and still expect what we just did to be updated.
	my $query = "
		SELECT 
			task_name,
			task_param,
			touch_time, 
			priority
		FROM task
		WHERE task_type = 'page' AND priority > 0
		ORDER BY priority DESC, touch_time DESC
		LIMIT ?;
	";

	my @params;
	push @params, $touchedPageLimit;

	my $results = SqliteQuery2($query, @params);

	return $results;
}

sub DBAddItemPage { # $itemHash, $pageType, $pageParam ; adds an entry to item_page table
# should perhaps be called DBAddItemPageReference
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

	if (!$pageType) {
		WriteLog('DBAddItemPage: warning: called without $pageType');
		return;
	}
	if (!$pageParam) {
		$pageParam = '';
	}

	WriteLog("DBAddItemPage($itemHash, $pageType, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_page(item_hash, page_name, page_param) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= '(?, ?, ?)';
	push @queryParams, $itemHash, $pageType, $pageParam;
}

sub DBResetPageTouch { # Clears the task table
# Called by clean-build, since it rebuilds the entire site
	WriteMessage("DBResetPageTouch() begin");

	my $query = "DELETE FROM task WHERE task_type = 'page'";
	my @queryParams = ();

	SqliteQuery2($query, @queryParams);

	WriteMessage("DBResetPageTouch() end");
}

sub DBDeletePageTouch { # $pageName, $pageParam
#todo optimize
	#my $query = 'DELETE FROM task WHERE page_name = ? AND page_param = ?';
	my $query = "UPDATE task SET priority = 0 WHERE task_type = 'page' AND task_name = ? AND task_param = ?";
	
	my $pageName = shift;
	my $pageParam = shift;
	
	my @queryParams = ($pageName, $pageParam);
	 
	SqliteQuery2($query, @queryParams);
}

sub DBDeleteItemReferences { # delete all references to item from tables
	WriteLog('DBDeleteItemReferences() ...');

	my $hash = shift;
	if (!IsSha1($hash)) {
		return;
	}

	WriteLog('DBDeleteItemReferences(' . $hash . ')');

	#todo queue all pages in item_page ;
	#todo item_page should have all the child items for replies

	#file_hash
	my @tables = qw(
		author_alias
		config
		item
		item_attribute
	);
	foreach (@tables) {
		my $query = "DELETE FROM $_ WHERE file_hash = '$hash'";
		SqliteQuery2($query);
	}

	#item_hash
	my @tables2 = qw(brc event item_page item_parent location);
	foreach (@tables2) {
		my $query = "DELETE FROM $_ WHERE item_hash = '$hash'";
		SqliteQuery2($query);
	}

	{
		my $query = "DELETE FROM vote WHERE ballot_hash = '$hash'";
		SqliteQuery2($query);
	}

	{
		my $query = "DELETE FROM item_attribute WHERE source = '$hash'";
		SqliteQuery2($query);
	}


	#ballot_hash
	my @tables3 = qw(vote);
	foreach (@tables3) {
		my $query = "DELETE FROM $_ WHERE ballot_hash = '$hash'";
		SqliteQuery2($query);
	}

	#todo
	#item_attribute.source
	#item_parent (?)
	#item_page (and refresh)
	#
	#
	#

	#todo any successes deleting stuff should result in a refresh for the affected page
}

sub DBAddPageTouch { # $pageName, $pageParam; Adds or upgrades in priority an entry to task table
# task table is used for determining which pages need to be refreshed
# is called from IndexTextFile() to schedule updates for pages affected by a newly indexed item
# if $pageName eq 'flush' then all the in-function stored queries are flushed to database.
	state $query;
	state @queryParams;

	my $pageName = shift;

	if ($pageName eq 'index') {
		#return;
		# this can be uncommented during testing to save time
		#todo optimize this so that all pages aren't rewritten at once
	}

	if ($pageName eq 'tag') {
		# if a tag page is being updated,
		# then the tags summary page must be updated also
		DBAddPageTouch('tags');
	}

	if ($pageName eq 'flush') {
		# flush to database queue stored in $query and @queryParams
		if ($query) {
			WriteLog("DBAddPageTouch(flush)");

			if (!$query) {
				WriteLog('Aborting DBAddPageTouch(flush), no query');
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

	if (!$pageParam) {
		$pageParam = 0;
	}

	my $touchTime = GetTime();

	if ($pageName eq 'author') {
		# cascade refresh items which are by this author
		#todo probably put this in another function
		# could also be done as
		# foreach (author's items) { DBAddPageTouch('item', $item); }
		#todo this is kind of a hack, sould be refactored, probably

		# touch all of author's items too
		#todo fix awkward time() concat
		my $queryAuthorItems = "
			UPDATE task
			SET priority = (priority + 1), touch_time = " . time() . "
			WHERE
				task_type = 'page' AND
				task_name = 'item' AND
				task_param IN (
					SELECT file_hash FROM item WHERE author_key = ?
				)
		";
		my @queryParamsAuthorItems;
		push @queryParamsAuthorItems, $pageParam;

		SqliteQuery2($queryAuthorItems, @queryParamsAuthorItems);
	}
	#
	# if ($pageName eq 'item') {
	# 	# cascade refresh items which are by this author
	# 	#todo probably put this in another function
	# 	# could also be done as
	# 	# foreach (author's items) { DBAddPageTouch('item', $item); }
	#
	# 	# touch all of author's items too
	# 	my $queryAuthorItems = "
	# 		UPDATE task
	# 		SET priority = (priority + 1)
	# 		WHERE
	#			task_type = 'page' AND
	# 			task_name = 'item' AND
	# 			task_param IN (
	# 				SELECT file_hash FROM item WHERE author_key = ?
	# 			)
	# 	";
	# 	my @queryParamsAuthorItems;
	# 	push @queryParamsAuthorItems, $pageParam;
	#
	# 	SqliteQuery2($queryAuthorItems, @queryParamsAuthorItems);
	# }

	#todo need to incremenet priority after doing this

	WriteLog("DBAddPageTouch($pageName, $pageParam)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO task(task_type, task_name, task_param, touch_time) VALUES ";
	} else {
		$query .= ',';
	}

	#todo
	# https://stackoverflow.com/a/34939386/128947
	# insert or replace into poet (_id,Name, count) values (
	# 	(select _id from poet where Name = "SearchName"),
	# 	"SearchName",
	# 	ifnull((select count from poet where Name = "SearchName"), 0) + 1)
	#
	# https://stackoverflow.com/a/3661644/128947
	# INSERT OR REPLACE INTO observations
	# VALUES (:src, :dest, :verb,
	#   COALESCE(
	#     (SELECT occurrences FROM observations
	#        WHERE src=:src AND dest=:dest AND verb=:verb),
	#     0) + 1);


	$query .= "('page', ?, ?, ?)";
	push @queryParams, $pageName, $pageParam, $touchTime;
} # DBAddPageTouch()

sub DBGetVoteCounts { # Get total vote counts by tag value
# Takes $orderBy as parameter, with vote_count being default;
#todo can probably be converted to parameterized query
	my $orderBy = shift;
	if ($orderBy) {
	} else {
		$orderBy = 'ORDER BY vote_count DESC';
	}

	my $query = "
		SELECT
			vote_value,
			vote_count
		FROM (
			SELECT
				vote_value,
				COUNT(vote_value) AS vote_count
			FROM
				vote
			WHERE
				file_hash IN (SELECT file_hash FROM item)
			GROUP BY
				vote_value
		)
		WHERE
			vote_count >= 1
		$orderBy;
	";

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
		$query = "INSERT OR REPLACE INTO author_alias(key, alias, file_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "(?, ?, ?)";
	push @queryParams, $key, $alias, $pubkeyFileHash;

	ExpireAvatarCache($key); # does fresh lookup, no cache
	DBAddPageTouch('author', $key);
}

sub DBAddItemParent { # Add item parent record. $itemHash, $parentItemHash ;
# Usually this is when item references parent item, by being a reply or a vote, etc.
#todo replace with item_attribute
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
		DBAddPageTouch('flush');
		DBAddItemParent('flush');
		$query = '';
		@queryParams = ();
	}

	my $parentHash = shift;

	if (!$parentHash) {
		WriteLog('DBAddItemParent: warning: $parentHash missing');
		return;
	}

	if ($itemHash eq $parentHash) {
		WriteLog('DBAddItemParent: warning: $itemHash eq $parentHash');
		return;
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_parent(item_hash, parent_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?)';
	push @queryParams, $itemHash, $parentHash;

	DBAddPageTouch('item', $itemHash);
	DBAddPageTouch('item', $parentHash);
}

sub DBAddItem { # $filePath, $itemName, $authorKey, $fileHash, $itemType, $verifyError ; Adds a new item to database
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

			DBAddItemAttribute('flush');
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

	#DBAddItemAttribute($fileHash, 'attribute', 'value', 'epoch', 'source');

	if (!$authorKey) {
		$authorKey = '';
	}
#
#	if ($authorKey) {
#		DBAddItemParent($fileHash, DBGetAuthorPublicKeyHash($authorKey));
#	}

	WriteLog("DBAddItem($filePath, $itemName, $authorKey, $fileHash, $itemType, $verifyError);");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, item_type, verify_error) VALUES ";
	} else {
		$query .= ",";
	}
	push @queryParams, $filePath, $itemName, $authorKey, $fileHash, $itemType, $verifyError;

	$query .= "(?, ?, ?, ?, ?, ?)";

	my $filePathRelative = $filePath;
	my $htmlDir = GetDir('html');
	$filePathRelative =~ s/$htmlDir\//\//;

	WriteLog('DBAddItem: $filePathRelative = ' . $filePathRelative . '; $htmlDir = ' . $htmlDir);

	if ($authorKey) {
		DBAddItemAttribute($fileHash, 'author_key', $authorKey);
	}
	DBAddItemAttribute($fileHash, 'sha1', $fileHash);
	DBAddItemAttribute($fileHash, 'md5', md5_hex(GetFile($filePath)));
	DBAddItemAttribute($fileHash, 'item_type', $itemType);
	DBAddItemAttribute($fileHash, 'file_path', $filePathRelative);

	if ($verifyError) {
		DBAddItemAttribute($fileHash, 'verify_error', '1');
	}
}

sub DBAddEventRecord { # add event record to database; $itemHash, $eventTime, $eventDuration, $signedBy
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


sub DBAddLocationRecord { # $itemHash, $latitude, $longitude, $signedBy ; Adds new location record from latlong token
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

sub DBAddBrcRecord { # $fileHash, $hours, $minutes, $street, $signedBy ; adds record to brc table
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

sub DBAddVoteRecord { # $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash ; Adds a new vote (tag) record to an item based on vote/ token
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
		WriteLog('DBAddVoteRecord: warning: called without $fileHash');
		return '';
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddVoteRecord('flush');
		DBAddPageTouch('flush');
		$query = '';
	}

	my $ballotTime = shift;
	my $voteValue = shift;
	my $signedBy = shift;
	my $ballotHash = shift;

	if (!$ballotTime) {
		WriteLog('DBAddVoteRecord: warning: missing $ballotTime');
		return '';
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

	if ($ballotHash) {
		chomp $ballotHash;
	} else {
		$ballotHash = '';
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value, author_key, ballot_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $fileHash, $ballotTime, $voteValue, $signedBy, $ballotHash;

	DBAddPageTouch('tag', $voteValue);
	DBAddPageTouch('item', $fileHash);
}

sub DBGetItemAttribute { # $fileHash, [$attribute] ; returns all if attribute not specified
	my $fileHash = shift;
	my $attribute = shift;

	if ($fileHash) {
		if ($fileHash =~ m/[^a-f0-9]/) {
			WriteLog('DBGetItemAttribute: warning: sanity check failed on $fileHash');
			return '';
		} else {
			$fileHash =~ s/[^a-f0-9]//g;
		}
	} else {
		return '';
	}
	if (!$fileHash) {
		WriteLog('DBGetItemAttribute: warning: where is $fileHash?');
		return '';
	}

	if ($attribute) {
		$attribute =~ s/[^a-zA-Z0-9_]//g;
		#todo add sanity check
	} else {
		$attribute = '';
	}

	my $query = "SELECT attribute, value FROM item_attribute_latest WHERE file_hash = '$fileHash'";
	if ($attribute) {
		$query .= " AND attribute = '$attribute'";
	}

	my $results = SqliteQuery3($query);
	return $results;
} # DBGetItemAttribute()

sub DBAddItemAttribute { # $fileHash, $attribute, $value, $epoch, $source # add attribute to item
# currently no constraints
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
		WriteLog('DBAddItemAttribute() called without $fileHash! Returning.');
	}

	if ($query && (length($query) > DBMaxQueryLength() || scalar(@queryParams) > DBMaxQueryParams())) {
		DBAddItemAttribute('flush');
		$query = '';
	}

	my $attribute = shift;
	my $value = shift;
	my $epoch = shift;
	my $source = shift;

	if (!$attribute) {
		WriteLog('DBAddItemAttribute: warning: called without $attribute');
	}
	if (!$value) {
		WriteLog('DBAddItemAttribute: warning: called without $value');
	}

	chomp $fileHash;
	chomp $attribute;
	chomp $value;

	if (!$epoch) {
		$epoch = '';
	}
	if (!$source) {
		$source = '';
	}

	chomp $epoch;
	chomp $source;

	WriteLog("DBAddItemAttribute($fileHash, $attribute, $value, $epoch, $source)");

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_attribute(file_hash, attribute, value, epoch, source) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?, ?, ?, ?, ?)';
	push @queryParams, $fileHash, $attribute, $value, $epoch, $source;
}

sub DBGetAddedTime { # return added time for item specified
	my $fileHash = shift;
	if (!$fileHash) {
		WriteLog('DBGetAddedTime: warning: $fileHash missing');
		return;
	}
	chomp ($fileHash);

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetAddedTime: warning: called with invalid parameter! returning');
		return;
	}

	if (!IsSha1($fileHash) || $fileHash ne SqliteEscape($fileHash)) {
		WriteLog('DBGetAddedTime: warning: important sanity check failed! this should never happen: !IsSha1($fileHash) || $fileHash ne SqliteEscape($fileHash)');
		return '';
	} #todo ideally this should verify it's a proper hash too

	my $query = "
		SELECT
			MIN(value) AS add_timestamp
		FROM item_attribute
		WHERE
			file_hash = '$fileHash' AND
			attribute IN ('chain_timestamp', 'gpg_timestamp', 'puzzle_timestamp')
	";
	# my $query = "SELECT add_timestamp FROM added_time WHERE file_hash = '$fileHash'";

	WriteLog($query);

	if ($dbh) {
		my $sth = $dbh->prepare($query);
		$sth->execute();

		my @aref = $sth->fetchrow_array();

		$sth->finish();

		my $resultUnHacked = $aref[0];
		#todo do this properly

		return $resultUnHacked;
	} else {
		WriteLog('DBGetAddedTime: warning: $dbh was missing, returning empty-handed');
	}
} # DBGetAddedTime()

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
	
	#todo this is currently an "OR" select, but it should be an "AND" select.

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

	WriteLog('DBGetItemList: $query = ' . $query);

	my $sth = $dbh->prepare($query);
	$sth->execute();

	my @resultsArray = ();

	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	return @resultsArray;
} # DBGetItemList()

sub DBGetAllAppliedTags { # return all tags that have been used at least once
	my $query = "
		SELECT DISTINCT vote_value FROM vote
		JOIN item ON (vote.file_hash = item.file_hash)
	";

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
	chomp $key;

	if (!IsFingerprint($key)) {
		WriteLog('DBGetAuthorAlias: warning: called with invalid parameter! returning');
		return;
	}

	$key = SqliteEscape($key);

	if ($key) {
		my $query = "SELECT alias FROM author_alias WHERE key = '$key'";
		return SqliteGetValue($query);
	} else {
		return "";
	}
}

sub DBGetAuthorScore { # returns author's total score
# score is the sum of all the author's items' scores
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
		WriteLog('DBGetAuthorItemCount: warning: called with non-fingerprint parameter, returning');
		return 0;
	}
	if ($key ne SqliteEscape($key)) {
		# should be redundant, but what the heck
		WriteLog('DBGetAuthorItemCount: warning: $key != SqliteEscape($key)');
		return 0;
	}

	state %scoreCache;
	if (exists($scoreCache{$key})) {
		return $scoreCache{$key};
	}

	if ($key) {
		my $query = "SELECT COUNT(file_hash) file_hash_count FROM (SELECT DISTINCT file_hash FROM item_flat WHERE author_key = ?)";
		$scoreCache{$key} = SqliteGetValue($query, $key);
		return $scoreCache{$key};
	} else {
		return 0;
	}

	WriteLog('DBGetAuthorItemCount: warning: unreachable reached');
	return 0;
} # DBGetAuthorItemCount()

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
	if (exists($authorPubKeyCache{$key}) && $authorPubKeyCache{$key}) {
		WriteLog('DBGetAuthorPublicKeyHash: returning from memo: ' . $authorPubKeyCache{$key});
		return $authorPubKeyCache{$key};
	}

	$key = SqliteEscape($key);

	if ($key) { #todo fix non-param sql
		my $query = "SELECT MAX(author_alias.file_hash) AS file_hash FROM author_alias WHERE key = '$key'";
		my $fileHashReturned = SqliteGetValue($query);
		if ($fileHashReturned) {
			$authorPubKeyCache{$key} = SqliteGetValue($query);
			WriteLog('DBGetAuthorPublicKeyHash: returning ' . $authorPubKeyCache{$key});
			return $authorPubKeyCache{$key};
		} else {
			WriteLog('DBGetAuthorPublicKeyHash: database drew a blank, returning 0');
			return 0;
		}
	} else {
		return "";
	}
} # DBGetAuthorPublicKeyHash()

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
		item_flat.tags_list tags_list,
		item_flat.item_type item_type";

	return $itemFields;
}

sub DBGetTopAuthors { # Returns top-scoring authors from the database
	WriteLog('DBGetTopAuthors() begin');

	my $query = "
		SELECT
			author_key,
			author_alias,
			author_score,
			last_seen,
			item_count
		FROM author_flat
		ORDER BY author_score DESC
		LIMIT 1024;
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

sub DBGetTopItems { # get top items minus flag (hard-coded for now)
	WriteLog('DBGetTopItems()');

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE item_score > 0";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp DESC";
	$queryParams{'limit_clause'} = "LIMIT 100";
	my @resultsArray = DBGetItemList(\%queryParams);

	return @resultsArray;
}

sub DBGetItemsByPrefix { # $prefix ; get items whose hash begins with $prefix
	my $prefix = shift;
	if (!IsItemPrefix($prefix)) {
		WriteLog('DBGetItemsByPrefix: warning: $prefix sanity check failed');
		return '';
	}

	my $itemFields = DBGetItemFields();
	my $whereClause;
	$whereClause = "
		WHERE
			(file_hash LIKE '%$prefix')

	"; #todo remove hardcoding here

	my $query = "
		SELECT
			$itemFields
		FROM
			item_flat
		$whereClause
		ORDER BY
			add_timestamp DESC
		LIMIT 50;
	";

	WriteLog('DBGetItemsByPrefix: $query = ' . $query);
	my @queryParams;

	my $sth = $dbh->prepare($query);
	$sth->execute(@queryParams);

	my @resultsArray = ();
	while (my $row = $sth->fetchrow_hashref()) {
		push @resultsArray, $row;
	}

	WriteLog('DBGetItemsByPrefix: scalar(@resultsArray) = ' . @resultsArray);

	return @resultsArray;
} # DBGetItemsByPrefix()

sub DBGetItemVoteTotals { # get tag counts for specified item, returned as hash of [tag] -> count
	my $fileHash = shift;
	if (!$fileHash) {
		WriteLog('DBGetItemVoteTotals: warning: $fileHash missing, returning');
		return 0;
	}

	chomp $fileHash;

	if (!IsItem($fileHash)) {
		WriteLog('DBGetItemVoteTotals: warning: sanity check failed, returned');
		return;
	}
	
	WriteLog("DBGetItemVoteTotals($fileHash)");

	my $query = "
		SELECT
			vote_value,
			COUNT(vote_value) AS vote_count
		FROM
			vote
		WHERE
			file_hash = ?
		GROUP BY
			vote_value
		ORDER BY
			vote_count DESC;
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
} # DBGetItemVoteTotals()

1;
