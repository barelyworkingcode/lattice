# lattice — permanent control container
#
# Runs the whole lattice loop off your host — the hard isolation boundary
# CLAUDE.md/SECURITY.md recommend. Ships Claude Code, the GitHub CLI, git, and
# python3 (the .claude/hooks/gate.py backstop). You authenticate *inside* the
# running container; creds persist in the bind-mounted home (see start.sh).
#
# Runs as root on purpose: the isolation boundary is the container/VM, not an
# in-container user, and root sidesteps every host bind-mount ownership quirk
# across Apple `container`, Docker, and Podman.
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
RUN npm install -g @anthropic-ai/claude-code

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NODE_NO_WARNINGS=1

# Trust the bind-mounted repo regardless of UID mapping. System-level, so it
# holds even though /root is replaced by the persistent home bind mount.
RUN git config --system --add safe.directory /lattice \
    && git config --system init.defaultBranch main

WORKDIR /lattice
CMD ["sleep", "infinity"]
