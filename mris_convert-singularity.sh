#!/usr/bin/env bash

#ln -s $(pwd)/mris_convert-singularity.sh ~/.local/bin/mris_convert
SINGULARITY_WRAPPER_RUN_AS_ROOT=0 SINGULARITY_WRAPPER_MOUNTS=$HOME/freesurfer-license/license.txt:/opt/freesurfer/license.txt exec ctrun $WORK/images/fmriprep-25.2.3.sif mris_convert "$@"

