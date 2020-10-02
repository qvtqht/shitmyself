#!/bin/bash

# Adds all non-essential and non-#keep items to archived.log
# This results in their archiving on next pass

sqlite3 -cmd ".headers off" -cmd ".timeout 500" cache/*/index.sqlite3 "
  SELECT file_hash
  FROM item_flat
  WHERE file_hash NOT IN (
    SELECT file_hash FROM item_flat
    WHERE
      ','||tags_list||',' LIKE '%,keep,%' OR
      ','||tags_list||',' LIKE '%,puzzle,%' OR
      ','||tags_list||',' LIKE '%,admin,%' OR
      ','||tags_list||',' LIKE '%,pubkey,%'
    UNION
    SELECT item_hash AS file_hash FROM item_parent
    WHERE parent_hash IN (
      SELECT file_hash FROM item_flat
      WHERE
        ','||tags_list||',' LIKE '%,keep,%' OR
        ','||tags_list||',' LIKE '%,puzzle,%' OR
        ','||tags_list||',' LIKE '%,admin,%' OR
        ','||tags_list||',' LIKE '%,pubkey,%'
    )
    UNION
    SELECT item_hash AS file_hash FROM item_parent
    WHERE parent_hash IN (
      SELECT file_hash FROM item_flat
      WHERE parent_hash IN (
        SELECT file_hash FROM item_flat
        WHERE
          ','||tags_list||',' LIKE '%,keep,%' OR
          ','||tags_list||',' LIKE '%,puzzle,%' OR
          ','||tags_list||',' LIKE '%,admin,%' OR
          ','||tags_list||',' LIKE '%,pubkey,%'
      )
    )
  )
" >> log/archived.log



















