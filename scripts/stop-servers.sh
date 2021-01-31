#!/bin/bash

cd $HOME

source .bashrc
source .profile

tmux kill-session -t instance

