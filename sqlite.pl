#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use 5.010;

my $SqliteDbName = "db";

sub SqliteUnlinkDb {
	unlink($SqliteDbName);
}

sub SqliteMakeTables() {
	SqliteQuery("CREATE TABLE author(key UNIQUE)");
	SqliteQuery("CREATE TABLE author_alias(key UNIQUE, alias, is_admin)");
	SqliteQuery("CREATE TABLE item(file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
}

sub SqliteQuery {
	my $query = shift;
	chomp $query;

	print "$query\n";
	
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

sub DBGetItemList {
	my $whereClause = shift;

	my $query;
	if ($whereClause) {
		$query = "SELECT item.file_path, item.item_name, item.file_hash, author_key FROM item WHERE $whereClause;";
	} else {
		$query = "SELECT item.file_path, item.item_name, item.file_hash, author_key FROM item;";
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

	return DBGetItemList("author_key = '$author'");
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

1;