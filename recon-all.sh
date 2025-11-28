#!/usr/bin/env bash

#ln -s $(pwd)/recon-all.sh ~/.local/bin/recon-all
DOCKER_WRAPPER_RUN_AS_ROOT=1 DOCKER_WRAPPER_MOUNTS=$HOME/freesurfer-license/license.txt:/opt/freesurfer/license.txt exec ctrun nipreps/fmriprep:latest recon-all "$@"

