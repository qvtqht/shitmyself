#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

my $SqliteDbName = "index.sqlite3";

sub SqliteUnlinkDb {
	#unlink($SqliteDbName);
	rename($SqliteDbName, "$SqliteDbName.prev");
}

#schema
sub SqliteMakeTables() {
	SqliteQuery("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE)");
	SqliteQuery("CREATE TABLE author_alias(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE, alias, is_admin, fingerprint)");
	SqliteQuery("CREATE TABLE item(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_path UNIQUE,
		item_name,
		author_key,
		file_hash UNIQUE,
		parent_hash,
		is_pubkey,
		last_bump
	)");
	SqliteQuery("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, ballot_time, vote_value, signed DEFAULT 0)");
	SqliteQuery("CREATE TABLE tag(id INTEGER PRIMARY KEY AUTOINCREMENT, vote_value, weight)");
	SqliteQuery("CREATE TABLE added_time(file_path, file_hash, add_timestamp);");
#	SqliteQuery("CREATE TABLE author(key UNIQUE)");
#	SqliteQuery("CREATE TABLE author_alias(key UNIQUE, alias, is_admin)");
#	SqliteQuery("CREATE TABLE item(file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
#	SqliteQuery("CREATE TABLE vote(file_hash, vote_hash, vote_value)");

	SqliteQuery("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value);");

	SqliteQuery("CREATE VIEW child_count AS select p.id, count(c.id) child_count FROM item p, item c WHERE p.file_hash = c.parent_hash GROUP BY p.id;");
	SqliteQuery("CREATE VIEW last_bump AS SELECT file_hash, MAX(add_timestamp) add_timestamp FROM added_time GROUP BY file_hash;");
}

sub SqliteQuery {
	my $query = shift;
	chomp $query;

	WriteLog( "$query\n");
	
	my $results = `sqlite3 $SqliteDbName "$query"`;

	return $results;
}

sub DBGetVotesTable {
	my $fileHash = shift;

	my $query;
	if ($fileHash) {
		$query = "SELECT file_hash, ballot_time, vote_value FROM vote WHERE file_hash = '$fileHash';";
	} else {
		$query = "SELECT file_hash, ballot_time, vote_value FROM vote;";
	}

	my $result = SqliteQuery($query);

	return $result;
}
PutFile('./html/votes.txt', DBGetVotesTable());

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

	my $result = SqliteQuery($query);
	chomp $result;

	return $result;
}

sub DBGetItemCount {
	my $whereClause = shift;

	my $itemCount;
	if ($whereClause) {
		$itemCount = SqliteGetValue("SELECT COUNT(*) FROM item WHERE $whereClause");
	} else {
		$itemCount = SqliteGetValue("SELECT COUNT(*) FROM item");
	}

	return $itemCount;
}

sub DBGetItemReplies {
	my $itemHash = shift;
	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "parent_hash = '$itemHash'";
	$queryParams{'order_clause'} = "ORDER BY add_timestamp, item_name"; #todo this should be by timestamp

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

	SqliteQuery("INSERT INTO $table(key, alias) VALUES ('$key', '$value');");

}

sub DBAddAuthor {
	my $key = shift;

	$key = SqliteEscape($key);

	SqliteQuery("INSERT OR REPLACE INTO author(key) VALUES ('$key');");
}

sub DBAddKeyAlias {
	my $key = shift;
	my $alias = shift;
	my $fingerprint = shift;

	$key = SqliteEscape($key);
	$alias = SqliteEscape($alias);
	$fingerprint = SqliteEscape($fingerprint);

	SqliteQuery("INSERT OR REPLACE INTO author_alias(key, alias, fingerprint) VALUES ('$key', '$alias', '$fingerprint');");
}

sub DBAddItem {
	my $filePath = shift;
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

	#todo clean up
	if ($authorKey) {
		SqliteQuery(
			"INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, parent_hash, is_pubkey)" .
				" VALUES('$filePath', '$itemName', '$authorKey', '$fileHash', '$parentHash', $isPubKey);"
		);
	} else {
		SqliteQuery(
			"INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash, parent_hash, is_pubkey)" .
				" VALUES('$filePath', '$itemName', NULL, '$fileHash', '$parentHash', $isPubKey);"
		);
	}

	if ($parentHash) {
		my $query = "UPDATE item SET last_bump = ";
	}
}

sub DbAddVoteWeight {
	my $voteValue = shift;
	my $weight = shift;

	$voteValue = SqliteEscape($voteValue);
	$weight = SqliteEscape($weight);

	SqliteQuery("INSERT OR REPLACE INTO tag(vote_value, weight) VALUES('$voteValue', '$weight')");
}

sub DBAddVoteRecord {
	my $fileHash = shift;
	my $ballotTime = shift;
	my $voteValue = shift;

	chomp $fileHash;
	chomp $ballotTime;
	chomp $voteValue;

	$fileHash = SqliteEscape($fileHash);
	$ballotTime = SqliteEscape($ballotTime);
	$voteValue = SqliteEscape($voteValue);

	SqliteQuery(
		"INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value) " .
			"VALUES('$fileHash', '$ballotTime', '$voteValue');"
	);
}

sub DBAddAddedRecord {
	my $filePath = shift;
	my $fileHash = shift;
	my $addedTime = shift;

	chomp $filePath;
	chomp $fileHash;
	chomp $addedTime;

	$filePath = SqliteEscape($filePath);
	$fileHash = SqliteEscape($fileHash);
	$addedTime = SqliteEscape($addedTime);

	SqliteQuery(
		"INSERT OR REPLACE INTO added_time(file_path, file_hash, add_timestamp) " .
			"VALUES('$filePath', '$fileHash', '$addedTime');"
	);
}

sub DBGetItemList {
	my $paramHashRef = shift;
	my %params = %$paramHashRef;

	#supported params:
	#where_clause = where clause for sql query

	my $query;
	if (defined ($params{'where_clause'})) {
		my $whereClause = $params{'where_clause'};
		$query = "SELECT item.file_path, item.item_name, item.file_hash, item.author_key, child_count.child_count FROM item LEFT JOIN child_count ON ( item.id = child_count.id) WHERE $whereClause";
	} else {
		$query = "SELECT item.file_path, item.item_name, item.file_hash, item.author_key, child_count.child_count FROM item LEFT JOIN child_count ON ( item.id = child_count.id)";
	}
	if (defined ($params{'limit_clause'})) {
		$query .= " " . $params{'limit_clause'};
	}
	if (defined ($params{'order_clause'})) {
		$query .= " " . $params{'order_clause'};
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
	$author = SqliteEscape($author);

	my %params = {};

	$params{'where_clause'} = "author_key = '$author'";

	return DBGetItemList(\%params);
}

sub DBGetAuthorList {
	my $query = "SELECT key FROM author";

	my @results = SqliteGetColumn($query);

	return @results;
}

sub DBGetAuthorAlias {
	my $key = shift;

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

	my $fileHashSql = SqliteEscape($fileHash);

	my $query = "SELECT vote_value, count(vote_value) vote_count FROM vote " .
		" WHERE file_hash = '$fileHashSql' GROUP BY vote_value ORDER BY vote_count DESC;";

	my %voteTotals = SqliteGetHash($query);

	return %voteTotals;
}


1;