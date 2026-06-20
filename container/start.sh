#!/usr/bin/env bash
# Create the permanent lattice container (or start it if it already exists).
# Builds the image first if it's missing. Idempotent — safe to run repeatedly.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_runtime.sh"

rt_ensure_up

if ! rt_image_exists; then
  "$HERE/build.sh"
fi

if rt_container_exists; then
  if rt_container_running; then
    echo "Container '$NAME' already running."
  else
    echo "Starting existing container '$NAME'…"
    rt_start
  fi
  echo "Enter it with: $HERE/enter.sh"
  exit 0
fi

echo "Creating permanent container '$NAME' ($KIND)…"
echo "  home (persistent auth): $HOME_DIR  ->  $GUEST_HOME"
echo "  repo:                   $REPO  ->  /lattice"
rt_create

echo
echo "Up. Enter it with: $HERE/enter.sh"
echo "Authenticate inside:  claude   ·   gh auth login && gh auth setup-git"
