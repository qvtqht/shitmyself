#!/bin/bash

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 'select distinct vote_value, count(vote_value) vote_count from vote group by vote_value order by vote_count desc;'
