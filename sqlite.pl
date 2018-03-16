#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

my $SqliteDbName = "index.sqlite3";

sub SqliteUnlinkDb {
	unlink($SqliteDbName);
}

sub SqliteMakeTables() {
	SqliteQuery("CREATE TABLE author(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE, long_key UNIQUE)");
	SqliteQuery("CREATE TABLE author_alias(id INTEGER PRIMARY KEY AUTOINCREMENT, key UNIQUE, alias, is_admin)");
	SqliteQuery("CREATE TABLE item(id INTEGER PRIMARY KEY AUTOINCREMENT, file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
	SqliteQuery("CREATE TABLE vote(id INTEGER PRIMARY KEY AUTOINCREMENT, file_hash, vote_hash, vote_value)");
	SqliteQuery("CREATE TABLE tag(id INTEGER PRIMARY KEY AUTOINCREMENT, vote_value, weight)");
#	SqliteQuery("CREATE TABLE author(key UNIQUE)");
#	SqliteQuery("CREATE TABLE author_alias(key UNIQUE, alias, is_admin)");
#	SqliteQuery("CREATE TABLE item(file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
#	SqliteQuery("CREATE TABLE vote(file_hash, vote_hash, vote_value)");

	SqliteQuery("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, vote_hash, vote_value);");
}

sub SqliteQuery {
	my $query = shift;
	chomp $query;

	#print "$query\n";
	
	my $results = `sqlite3 $SqliteDbName "$query"`;
	
	return $results;
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

	my $result = SqliteQuery($query);
	chomp $result;

	return $result;
}

sub DBGetItemCount {
	my $itemCount = SqliteGetValue("SELECT COUNT(*) FROM item");

	return $itemCount;
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
	my $isAdmin = shift;

	$key = SqliteEscape($key);
	$alias = SqliteEscape($alias);
	$isAdmin = SqliteEscape($isAdmin);

	SqliteQuery("INSERT OR REPLACE INTO author_alias(key, alias) VALUES ('$key', '$alias');");
}

sub DBAddItem {
	my $filePath = shift;
	my $itemName = shift;
	my $authorKey = shift;
	my $fileHash = shift;

	$filePath = SqliteEscape($filePath);
	$itemName = SqliteEscape($itemName);
	$fileHash = SqliteEscape($fileHash);

	if ($authorKey) {
		SqliteQuery(
			"INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash)" .
				" VALUES('$filePath', '$itemName', '$authorKey', '$fileHash');"
		);
	} else {
		SqliteQuery(
			"INSERT OR REPLACE INTO item(file_path, item_name, author_key, file_hash)" .
				" VALUES('$filePath', '$itemName', NULL, '$fileHash');"
		);
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
		"INSERT OR REPLACE INTO vote(file_hash, vote_hash, vote_value) " .
			"VALUES('$fileHash', '$ballotTime', '$voteValue');"
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
		$query = "SELECT item.file_path, item.item_name, item.file_hash, author_key FROM item WHERE $whereClause;";
	} else {
		$query = "SELECT item.file_path, item.item_name, item.file_hash, author_key FROM item";
	}
	if (defined ($params{'limit_clause'})) {
		$query .= " " . $params{'limit_clause'};
	}

	my @results = split("\n", SqliteQuery($query));

	my @return;

	foreach (@results) {
		chomp;

		my ($file_path, $item_name, $file_hash, $author_key) = split(/\|/, $_);
		my $row = {};

		$row->{'file_path'} = $file_path;
		$row->{'item_name'} = $item_name;
		$row->{'file_hash'} = $file_hash;
		$row->{'author_key'} = $author_key;

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
	$key = SqliteEscape($key);

	if ($key) {
		my $query = "SELECT alias FROM author_alias WHERE key = '$key'";
		return SqliteGetValue($query);
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