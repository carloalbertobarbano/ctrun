#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ctrun-singularity IMAGE [CMD ...]
# Or set SINGULARITY_WRAPPER_IMAGE and run:
#   ctrun-singularity [CMD ...]
#
# Environment variables:
#   SINGULARITY_WRAPPER_IMAGE          - Default image to use
#   SINGULARITY_WRAPPER_ENV_WHITELIST  - Space-separated list of env vars to pass through
#   SINGULARITY_WRAPPER_RUN_AS_ROOT    - Set to "1" or "true" to run with sudo
#   SINGULARITY_WRAPPER_MOUNTS         - Colon-separated host:container bindings

# ----------------------------
# Detect singularity/apptainer
# ----------------------------
if command -v singularity >/dev/null 2>&1; then
    SING_BIN="singularity"
elif command -v apptainer >/dev/null 2>&1; then
    SING_BIN="apptainer"
else
    echo "Error: singularity/apptainer not found in PATH" >&2
    exit 1
fi

IMAGE="${SINGULARITY_WRAPPER_IMAGE:-}"

if [[ -z "$IMAGE" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 IMAGE [COMMAND ...]" >&2
        exit 1
    fi
    IMAGE="$1"
    shift
fi

ENV_WHITELIST="${SINGULARITY_WRAPPER_ENV_WHITELIST:-}"
RUN_AS_ROOT="${SINGULARITY_WRAPPER_RUN_AS_ROOT:-}"
EXTRA_MOUNTS="${SINGULARITY_WRAPPER_MOUNTS:-}"

uid="$(id -u)"
gid="$(id -g)"
workdir="$PWD"

# ----------------------------
# Build singularity command
# ----------------------------
sing_args=( exec )

# Root mode
if [[ "$RUN_AS_ROOT" == "1" || "$RUN_AS_ROOT" == "true" ]]; then
    echo "Running as root inside container (sudo singularity exec)" >&2
    SUDO="sudo"
else
    SUDO=""
fi

# ----------------------------
# Bind mounts
# ----------------------------
# Always bind: $HOME, /tmp, PWD → same inside container
sing_args+=( --bind "${HOME}:${HOME}" )
sing_args+=( --bind "/tmp:/tmp" )
sing_args+=( --bind "${workdir}:${workdir}" )

# Custom binds
if [[ -n "$EXTRA_MOUNTS" ]]; then
    IFS=':' read -ra MOUNTS <<< "$EXTRA_MOUNTS"
    i=0
    while [ $i -lt ${#MOUNTS[@]} ]; do
        if [ $((i+1)) -lt ${#MOUNTS[@]} ]; then
            sing_args+=( --bind "${MOUNTS[$i]}:${MOUNTS[$((i+1))]}" )
            i=$((i+2))
        else
            echo "Warning: Incomplete mount specification: ${MOUNTS[$i]}" >&2
            break
        fi
    done
fi

# ----------------------------
# Environment variables
# ----------------------------
# Pass core env vars
[ -n "${TERM-}" ] && sing_args+=( --env "TERM=${TERM}" )
[ -n "${LANG-}" ] && sing_args+=( --env "LANG=${LANG}" )
[ -n "${LC_ALL-}" ] && sing_args+=( --env "LC_ALL=${LC_ALL}" )
sing_args+=( --env "HOME=${HOME}" )
sing_args+=( --env "USER=${USER}" )

# Extra env passthrough
if [[ -n "$ENV_WHITELIST" ]]; then
    for name in $ENV_WHITELIST; do
        val="${!name-}"
        if [[ -n "$val" ]]; then
            sing_args+=( --env "${name}=${val}" )
        fi
    done
fi

# ----------------------------
# Image last, always exec command (ENTRYPOINT bypass)
# ----------------------------
sing_args+=( "$IMAGE" )

# If no command → open a shell
if [[ $# -eq 0 ]]; then
    sing_args+=( bash )
else
    sing_args+=( "$@" )
fi

# ----------------------------
# Execute command
# ----------------------------
exec ${SUDO} "$SING_BIN" "${sing_args[@]}"
