CREATE VIEW
	author
AS
	SELECT DISTINCT
		data AS author_key
	FROM
		item_attribute
	WHERE
		attribute IN ('cookie_id', 'gpg_id');


CREATE TABLE
	author_alias
	(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		key UNIQUE,
		alias,
		fingerprint,
		file_hash
	)

CREATE VIEW
	item_author
AS
	SELECT
		file_hash,
		MAX(value) AS author_key
	FROM
		item_attribute_latest
	WHERE
		attribute IN ('cookie_id', 'gpg_id')
	GROUP BY
		file_hash;

