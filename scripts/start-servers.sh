#!/bin/bash

cd $HOME

source .bashrc
source .profile

tmux new-session -ds instance -n 1 "OWNWAR_SETTINGS=$HOME/instance-1.cfg ./instance-server.sh; bash"
tmux new-window -dt instance -n 2 "OWNWAR_SETTINGS=$HOME/instance-2.cfg ./instance-server.sh; bash"
tmux new-window -dt instance -n 3 "OWNWAR_SETTINGS=$HOME/instance-3.cfg ./instance-server.sh; bash"

