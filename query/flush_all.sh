#!/bin/bash

#sqlite3 -cmd ".headers off" -cmd ".timeout 500" cache/*/index.sqlite3 "SELECT file_hash FROM item_flat WHERE ','||tags_list||',' NOT LIKE '%,pubkey,%' and ','||tags_list||',' NOT LIKE '%,admin,%' AND ','||tags_list||',' NOT LIKE '%,approve,%';" >> log/deleted.log

