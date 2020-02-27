#!/bin/bash

set -x

# example usage:
# $> ./tmux_connect_to_nodes.sh

tmux new -s quorum 'geth attach ../qdata/dd/geth.ipc' \; \
splitw -h -p 50 "geth attach ../qdata/dd/geth.ipc; bash" \; \
splitw -v -p 50 "geth attach ../qdata/dd/geth.ipc; bash" \;

# To stop the session run:
# $> tmux kill-session -t quorum
