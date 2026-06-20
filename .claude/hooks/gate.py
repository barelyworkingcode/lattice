#!/usr/bin/env python3
"""lattice gate — harness-level enforcement of evaluate-before-build.

A PreToolUse hook. Blocks any write into a node's workspace dir
(`workspace/<node>/...`) unless that dir holds a passing verdict
(`workspace/<node>/.verdict` whose first line is `GO`), which `/inspect-node`
writes the moment `/pick-node` fetches the node's prompt.md.

This is defense-in-depth, not an airtight wall, and not the primary control.
The launder (a no-tools classifier the acting agent can't be steered through) is
what actually stops an adversarial prompt; this hook is a backstop, and the real
containment for the run step is a container/VM. Known, deliberate limits:

- File-editing tools (Write/Edit/MultiEdit/NotebookEdit): the path check is
  exact and anchored to the node root. The three bookkeeping names the loop must
  write before a verdict exists (.verdict/.target/prompt.md) are exempt only at
  `workspace/<node>/<name>` (depth 2), never deeper. Because `.verdict` itself
  has to be writable there, a steered agent could still forge one — the hook
  cannot tell a real verdict from a forged one. Treat it as best-effort.
- Bash: best-effort detection of literal `workspace/<node>/<file>` write
  patterns. Interpreter writers (python3 -c, node -e, heredocs) and shell
  indirection (variables, evals) evade it. The container is the real containment.

Contract: read the tool call as JSON on stdin. Exit 0 allow, exit 2 block
(stderr is shown to the agent). Anything that isn't a build-write is allowed;
an error while evaluating a build-write fails closed (block), not open.
"""
import json
import os
import re
import sys

# Bookkeeping files the loop legitimately writes before/around a verdict.
# Exempt ONLY at the node root (workspace/<node>/<name>), never in a subdir.
ALLOW_NAMES = {".verdict", ".target", "prompt.md"}


def has_go(base: str, node: str) -> bool:
    try:
        with open(os.path.join(base, "workspace", node, ".verdict"), encoding="utf-8") as fh:
            return fh.readline().strip() == "GO"
    except Exception:
        return False  # missing, unreadable, or non-UTF8 verdict => no GO => block (fail closed)


def deny(msg: str) -> int:
    sys.stderr.write(
        "lattice gate: %s\nRun /pick-node (it fetches and evaluates in one move) or "
        "/inspect-node to (re)gate. A node must earn a GO before anything builds.\n" % msg
    )
    return 2


def gate_path(path: str, base: str) -> int:
    target = os.path.abspath(path)
    parts = os.path.relpath(target, base).split(os.sep)
    if len(parts) < 2 or parts[0] != "workspace":
        return 0
    node = parts[1]
    # Bookkeeping names are exempt only at the node root — workspace/<node>/<name>,
    # i.e. exactly three path parts — so a build can't pose as prompt.md/.verdict deeper in.
    root_bookkeeping = len(parts) == 3 and parts[2] in ALLOW_NAMES
    if root_bookkeeping or has_go(base, node):
        return 0
    return deny("refusing to write %s — no passing verdict for workspace/%s"
                % (os.path.relpath(target, base), node))


# Tokens that indicate the command writes a file, and references to a node subpath.
WRITE_HINT = re.compile(
    r">>?|\btee\b|\bcp\b|\bmv\b|\binstall\b|\bdd\b|\btouch\b|\bmkdir\b|\brsync\b|"
    r"\bln\b|--in-place|\bchmod\b|\bsed\b[^\n|]*\s-i\b"
)
WS_REF = re.compile(r"workspace/([^/\s'\"`;|&()]+)/([^\s'\"`;|&()]+)")


def gate_bash(cmd: str, base: str) -> int:
    if not WRITE_HINT.search(cmd):
        return 0
    offenders = []
    for node, sub in WS_REF.findall(cmd):
        if sub in ALLOW_NAMES:  # exempt only a root-level bookkeeping file, not <subdir>/<name>
            continue
        if not has_go(base, node):
            offenders.append("workspace/%s/%s" % (node, sub))
    if offenders:
        return deny("refusing a shell write into an unevaluated node (%s)"
                    % ", ".join(sorted(set(offenders))))
    return 0


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # unparseable stdin comes from the harness, not a node; don't wedge the session
    base = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}
    try:
        if tool == "Bash":
            return gate_bash(tool_input.get("command") or "", base)
        path = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
        return gate_path(path, base) if path else 0
    except Exception as exc:
        # A parsed build-write we couldn't evaluate fails closed, not open.
        return deny("gate evaluation error (%s) — failing closed" % type(exc).__name__)


if __name__ == "__main__":
    sys.exit(main())
