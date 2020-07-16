#!/bin/bash

# sets all items in page_touch table to have priority = 0, which means they do not need to be refreshed
# this is a way of resetting the queue without having to rebuild all the page references

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".mode column" cache/*/index.sqlite3 'UPDATE page_touch SET priority = 0'
