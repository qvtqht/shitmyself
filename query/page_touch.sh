#!/bin/bash

# displays task table, sorted by relevance
# this table is queue for generating pages

# this script assumes existence of one cache/*/index.sqlite

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 "SELECT priority, COUNT(*) AS count FROM task GROUP BY priority; SELECT * FROM task ORDER BY priority DESC, touch_time DESC LIMIT 25"

