#!/bin/bash

tmux new-session "watch -n 0.1 query/page_touch.sh" \; split-window "time ./loop.pl"

