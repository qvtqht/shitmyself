#!/bin/bash

# rebuild.sh
############
# useful during development
# rebuilds entire site
# calls update.pl --all to re-import all data

./clean.sh

./build.pl

./update.pl --all
