#!/bin/bash

# this script will clean html to make room for new html

# mkdir trash
# mkdir trash.`date +%s`
# #todo first move to trash, then rm. reason: rm takes longer than mv

echo "rm -rf html/*.html html/*/*.html html/*/*/*.html"
rm -vrf html/*.html html/*/*.html html/*/*/*.html

echo "rm -rf html/*.js html/*/*.js html/*/*/*.js"
rm -vrf html/*.js html/*/*.js html/*/*/*.js
