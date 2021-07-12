#!/bin/bash

source .bashrc
source .profile

tmux new-session -ds lobby -n 1 "./own-war-lobby; bash"
