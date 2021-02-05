CREATE TABLE
	item
	(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_path UNIQUE,
		item_name,
		file_hash UNIQUE,
		item_type,
		verify_error
	)

CREATE TABLE
	item_attribute
	(
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		file_hash,
		attribute,
		data,
		epoch,
		source
	)

CREATE UNIQUE INDEX
	item_attribute_unique
	ON
		item_attribute
		(
			file_hash,
			attribute,
			data,
			epoch,
			source
		)
