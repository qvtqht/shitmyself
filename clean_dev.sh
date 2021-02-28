#!/bin/bash

# MYDATE=`date +%s`
# mkdir trash
# mkdir trash.$MYDATE

echo "rm -v cron.lock"
rm -v cron.lock

echo "rm -rf cache"
rm -rf cache

echo "rm -rf html/*.html html/*/*.html html/*/*/*.html"
rm -rf html/*.html html/*/*.html html/*/*/*.html

echo "rm -rf html/*.js html/*/*.js html/*/*/*.js"
rm -rf html/*.js html/*/*.js html/*/*/*.js

echo "rm -rf html/*.php html/*/*.php html/*/*/*.php"
rm -rf html/*.php html/*/*.php html/*/*/*.php

echo "rm -rf html/*.xml html/*/*.xml"
rm -rf html/*.xml html/*/*.xml

echo "rm -rf html/.htaccess"
rm -rf html/.htaccess

echo "rm -rf html/*.zip"
rm -rf html/*.zip

echo "rm -rf html/rss.xml html/rss.txt"
rm -rf html/rss.xml html/rss.txt

echo "rm -rf config/template/*"
rm -rf config/template/*

echo "rm -rf config/query/*"
rm -rf config/query/*

echo "rm -rf config/string/*"
rm -rf config/string/*

echo "rm -rf config/theme/*"
rm -rf config/theme/*

echo "rm -rf config/admin/my_version"
rm -rf config/admin/my_version

echo "find html -type d -empty -delete"
find html -type d -empty -delete

echo "touch html/post.html"
touch html/post.html

echo "rm -v log/log.log"
rm -v log/log.log

echo "mkdir -p html/txt"
mkdir -p html/txt
