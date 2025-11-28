#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ctrun-singularity IMAGE [CMD ...]
# Or set DOCKER_WRAPPER_IMAGE and run:
#   ctrun-singularity [CMD ...]
#
# Notes:
# - IMAGE may be a local .sif file path OR a remote image.
#   If it does not include a scheme (e.g., docker://, library://),
#   it will be treated as a Docker image and prefixed with docker://
#   so you can use names like "ubuntu:22.04".
#
# Environment variables:
#   DOCKER_WRAPPER_IMAGE          - Default image to use
#   DOCKER_WRAPPER_ENV_WHITELIST  - Space-separated list of env vars to pass through
#   DOCKER_WRAPPER_RUN_AS_ROOT    - Set to "1" or "true" to run as root (via sudo or --fakeroot)
#   DOCKER_WRAPPER_MOUNTS         - Colon-separated list of additional mounts (e.g., "/host:/ctr:/another:/mount")
#   SINGULARITY_USE_SUDO          - If set to "1"/"true" and RUN_AS_ROOT is enabled, run via sudo instead of --fakeroot

IMAGE="${DOCKER_WRAPPER_IMAGE:-}"

if [[ -z "$IMAGE" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "Usage: $0 IMAGE [COMMAND ...]" >&2
    exit 1
  fi
  IMAGE="$1"
  shift
fi

# Optional: env whitelist
ENV_WHITELIST="${DOCKER_WRAPPER_ENV_WHITELIST:-}"

# Optional: run as root
RUN_AS_ROOT="${DOCKER_WRAPPER_RUN_AS_ROOT:-}"
USE_SUDO="${SINGULARITY_USE_SUDO:-}"

# Optional: additional mounts
EXTRA_MOUNTS="${DOCKER_WRAPPER_MOUNTS:-}"

uid="$(id -u)"
gid="$(id -g)"
workdir="$PWD"

# Resolve IMAGE to a singularity reference
# - If local file exists, use it as-is (likely .sif)
# - If it already has a scheme (docker://, library://, oras://), keep it
# - Otherwise, assume docker://<IMAGE>
if [[ -f "$IMAGE" ]]; then
  S_IMG="$IMAGE"
else
  if [[ "$IMAGE" == *"://"* ]]; then
    S_IMG="$IMAGE"
  else
    S_IMG="docker://$IMAGE"
  fi
fi

singularity_cmd=( singularity exec )
singularity_args=()

# Start with a clean container env to mimic docker behavior
singularity_args+=( --cleanenv )

# Working directory
singularity_args+=( --pwd "$workdir" )

# Bind mounts (HOME, /tmp, current workdir)
binds=(
  "${HOME}:${HOME}"
  "/tmp:/tmp"
  "${workdir}:${workdir}"
)

# Additional mounts
if [[ -n "$EXTRA_MOUNTS" ]]; then
  IFS=':' read -ra MOUNTS <<< "$EXTRA_MOUNTS"
  i=0
  while [[ $i -lt ${#MOUNTS[@]} ]]; do
    if [[ $((i + 1)) -lt ${#MOUNTS[@]} ]]; then
      binds+=( "${MOUNTS[$i]}:${MOUNTS[$((i+1))]}" )
      i=$((i + 2))
    else
      echo "Warning: Ignoring incomplete mount specification: ${MOUNTS[$i]}" >&2
      break
    fi
  done
fi

# Apply binds
for b in "${binds[@]}"; do
  singularity_args+=( --bind "$b" )
fi

# Basic env (explicit to match docker wrapper)
singularity_env=(
  "HOME=${HOME}"
  "USER=${USER:-user}"
)

[[ -n "${TERM-}" ]] && singularity_env+=( "TERM=${TERM}" )
[[ -n "${LANG-}" ]] && singularity_env+=( "LANG=${LANG}" )
[[ -n "${LC_ALL-}" ]] && singularity_env+=( "LC_ALL=${LC_ALL}" )

# Extra env pass-through
if [[ -n "$ENV_WHITELIST" ]]; then
  for name in $ENV_WHITELIST; do
    val="${!name-}"
    if [[ -n "$val" ]]; then
      singularity_env+=( "${name}=${val}" )
    fi
  done
fi

# Attach envs
for e in "${singularity_env[@]}"; do
  singularity_args+=( --env "$e" )
fi

# Root behavior
if [[ "$RUN_AS_ROOT" == "1" || "$RUN_AS_ROOT" == "true" ]]; then
  if [[ "$USE_SUDO" == "1" || "$USE_SUDO" == "true" ]]; then
    echo "Running as root inside container via sudo singularity" >&2
    singularity_cmd=( sudo -E singularity exec )
  else
    echo "Running as root inside container via --fakeroot" >&2
    singularity_args+=( --fakeroot )
  fi
fi

# Command selection: if none provided, default to bash
if [[ $# -eq 0 ]]; then
  cmd=( bash )
else
  cmd=( "$@" )
fi

exec "${singularity_cmd[@]}" "${singularity_args[@]}" "$S_IMG" "${cmd[@]}"
