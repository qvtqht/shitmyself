#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use DBD::SQLite;
use DBI;
use 5.010;

my $SqliteDbName = "index.sqlite3";
my $SqliteDbName2 = "test.db";
my $dbh;

sub SqliteConnect {
	$dbh = DBI->connect(
		"dbi:SQLite:dbname=test.db",
		"",
		"",
		{ RaiseError => 1 },
	) or die $DBI::errstr;
}

sub SqliteUnlinkDb {
	#unlink($SqliteDbName);
	rename($SqliteDbName, "$SqliteDbName.prev");
	rename($SqliteDbName2, "$SqliteDbName2.prev");
}

#schema
sub SqliteMakeTables() {
	SqliteQuery("CREATE TABLE added_time(file_hash, add_timestamp);");
	SqliteQuery("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE)");
	SqliteQuery("CREATE TABLE author_alias(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		is_admin,
		fingerprint
	)");
	SqliteQuery("CREATE TABLE vote_weight(key, vote_weight)");
	SqliteQuery("CREATE TABLE item(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_path UNIQUE,
		item_name,
		author_key,
		file_hash UNIQUE,
		parent_hash,
		is_pubkey
	)");
	SqliteQuery("CREATE TABLE tag(id INTEGER PRIMARY KEY AUTOINCREMENT, vote_value)");
	SqliteQuery("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, signed_by)");
+#	SqliteQuery("CREATE TABLE author(key UNIQUE)");
#	SqliteQuery("CREATE TABLE author_alias(key UNIQUE, alias, is_admin)");
#	SqliteQuery("CREATE TABLE item(file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
#	SqliteQuery("CREATE TABLE vote(file_hash, vote_hash, vote_value)");

	SqliteQuery("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value, signed_by);");
	SqliteQuery("CREATE UNIQUE INDEX added_time_unique ON added_time(file_hash);");
	SqliteQuery("CREATE UNIQUE INDEX tag_unique ON tag(vote_value);");


	SqliteQuery("CREATE VIEW child_count AS select p.id, count(c.id) child_count FROM item p, item c WHERE p.file_hash = c.parent_hash GROUP BY p.id;");
	SqliteQuery("CREATE VIEW item_last_bump AS SELECT file_hash, MAX(add_timestamp) add_timestamp FROM added_time GROUP BY file_hash;");
	SqliteQuery("
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

	SqliteQuery("
		CREATE VIEW item_flat AS
			SELECT
				item.file_path AS file_path,
				item.item_name AS item_name,
				item.file_hash AS file_hash,
				item.author_key AS author_key,
				item.parent_hash AS parent_hash,
				child_count.child_count AS child_count,
				added_time.add_timestamp AS add_timestamp
			FROM
				item
				LEFT JOIN child_count ON ( item.id = child_count.id)
				LEFT JOIN added_time ON ( item.file_hash = added_time.file_hash);
	");
	SqliteQuery("
		CREATE VIEW item_vote_count AS
			SELECT
				file_hash,
				vote_value AS vote_value,
				COUNT(file_hash) AS vote_count
			FROM vote
			GROUP BY file_hash, vote_value
			ORDER BY vote_count DESC
	");

	SqliteQuery("
		CREATE VIEW author_flat AS
			SELECT
				author.key,
				vote_weight.vote_weight,
				author_alias.alias
			FROM author
				LEFT JOIN vote_weight ON (author.key = vote_weight.key)
				LEFT JOIN author_alias ON (author.key = author_alias.key)
	");
}

sub SqliteQuery2 {
	return;
	my $query = shift;

	if (!$query) {
		WriteLog("SqliteQuery2 called without query");

		return;
	}

	chomp $query;

	WriteLog("** $query");

	if ($query) {

		my $sth = $dbh->prepare($query);
		$sth->execute();

		WriteLog ($sth);

		return $sth;
	}
}

sub EscapeShellChars {
	my $string = shift;
	chomp $string;

	#WriteLog($string);

	$string =~ s/([\"|\$`\\])/\\$1/g;
	# " | $ ` \

	#WriteLog($string);

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

	#SqliteQuery2($query);



	my $results = `sqlite3 $SqliteDbName "$query"`;

	return $results;
}

sub DBGetVotesTable {
	my $fileHash = shift;

	if (!IsSha1($fileHash)) {
		WriteLog("DBGetVotesTable called with invalid parameter! returning");
		return '';
	}

	my $query;
	if ($fileHash) {
		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed WHERE file_hash = '$fileHash';";
	} else {
		$query = "SELECT file_hash, ballot_time, vote_value, signed_by, vote_weight FROM vote_weighed;";
	}

	my $result = SqliteQuery($query);

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

sub SqliteGetValue2 {
	break;
	my $query = shift;
	chomp $query;

	my $sth = SqliteQuery2($query);
	my @row;
	my $result;

	if (@row = $sth->fetchrow_array()) {
		$result = $row[0];
	} else {
		$result = ''; #todo this is not great
	}

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

sub DBGetItemReplies {
	my $itemHash = shift;

	if (!IsSha1($itemHash)) {
		WriteLog('DBGetItemReplies called with invalid parameter! returning');
		return '';
	}

	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "WHERE parent_hash = '$itemHash'";
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

sub DBAddAuthor {
	state $query;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DBAddAuthor(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery($query);

			$query = '';
		}

		return;
	}

	if ($query && length($query) > 10240) {
	    DBAddAuthor('flush');
	    $query = '';
    }

    $key = SqliteEscape($key);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author(key) VALUES ";
	} else {
		$query .= ",";
	}
	$query .= "('$key')";
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

	my $key = shift;

	if ($key eq 'flush') {
		if ($query) {
			WriteLog("DBAddKeyAlias(flush)");

			if (!$query) {
				WriteLog('Aborting, no query');
				return;
			}

			$query .= ';';

			SqliteQuery($query);

			$query = "";
		}

		return;
	}

    if ($query && length($query) > 10240) {
        DBAddKeyAlias('flush');
        $query = '';
    }

    my $alias = shift;
	my $fingerprint = shift;

	$key = SqliteEscape($key);
	$alias = SqliteEscape($alias);
	$fingerprint = SqliteEscape($fingerprint);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author_alias(key, alias, fingerprint) VALUES ";
	} else {
		$query .= ",";
	}
	$query .= "('$key', '$alias', '$fingerprint')";
}

sub DBAddItem {
	state $query;

	my $filePath = shift;

	if ($filePath eq 'flush') {
		if ($query) {
			WriteLog("DBAddItem(flush)");

			$query .= ';';

			SqliteQuery($query);

			$query = "";
		}

		return;
	}

    if ($query && length($query) > 10240) {
        DBAddItem('flush');
        $query = '';
    }

    my $itemName = shift;
	my $authorKey = shift;
	my $fileHash = shift;
	my $parentHash = shift;
	my $isPubKey = shift;

	$filePath = SqliteEscape($filePath);
	$itemName = SqliteEscape($itemName);
	$fileHash = SqliteEscape($fileHash);
	$parentHash = SqliteEscape($parentHash);
	if ($isPubKey) {
		$isPubKey = 1;
	} else {
		$isPubKey = 0;
	}

	if (!$query) {
		$query = "INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, parent_hash, is_pubkey) VALUES ";
	} else {
		$query .= ",";
	}

	#todo clean up
	if ($authorKey) {
		$query .= "('$filePath', '$itemName', '$authorKey', '$fileHash', '$parentHash', $isPubKey)"
	} else {
		$query .= "('$filePath', '$itemName', NULL, '$fileHash', '$parentHash', $isPubKey)"
	}

#	if ($parentHash) {
#		my $query = "UPDATE item SET last_bump = "; #todo
#	}
}

sub DBAddVoteWeight {
	state $query;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DbAddVoteWeight(flush)");

		if ($query) {
			$query .= ';';

			SqliteQuery($query);

			$query = '';
		}

		return;
	}

    if ($query && length($query) > 10240) {
        DBAddVoteWeight('flush');
        $query = '';
    }

    my $weight = shift;

	$key = SqliteEscape($key);
	$weight = SqliteEscape($weight);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote_weight(key, vote_weight) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= "('$key', '$weight')";
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

sub DBGetItemList {
	my $paramHashRef = shift;
	my %params = %$paramHashRef;

	#supported params:
	#where_clause = where clause for sql query

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
