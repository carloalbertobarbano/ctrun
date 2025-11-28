#!/usr/bin/env bash

#ln -s $(pwd)/wb_command.sh ~/.local/bin/wb_command
exec ctrun $WORK/images/fmriprep-25.2.3.sif wb_command "$@"

