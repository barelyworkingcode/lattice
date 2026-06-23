# lattice in a container

A permanent container to run the whole lattice loop off your host — the hard
isolation boundary `CLAUDE.md` and `SECURITY.md` recommend. It ships **Claude
Code**, the **GitHub CLI**, **git**, and **python3** (the `gate.py` hook). You
authenticate *inside* the container; your credentials persist on the host.

Built for **Apple `container`** (the detected runtime here); **Docker** and
**Podman** also work via the same scripts.

## Three scripts

| Script | What it does |
| --- | --- |
| `build.sh` | Build the image (`lattice-control:latest`). Re-run after editing the Dockerfile. |
| `start.sh` | Create the permanent container (builds first if needed), or start it if it exists. Idempotent. |
| `enter.sh` | Drop into a shell inside it (starts it first if stopped). |

```sh
./container/start.sh     # one time: builds + creates the container
./container/enter.sh     # whenever you want in
```

## Authenticate (once, inside the container)

```sh
./container/enter.sh

# Claude Code — pick "Claude account", open the printed URL on your Mac,
# approve, paste the code back into the terminal.
claude

# GitHub — device flow gives you a code to type at github.com/login/device.
gh auth login          # GitHub.com → HTTPS → "Login with a web browser"
gh auth setup-git      # let git push with gh's token

# git identity for your commits
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

The container runs as the non-root **`node`** user, and `/home/node` is
bind-mounted to `~/.lattice-container/home` on your Mac. So `~/.claude`,
`~/.claude.json`, `~/.config/gh`, and `~/.gitconfig` live on the host and
**persist** across restarts, recreation, and rebuilds. (Running non-root is
deliberate — Claude Code refuses `--dangerously-skip-permissions` as root, so a
non-root user is what lets you run it that way *inside* the box. The
container/VM is still the isolation boundary; on macOS the runtime's
file-sharing layer lets `node` write the host bind-mounts regardless of their
on-disk ownership.)

## Run the loop

The repo is bind-mounted at `/lattice`, so edits on your Mac show up inside and
vice-versa. Fetched node prompts land in `/lattice/workspace` (gitignored).

```sh
./container/enter.sh
claude          # then: /find-nodes, /pick-node, /run-prompt, /submit-pr …
# or jump straight in:
./container/enter.sh claude
```

Because the container runs as the non-root `node` user, you can let Claude run
unattended inside this already-isolated box:

```sh
./container/enter.sh claude --dangerously-skip-permissions
```

Only do that *inside* the container — the whole point of the box is that a
poisoned node still can't reach your host. Don't pass that flag on the Mac.

## "Permanent" on Apple container

Apple `container` has no restart policy, so the container doesn't auto-start on
boot. It does persist (it's never deleted), and `start.sh` / `enter.sh` bring it
back up on demand — so day to day you just run `./container/enter.sh`. On Docker
and Podman the scripts add `--restart unless-stopped`, which auto-starts it.

If `container system status` isn't `running` after a reboot, the scripts run
`container system start` for you.

## Notes & overrides

- **`/sandbox-node` won't work inside here.** It wants to launch a nested
  throwaway container, which would need the host runtime socket — deliberately
  not exposed, since that would punch through the isolation. Running the whole
  loop in this container already gives you the recommended boundary; rely on a
  self-contained artifact + PR review as the backstop.
- **Override via env:** `LATTICE_IMAGE`, `LATTICE_CONTAINER`, `LATTICE_HOME_DIR`,
  `LATTICE_GUEST_USER`, `LATTICE_CONTAINER_RUNTIME`.
- **Update Claude Code:** `./container/enter.sh npm update -g @anthropic-ai/claude-code`
  (works non-root — the image hands the npm global tree to `node` at build time).
- **Upgrading an existing (root) container?** The guest home moved from `/root`
  to `/home/node`, so rebuild and recreate once:
  `container rm -f lattice && ./container/build.sh && ./container/start.sh`. Your
  auth in `~/.lattice-container/home` carries over unchanged — they're the same
  `.claude` / `.config/gh` / `.gitconfig` files, just mounted at the new home.
- **Rebuild from scratch:** `container rm -f lattice && ./container/build.sh && ./container/start.sh`
  (your auth in `~/.lattice-container/home` survives this).
- **Tear down completely:** `container rm -f lattice` and delete
  `~/.lattice-container/home` to wipe the saved credentials.
