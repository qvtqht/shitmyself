#!/bin/bash

sqlite3 -echo -cmd ".headers on" -cmd ".timeout 500" -cmd ".tables" cache/*/index.sqlite3

