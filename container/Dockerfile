# lattice — permanent control container
#
# Runs the whole lattice loop off your host — the hard isolation boundary
# CLAUDE.md/SECURITY.md recommend. Ships Claude Code, the GitHub CLI, git, and
# python3 (the .claude/hooks/gate.py backstop). You authenticate *inside* the
# running container; creds persist in the bind-mounted home (see start.sh).
#
# Runs as the non-root `node` user (UID 1000) the base image ships. Claude Code
# refuses `--dangerously-skip-permissions` as root, so a non-root user is what
# unlocks running it that way *inside* the box. The container/VM is still the
# isolation boundary; dropping root is just what the flag requires. On macOS
# (Apple `container`, Docker Desktop, Podman machine) the file-sharing layer
# lets this user write host bind-mounts regardless of their on-disk ownership,
# so the old "root sidesteps mount quirks" reasoning doesn't bite here.
FROM node:22-bookworm-slim

# --- base tooling -----------------------------------------------------------
# git: submit-pr / seed-node.  python3: the PreToolUse gate hook.  ripgrep/jq:
# used by skills and handy in a shell.  curl/gnupg/ca-certificates: gh apt repo.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git python3 \
        ripgrep jq less nano \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI (official apt repo) -----------------------------------------
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- Claude Code ------------------------------------------------------------
# Install globally as root, then hand the npm global tree to `node` so the
# non-root user can self-update later (`npm update -g @anthropic-ai/claude-code`).
RUN npm install -g @anthropic-ai/claude-code \
    && chown -R node:node /usr/local/lib/node_modules /usr/local/bin

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NODE_NO_WARNINGS=1

# Trust the bind-mounted repo regardless of UID mapping. System-level (/etc/
# gitconfig), so it applies to every user even though the home dir is replaced
# by the persistent bind mount.
RUN git config --system --add safe.directory /lattice \
    && git config --system init.defaultBranch main

# Drop to the non-root user the base image ships (UID 1000, home /home/node).
# This is what lets `claude --dangerously-skip-permissions` run inside the box.
USER node

WORKDIR /lattice
CMD ["sleep", "infinity"]
