#/usr/bin/bash

rm -v cron.lock
rm -rfv cache
rm -rfv html/*.html html/*/*.html html/*/*/*.html
rm -rfv html/*.js html/*/*.js html/*/*/*.js
rm -rfv html/*.php html/*/*.php html/*/*/*.php
rm -rfv html/*.xml html/*/*.xml
rm -rfv html/.htaccess
rm -rfv html/*.zip
rm -rfv html/rss.xml html/rss.txt
rm -rfv config/template/*
rm -rfv config/string/*
rm -rfv config/theme/*
rm -rfv config/admin/my_version
find html -type d -empty -delete

touch html/post.html
rm -v log/log.log

rm -rfv html/txt/.git
mkdir -p html/txt

