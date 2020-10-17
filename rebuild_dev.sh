#!/bin/bash

# rebuild.sh
############
# useful during development
# rebuilds entire site
# calls update.pl --all to re-import all data

./clean.sh

./build.pl

./index.pl --all

./pages.pl --all

./update.pl --all
