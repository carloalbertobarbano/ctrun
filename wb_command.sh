#!/usr/bin/env bash

#ln -s $(pwd)/wb_command.sh ~/.local/bin/wb_command
exec ctrun nipreps/fmriprep:latest wb_command "$@"

