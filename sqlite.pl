#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use utf8;
use DBD::SQLite;
use DBI;
use 5.010;

my $SqliteDbName = "index.sqlite3";
my $SqliteDbName2 = "test.sqlite3";

my $dbh = DBI->connect(
	"dbi:SQLite:dbname=$SqliteDbName2",
	"",
	"",
	{ RaiseError => 1 },
) or die $DBI::errstr;

sub SqliteUnlinkDb {
	#unlink($SqliteDbName);
	rename($SqliteDbName, "$SqliteDbName.prev");
	rename($SqliteDbName2, "$SqliteDbName2.prev");
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
+#	SqliteQuery("CREATE TABLE author(key UNIQUE)");
#	SqliteQuery("CREATE TABLE author_alias(key UNIQUE, alias, is_admin)");
#	SqliteQuery("CREATE TABLE item(file_path UNIQUE, item_name, author_key, file_hash UNIQUE)");
#	SqliteQuery("CREATE TABLE vote(file_hash, vote_hash, vote_value)");

	SqliteQuery("CREATE UNIQUE INDEX vote_unique ON vote (file_hash, ballot_time, vote_value);");

	SqliteQuery("CREATE VIEW child_count AS select p.id, count(c.id) child_count FROM item p, item c WHERE p.file_hash = c.parent_hash GROUP BY p.id;");
	SqliteQuery("CREATE VIEW item_last_bump AS SELECT file_hash, MAX(add_timestamp) add_timestamp FROM added_time GROUP BY file_hash;");
}

sub SqliteQuery2 {
	my $query = shift;

	if (!$query) {
		WriteLog("SqliteQuery2 called without query");

		return;
	}

	chomp $query;

	WriteLog("** $query");

	my $sth = $dbh->prepare($query);
	$sth->execute();

	WriteLog ($sth);

	return $sth;
}

sub SqliteQuery {
	my $query = shift;

	if (!$query) {
		WriteLog("SqliteQuery called without query");

		return;
	}

	chomp $query;

	WriteLog( "$query\n");

	SqliteQuery2($query);
	
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
		$itemCount = SqliteGetValue2("SELECT COUNT(*) FROM item WHERE $whereClause");
	} else {
		$itemCount = SqliteGetValue2("SELECT COUNT(*) FROM item");
	}

	return $itemCount;
}

sub DBGetItemReplies {
	my $itemHash = shift;
	$itemHash = SqliteEscape($itemHash);

	my %queryParams;
	$queryParams{'where_clause'} = "parent_hash = '$itemHash'";
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

		$query .= ';';

		SqliteQuery($query);

		$query = '';

		return;
	}

	$key = SqliteEscape($key);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO author(key) VALUES ";
	} else {
		$query .= ",";
	}
	$query .= "('$key')";
}

sub DBAddKeyAlias {
	state $query;

	my $key = shift;

	if ($key eq 'flush') {
		WriteLog("DBAddKeyAlias(flush)");

		if (!$query) {
			WriteLog('Aborting, no query');
			return;
		}

		$query .= ';';

		SqliteQuery($query);

		$query = "";

		return;
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

	DBAddKeyAlias('flush'); #temporary while fixing bug todo
}

sub DBAddItem {
	state $query;

	my $filePath = shift;

	if ($filePath eq 'flush') {
		WriteLog("DBAddItem(flush)");

		$query .= ';';

		SqliteQuery($query);

		$query = "";

		return;
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

sub DbAddVoteWeight { #todo test this function, as it is apparently unused as of now
	state $query;
	state $tagQuery;

	my $voteValue = shift;

	if ($voteValue eq 'flush') {
		WriteLog("DbAddVoteWeight(flush)");

		$query .= ';';
		$tagQuery .= ';';

		SqliteQuery($query);
		SqliteQuery($tagQuery);

		$query = '';
		$tagQuery = '';

		return;
	}

	my $weight = shift;

	$voteValue = SqliteEscape($voteValue);
	$weight = SqliteEscape($weight);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO tag(vote_value, weight) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= "('$voteValue', '$weight')";

	if (!$tagQuery) {
		$tagQuery = "INSERT OR REPLACE INTO tag(vote_value, weight) VALUES ";
	} else {
		$tagQuery .= ",";
	}

	$tagQuery .= "('$voteValue', '$weight')";
}

sub DBAddVoteRecord {
	state $query;

	my $fileHash = shift;

	if ($fileHash eq 'flush') {
		WriteLog("DBAddVoteRecord(flush)");

		$query .= ';';

		SqliteQuery($query);

		$query = '';

		return;
	}

	my $ballotTime = shift;
	my $voteValue = shift;

	chomp $fileHash;
	chomp $ballotTime;
	chomp $voteValue;

	$fileHash = SqliteEscape($fileHash);
	$ballotTime = SqliteEscape($ballotTime);
	$voteValue = SqliteEscape($voteValue);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO vote(file_hash, ballot_time, vote_value) VALUES ";
	} else {
		$query .= ",";
	}

	$query .= "('$fileHash', '$ballotTime', '$voteValue')";
}

sub DBAddAddedRecord {
	state $query;

	my $filePath = shift;

	if ($filePath eq 'flush') {
		WriteLog("DBAddAddedRecord(flush)");

		$query .= ';';

		SqliteQuery($query);

		$query = '';

		return;
	}

	my $fileHash = shift;
	my $addedTime = shift;

	chomp $filePath;
	chomp $fileHash;
	chomp $addedTime;

	$filePath = SqliteEscape($filePath);
	$fileHash = SqliteEscape($fileHash);
	$addedTime = SqliteEscape($addedTime);

	if (!$query) {
		$query = "INSERT OR REPLACE INTO added_time(file_path, file_hash, add_timestamp) VALUES ";
	} else {
		$query .= ',';
	}

	$query .= "('$filePath', '$fileHash', '$addedTime')";
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