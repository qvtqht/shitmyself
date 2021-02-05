CREATE VIEW
	item_attribute_latest
AS
	SELECT
		file_hash,
		attribute,
		data,
		source,
		MAX(epoch) AS epoch
	FROM
		item_attribute
	GROUP BY
		file_hash,
		attribute
	ORDER BY
		epoch DESC

CREATE VIEW
	added_time
AS
	SELECT
		file_hash,
		data AS add_timestamp
	FROM
		item_attribute_latest
	WHERE
		attribute = 'chain_timestamp'

CREATE VIEW
	item_title
AS
	SELECT
		file_hash,
		data AS title
	FROM
		item_attribute_latest
	WHERE
		attribute = 'title'

