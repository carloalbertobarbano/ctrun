#!/usr/bin/env bash

#ln -s $(pwd)/recon-all.sh ~/.local/bin/recon-all
exec ctrun nipreps/fmriprep:latest recon-all "$@"

