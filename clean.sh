#!/bin/bash

rm -v cron.lock
rm -rf cache
rm -rf html/*.html html/*/*.html html/*/*/*.html
rm -rf html/*.js html/*/*.js html/*/*/*.js
rm -rf html/*.php html/*/*.php html/*/*/*.php
rm -rf html/*.xml html/*/*.xml
rm -rf html/.htaccess
rm -rf html/*.zip
rm -rf html/rss.xml html/rss.txt
rm -rf config/template/*
rm -rf config/string/*
rm -rf config/theme/*
rm -rf config/admin/my_version
find html -type d -empty -delete

touch html/post.html
rm -v log/log.log

rm -rfv html/txt/.git
mkdir -p html/txt

