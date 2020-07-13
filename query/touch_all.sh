#!/bin/bash

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 'update page_touch set priority=priority+1'
