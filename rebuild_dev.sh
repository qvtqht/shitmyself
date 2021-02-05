#!/bin/bash

# rebuild.sh
############
# useful during development
# rebuilds entire site
# calls update.pl --all to re-import all data

./clean_dev.sh 2>>log/clean_dev_err.txt

./build.pl 2>>log/build_err.txt

./index.pl --all 2>>log/index_err.txt

