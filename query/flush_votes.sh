#!/bin/bash

#this query will remove all items which are:
# +notext and
# +vote and
# -approve

#sqlite3 -cmd ".headers off" -cmd ".timeout 500" cache/*/index.sqlite3 "SELECT file_hash FROM item_flat WHERE ','||tags_list||',' NOT LIKE '%,approve,%' and ','||tags_list||',' LIKE '%,notext,%' AND ','||tags_list||',' LIKE '%,vote,%';" >> log/deleted.log

