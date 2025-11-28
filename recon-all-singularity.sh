#!/usr/bin/env bash

#ln -s $(pwd)/recon-all.sh ~/.local/bin/recon-all
SINGULARITY_WRAPPER_RUN_AS_ROOT=0 SINGULARITY_WRAPPER_MOUNTS=$HOME/freesurfer-license/license.txt:/opt/freesurfer/license.txt exec ctrun $WORK/images/fmriprep-25.2.3.sif recon-all "$@"

