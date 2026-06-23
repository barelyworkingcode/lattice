#!/usr/bin/env bash
# Shared config + runtime abstraction, sourced by build/start/enter.
# Supports Apple `container` (primary) and Docker / Podman (fallback).
# Override anything via the environment.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

IMAGE="${LATTICE_IMAGE:-lattice-control:latest}"
NAME="${LATTICE_CONTAINER:-lattice}"
# Non-root user inside the container (UID 1000). Required so Claude Code will
# accept `--dangerously-skip-permissions` — it refuses to run as root.
GUEST_USER="${LATTICE_GUEST_USER:-node}"
# Persistent home (Claude + gh + git auth) — bind-mounted at /home/node inside.
HOME_DIR="${LATTICE_HOME_DIR:-$HOME/.lattice-container/home}"
GUEST_HOME="/home/node"

# --- runtime detection ------------------------------------------------------
RUNTIME="${LATTICE_CONTAINER_RUNTIME:-}"
if [ -z "$RUNTIME" ]; then
  RUNTIME="$(command -v container || command -v docker || command -v podman || true)"
fi
if [ -z "$RUNTIME" ]; then
  cat >&2 <<'EOF'
No container runtime found. Install one, then re-run:

  Apple container  brew install --cask container          (https://github.com/apple/container)
  Docker Desktop   https://www.docker.com/products/docker-desktop/
  Colima           brew install colima docker && colima start
  Podman           brew install podman && podman machine init && podman machine start

Or set LATTICE_CONTAINER_RUNTIME=/path/to/runtime.
EOF
  exit 1
fi

case "$(basename "$RUNTIME")" in
  container) KIND=apple ;;   # Apple container CLI
  *)         KIND=docker ;;  # docker + podman share the surface
esac

# --- operations (dispatch on KIND) ------------------------------------------

rt_ensure_up() {           # make sure the runtime's services/daemon are live
  if [ "$KIND" = apple ]; then
    if ! "$RUNTIME" system status 2>/dev/null | grep -q 'running'; then
      echo "Starting container services…"
      "$RUNTIME" system start
    fi
  else
    "$RUNTIME" info >/dev/null 2>&1 || {
      echo "Container daemon not reachable — start Docker/Colima/Podman first." >&2
      exit 1
    }
  fi
}

rt_image_exists() { "$RUNTIME" image inspect "$IMAGE" >/dev/null 2>&1; }

rt_build() { "$RUNTIME" build -t "$IMAGE" -f "$HERE/Dockerfile" "$HERE"; }

rt_container_exists() {
  if [ "$KIND" = apple ]; then "$RUNTIME" inspect "$NAME" >/dev/null 2>&1
  else "$RUNTIME" container inspect "$NAME" >/dev/null 2>&1; fi
}

rt_container_running() {
  if [ "$KIND" = apple ]; then
    "$RUNTIME" list --quiet 2>/dev/null | grep -qx "$NAME"
  else
    "$RUNTIME" ps --format '{{.Names}}' 2>/dev/null | grep -qx "$NAME"
  fi
}

rt_create() {              # create + start the permanent container
  mkdir -p "$HOME_DIR"
  if [ "$KIND" = apple ]; then
    # Apple container has no restart policy; start.sh/enter.sh start on demand.
    "$RUNTIME" run -d --name "$NAME" --user "$GUEST_USER" \
      -v "$HOME_DIR:$GUEST_HOME" \
      -v "$REPO:/lattice" \
      -w /lattice \
      "$IMAGE" sleep infinity >/dev/null
  else
    "$RUNTIME" run -d --name "$NAME" --restart unless-stopped --user "$GUEST_USER" \
      -v "$HOME_DIR:$GUEST_HOME" \
      -v "$REPO:/lattice" \
      -w /lattice \
      "$IMAGE" sleep infinity >/dev/null
  fi
}

rt_start() { "$RUNTIME" start "$NAME" >/dev/null; }

rt_exec() {                # interactive: rt_exec [cmd...]  (default: login shell)
  if [ "$#" -gt 0 ]; then
    exec "$RUNTIME" exec -it --user "$GUEST_USER" -w /lattice -e HOME="$GUEST_HOME" "$NAME" "$@"
  fi
  exec "$RUNTIME" exec -it --user "$GUEST_USER" -w /lattice -e HOME="$GUEST_HOME" "$NAME" bash -l
}
