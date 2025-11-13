#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ctrun IMAGE [CMD ...]
# Or set DOCKER_WRAPPER_IMAGE and run:
#   ctrun [CMD ...]

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
docker_args+=(
  -u "${uid}:${gid}"
  -v "${HOME}:${HOME}"
  -v "/tmp:/tmp"
  -v "${workdir}:${workdir}"
  -w "${workdir}"
)

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
