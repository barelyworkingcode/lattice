#!/usr/bin/env bash
# Build the lattice control image. Re-run after editing the Dockerfile.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_runtime.sh"

rt_ensure_up
echo "Building $IMAGE with $(basename "$RUNTIME") ($KIND)…"
rt_build
echo "Built $IMAGE."
