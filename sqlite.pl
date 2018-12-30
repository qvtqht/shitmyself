#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBD::SQLite;
use DBI;
use Data::Dumper;
use 5.010;

my $SqliteDbName = "index.sqlite3";
my $dbh;

sub SqliteConnect {
	$dbh = DBI->connect(
		"dbi:SQLite:dbname=$SqliteDbName",
		"",
		"",
		{ RaiseError => 1 },
	) or die $DBI::errstr;
}
SqliteConnect();

sub SqliteUnlinkDb {
	rename($SqliteDbName, "$SqliteDbName.prev");
}

#schema
sub SqliteMakeTables() {
	SqliteQuery2("CREATE TABLE added_time(file_hash, add_timestamp);");
	SqliteQuery2("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE)");
	SqliteQuery2("CREATE TABLE author_alias(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		is_admin,
		fingerprint
	)");
	SqliteQuery2("CREATE TABLE vote_weight(key, vote_weight)");
	SqliteQuery2("CREATE TABLE item(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_path UNIQUE,
		item_name,
		author_key,
		file_hash UNIQUE,
		item_type
	)");
	SqliteQuery2("CREATE TABLE item_parent(item_hash, parent_hash)");
	SqliteQuery2("CREATE TABLE tag(id INTEGER PRIMARY KEY AUTOINCREMENT, vote_value)");
	SqliteQuery2("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, signed_by)");

	SqliteQuery2("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value, signed_by);");
	SqliteQuery2("CREATE UNIQUE INDEX added_time_unique ON added_time(file_hash);");
	SqliteQuery2("CREATE UNIQUE INDEX tag_unique ON tag(vote_value);");
	SqliteQuery2("CREATE UNIQUE INDEX item_parent_unique ON item_parent(item_hash, parent_hash)");


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
				item.item_type AS item_type,
				IFNULL(child_count.child_count, 0) AS child_count,
				IFNULL(parent_count.parent_count, 0) AS parent_count,
				added_time.add_timestamp AS add_timestamp
			FROM
				item
				LEFT JOIN child_count ON ( item.file_hash = child_count.parent_hash)
				LEFT JOIN parent_count ON ( item.file_hash = parent_count.item_hash)
				LEFT JOIN added_time ON ( item.file_hash = added_time.file_hash);
	");
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
			author_alias.alias AS author_alias
		FROM 
			author 
			LEFT JOIN vote_weight ON (author.key = vote_weight.key) 
			LEFT JOIN author_alias ON (author.key = author_alias.key)
			GROUP BY author.key, author_alias.alias
	");
}

sub SqliteQuery2 {
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

sub SqliteQuery {
	my $query = shift;

	if (!$query) {
		WriteLog("SqliteQuery called without query");

		return;
	}

	chomp $query;

	$query = EscapeShellChars($query);

	WriteLog( "$query\n");

	my $results = `sqlite3 $SqliteDbName "$query"`;

	return $results;
}

sub DBGetVotesTable {
	my $fileHash = shift;

	if (!IsSha1($fileHash) && $fileHash) {
		WriteLog("DBGetVotesTable called with invalid parameter! returning");
		WriteLog("$fileHash");
		return '';
	}

	my $query;
	my @queryParams = ();

	if ($fileHash) {
		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed WHERE file_hash = ?;";
		@queryParams = ($fileHash);
	} else {
		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed;";
	}

	my $result = SqliteQuery2($query, @queryParams);

	return $result;
}

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

sub SqliteGetHash {
	my $query = shift;
	chomp $query;
	
	my @results = split("\n", SqliteQuery($query));

	my %hash;
	
	foreach (@results) {
		chomp;

		my ($key, $value) = split(/\|/, $_);

		$hash{$key} = $value;
	}
	
	return %hash;
}

sub SqliteGetColumn {
	my $query = shift;
	chomp $query;

	my @results = split("\n", SqliteQuery($query));

	return @results;
}

sub SqliteGetValue {
	my $query = shift;
	chomp $query;

	my $result;

	$result = SqliteQuery($query);

	return $result;
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

sub DBGetItemReplies {
	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemReplies called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE file_hash IN(SELECT item_hash FROM item_parent WHERE parent_hash = '$itemHash')";
	$queryParams{'order_clause'} = "ORDER BY item_name"; #todo this should be by timestamp

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

sub SqliteAddKeyValue {
	my $table = shift;
	my $key = shift;
	my $value = shift;

	$table = SqliteEscape ($table);
	$key = SqliteEscape($key);
	$value = SqliteEscape($value);

	SqliteQuery("INSERT INTO $table(key, alias) VALUES ('$key', '$value');");

}

sub DBGetAuthor {
	my $query = "SELECT author_key, author_alias, vote_weight FROM author_flat";

	my $authorInfo = SqliteQuery($query);

	return $authorInfo;
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

	if ($query && length($query) > 10240) {
		DBAddAuthor('flush');
		$query = '';
		@queryParams = ();
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author(key) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= '(?)';
	push @queryParams, $key;

}

sub DBGetVoteCounts {
	my $query = "SELECT vote_value, COUNT(vote_value) AS vote_count FROM vote GROUP BY vote_value ORDER BY vote_count DESC;";

	my $voteCounts = SqliteQuery($query);

	return $voteCounts;
}

sub GetTopItemsForTag {
	my $tag = shift;
	chomp($tag);

	my $query = "SELECT * FROM item_flat WHERE file_hash IN (
	SELECT file_hash FROM (
		SELECT file_hash, COUNT(vote_value) AS vote_count
		FROM vote WHERE vote_value = '" . SqliteEscape($tag) . "'
		GROUP BY file_hash
		ORDER BY vote_count DESC
	)
	);";

	return $query;
}

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

	my $itemHash = shift;

	if ($itemHash eq 'flush') {
		if ($query) {
			WriteLog('DBAddItemParent(flush)');

			$query .= ';';

			SqliteQuery($query);

			$query = '';
		}

		return;
	}

	if ($query && length($query) > 10240) {
		DBAddItemParent('flush');
		$query = '';
	}

	my $parentHash = shift;

	$itemHash = SqliteEscape($itemHash);
	$parentHash = SqliteEscape($parentHash);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item_parent(item_hash, parent_hash) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "('$itemHash', '$parentHash')";
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

			SqliteQuery($query, @queryParams);

			$query = '';
			@queryParams = ();
		}

		return;
	}

	if ($query && (length($query) > 10240 || scalar(@queryParams) > 100)) {
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

sub DBAddVoteRecord {
# DBAddVoteRecord
# $fileHash
# $ballotTime
# $voteValue
# $signedBy
	state $query;

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddVoteRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery($query);

			$query = '';
		}

		return;
	}

	if ($query && length($query) > 10240) {
		DBAddVoteRecord('flush');
		$query = '';
	}	

	my $ballotTime = shift;
	my $voteValue = shift;
	my $signedBy = shift;

	chomp $fileHash;
	chomp $ballotTime;
	chomp $voteValue;
	if ($signedBy) {
		chomp $signedBy;
	} else {
		$signedBy = '';
	}

	$fileHash = SqliteEscape($fileHash);
	$ballotTime = SqliteEscape($ballotTime);
	$voteValue = SqliteEscape($voteValue);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value, signed_by) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "('$fileHash', '$ballotTime', '$voteValue', '$signedBy')";
}

