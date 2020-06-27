#!/bin/bash

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 'SELECT DISTINCT vote_value, count(vote_value) vote_count FROM vote GROUP BY vote_value ORDER BY vote_count DESC;'
