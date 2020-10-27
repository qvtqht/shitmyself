#!/bin/bash

#this query lists items which are in chain log, but not in item table

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 'SELECT file_hash FROM item_attribute WHERE attribute = "chain_sequence" AND file_hash NOT IN (SELECT file_hash FROM item);