sub DBAddAddedTimeRecord {
# Adds a new record to added_time, typically from log/added.log
# This records the time that the file was first submitted or picked up by the indexer
#	$filePath = path to file
#	$fileHash = file's hash
#	$addedTime = time it was added
#
	state $query;

	my $fileHash = shift;
	chomp $fileHash;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddAddedTimeRecord(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery($query);

			$query = '';
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

	if ($query && length($query) > 10240) {
		DBAddAddedTimeRecord('flush');
		$query = '';
	}

	$fileHash = SqliteEscape($fileHash);
	$addedTime = SqliteEscape($addedTime);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO added_time(file_hash, add_timestamp) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= "('$fileHash', '$addedTime')";
}

sub DBGetAddedTime {
	my $fileHash = shift;
	chomp ($fileHash);

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetAddedTime called with invalid parameter! returning');
		return;
	}

	if ($fileHash ne SqliteEscape($fileHash)) {
		die('DBGetAddedTime() this should never happen');
	} #todo ideally this should verify it's a proper hash too

	my $query = "SELECT add_timestamp FROM added_time WHERE file_hash = '$fileHash'";

	my $result = SqliteQuery($query);

	return $result;
}

sub DBGetItemsForTag {
	my $tag = shift;
	chomp($tag);

	$tag = SqliteEscape($tag);

	my $query = "
		SELECT file_hash FROM (
			SELECT
				file_hash,
				COUNT(file_hash) AS vote_count
			FROM vote
			WHERE
				vote_value = '$tag'
			GROUP BY file_hash
			ORDER BY vote_count DESC
			LIMIT 32
		) AS item_tag
	";

	my $result = SqliteQuery($query);

	my @itemsArray = split("\n", $result);

	return @itemsArray;
}

sub DBGetItemList2 {
	my $paramHashRef = shift;
	my %params = %$paramHashRef;

	my $query;
	$query = "
		SELECT
			file_path,
			item_name,
			file_hash,
			author_key,
			child_count,
			add_timestamp
		FROM
			item_flat
	";
}

sub DBGetItemList {
	my $paramHashRef = shift;
	my %params = %$paramHashRef;

	#supported params:
	#where_clause = where clause for sql query
	#order_clause
	#limit_clause

	my $query;
	$query = "
		SELECT
			file_path,
			item_name,
			file_hash,
			author_key,
			child_count,
			add_timestamp
		FROM
			item_flat
	";

	if (defined ($params{'where_clause'})) {
		$query .= " " . $params{'where_clause'};
	}
	if (defined ($params{'order_clause'})) {
		$query .= " " . $params{'order_clause'};
	}
	if (defined ($params{'limit_clause'})) {
		$query .= " " . $params{'limit_clause'};
	}

	WriteLog("DBGetItemList()");

	my @results = split("\n", SqliteQuery($query));

	my @return;

	foreach (@results) {
		chomp;

		my ($file_path, $item_name, $file_hash, $author_key, $child_count) = split(/\|/, $_);
		my $row = {};

		$row->{'file_path'} = $file_path;
		$row->{'item_name'} = $item_name;
		$row->{'file_hash'} = $file_hash;
		$row->{'author_key'} = $author_key;
		$row->{'child_count'} = $child_count;

		push @return, $row;
	}

	return @return;
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

	my @results = SqliteGetColumn($query);

	return @results;
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

sub DBGetItemVoteTotals {
	my $fileHash = shift;
	chomp $fileHash;

	if (!IsSha1($fileHash)) {
		WriteLog('DBGetItemVoteTotals called with invalid $fileHash! returning');
		return;
	}

	my $fileHashSql = SqliteEscape($fileHash);

	my $query = "
		SELECT
			vote_value,
			SUM(IFNULL(vote_weight,1)) AS vote_weight
		FROM
			vote_weighed
		WHERE
			file_hash = '$fileHashSql'
		GROUP BY
			vote_value
		ORDER BY
			vote_weight DESC;
	";

	my %voteTotals = SqliteGetHash($query);

	return %voteTotals;
}


1;