#!/bin/bash

# displays page_touch table, sorted by relevance
# this table is queue for generating pages

# this script assumes existence of one cache/*/index.sqlite

sqlite3 -echo -cmd ".headers off" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 "SELECT count(*) FROM page_touch WHERE priority > 0; SELECT * FROM page_touch ORDER BY priority DESC, touch_time DESC LIMIT 25"

