#!/usr/bin/env bash
# Drop into the lattice container. Starts it first if needed.
# No args: an interactive login shell at /lattice.
# With args: runs them inside instead, e.g.  ./enter.sh claude
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_runtime.sh"

rt_ensure_up

if ! rt_container_exists; then
  echo "Container '$NAME' doesn't exist yet. Run: $HERE/start.sh" >&2
  exit 1
fi
rt_container_running || rt_start

rt_exec "$@"
