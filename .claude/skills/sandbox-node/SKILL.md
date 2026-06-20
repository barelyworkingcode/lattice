---
name: sandbox-node
description: Run a freshly built artifact inside a throwaway container with no credentials and no network, to verify it works without executing it on your host. The optional execute-only verifier. Use after /run-prompt and before /submit-pr when you want the run step off your machine. Needs container/docker/podman.
---

# sandbox-node (execute-only)

The whole loop runs on your host under your own Claude subscription — fetch, gate, build, submit.
There's exactly **one** moment that executes code: *running the artifact to check it works.* This
skill moves that one moment into a disposable container with **no credentials, no network, and
nothing of yours mounted but the one built file, read-only** — so it never runs on your host.

Optional. A self-contained toy you built from a vetted spec is low-risk, and the node owner reviews
the PR. Reach for this when you want the run step airtight. Takes the node dir, e.g. `workspace/<repo>`
(must have a `GO` verdict and a built artifact).

## Steps

1. Find the built artifact and its run command (from its `# run:` header):
   ```bash
   dir="${1:-workspace/$(ls -t workspace 2>/dev/null | head -1)}"
   head -1 "$dir/.verdict" 2>/dev/null | grep -qx GO || { echo "✋ no GO verdict for $dir"; exit 1; }
   art=$(cd "$dir" && find . -type f ! -name prompt.md ! -name .target ! -name .verdict | sed 's#^\./##' | head -1)
   [ -n "$art" ] || { echo "nothing built — run /run-prompt first"; exit 1; }
   runcmd=$(sed -n '1,3p' "$dir/$art" | grep -m1 -iE 'run:' | sed -E 's/.*run:[[:space:]]*//')
   echo "artifact: $art   run: ${runcmd:-<infer from extension>}"
   ```

2. Pick a runtime and a **stock** base image for the artifact's language (no custom build):
   ```bash
   if   command -v container >/dev/null; then rt=container   # Apple: per-container VM
   elif command -v docker    >/dev/null; then rt=docker
   elif command -v podman    >/dev/null; then rt=podman
   else echo "need container (Apple), docker, or podman"; exit 1; fi
   case "$art" in
     *.py)        img=python:3-slim ;;
     *.js|*.mjs)  img=node:22-slim ;;
     *)           img=debian:stable-slim ;;   # bash/sh and friends
   esac
   ```

3. Run it — **no creds, no network, read-only, ephemeral**:
   ```bash
   "$rt" run --rm --network none -v "$PWD/$dir:/work:ro" -w /work "$img" \
     bash -lc "${runcmd:-bash $art}"
   ```
   `--network none` → the artifact literally cannot phone home. `:ro` → it cannot touch your files.
   `--rm` → it's gone after. (Apple `container` flag names can vary; if `--network none` is rejected,
   drop it — the read-only mount + ephemeral VM still hold.)

4. Show the output. If it satisfies the spec, hand off to `/submit-pr`. If it errors, fix the
   artifact on the host and re-run.

## Notes

- **Free, with one prerequisite.** Nothing is billed — no API key, no token, just local CPU/RAM (no
  Claude runs in here; it only *executes* the file). The one requirement is a container runtime
  (Apple `container`, Docker, or Podman) installed once; the first run pulls a small stock base image,
  then it's cached. It runs locally but walled off (own VM/namespace, read-only mount, network off) —
  "off your host," not on a remote server.
- **No credential ever enters this container.** It only runs code; it never pushes. Submitting is the
  host's job (`/submit-pr`) with your existing `gh` — so you keep using your subscription and add no
  new auth.
- It mounts only the one node dir, read-only; nothing else of your host is visible, and with the
  network off there's nowhere for a misbehaving artifact to send anything.
- For a toy that must write output, add a writable tmpfs/scratch path — but prefer toys that print to
  stdout.
