#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ctrun IMAGE [CMD ...]
# Or set DOCKER_WRAPPER_IMAGE and run:
#   ctrun [CMD ...]
#
# Environment variables:
#   DOCKER_WRAPPER_IMAGE          - Default image to use
#   DOCKER_WRAPPER_ENV_WHITELIST  - Space-separated list of env vars to pass through
#   DOCKER_WRAPPER_RUN_AS_ROOT    - Set to "1" or "true" to run as root (no uid/gid mapping)
#   DOCKER_WRAPPER_MOUNTS         - Colon-separated list of additional mounts (e.g., "/host/path:/container/path:/another:/mount")

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

# Optional: additional mounts
EXTRA_MOUNTS="${DOCKER_WRAPPER_MOUNTS:-}"

uid="$(id -u)"
gid="$(id -g)"
workdir="$PWD"

docker_args=( run --rm )

# Force entrypoint override EVERY TIME
docker_args+=( --entrypoint "" )

# TTY behavior
if [ -t 0 ]; then
  docker_args+=( -it )
else
  docker_args+=( -i )
fi

# User + mounts
if [[ "$RUN_AS_ROOT" == "1" || "$RUN_AS_ROOT" == "true" ]]; then
  # Run as root - no user mapping
  echo "Running as root inside container (no user mapping)" >&2
  docker_args+=(
    -v "${HOME}:${HOME}"
    -v "/tmp:/tmp"
    -v "${workdir}:${workdir}"
    -w "${workdir}"
  )
else
  # Normal user mapping
  docker_args+=(
    -u "${uid}:${gid}"
    -v "${HOME}:${HOME}"
    -v "/tmp:/tmp"
    -v "${workdir}:${workdir}"
    -w "${workdir}"
  )
fi

# Additional mounts
if [[ -n "$EXTRA_MOUNTS" ]]; then
  IFS=':' read -ra MOUNTS <<< "$EXTRA_MOUNTS"
  i=0
  while [ $i -lt ${#MOUNTS[@]} ]; do
    if [ $((i + 1)) -lt ${#MOUNTS[@]} ]; then
      docker_args+=( -v "${MOUNTS[$i]}:${MOUNTS[$((i+1))]}" )
      i=$((i + 2))
    else
      echo "Warning: Ignoring incomplete mount specification: ${MOUNTS[$i]}" >&2
      break
    fi
  done
fi

# Basic env
docker_args+=(
  -e "HOME=${HOME}"
  -e "USER=${USER}"
)

[ -n "${TERM-}" ] && docker_args+=( -e "TERM=${TERM}" )
[ -n "${LANG-}" ] && docker_args+=( -e "LANG=${LANG}" )
[ -n "${LC_ALL-}" ] && docker_args+=( -e "LC_ALL=${LC_ALL}" )

# Extra env pass-through
if [[ -n "$ENV_WHITELIST" ]]; then
  for name in $ENV_WHITELIST; do
    val="${!name-}"
    if [[ -n "$val" ]]; then
      docker_args+=( -e "${name}=${val}" )
    fi
  done
fi

# Image last
docker_args+=( "$IMAGE" )

# If no args passed, open an interactive shell inside container
if [[ $# -eq 0 ]]; then
  docker_args+=( bash )
else
  # The FIRST arg is ALWAYS treated as the command (overrides entrypoint)
  docker_args+=( "$@" )
fi

exec docker "${docker_args[@]}"
