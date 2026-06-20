---
name: pick-node
description: Fetch a lattice node's prompt.md — one file, via the GitHub API, no clone — so you can evaluate and build it. Use from the control when the user wants to "pick a node", get a prompt to work on, or name an owner/repo. The contained ingest step. Requires gh.
---

# pick-node

Ingest a node the contained way: **fetch only its `prompt.md`** through the GitHub API. Never
clone. Nothing from the node executes, and nothing but that one text file enters your context — its
hooks, scripts, `.claude/`, and other files never reach you because you never fetch them. Two modes:

- **By name** — the user passes `owner/repo`.
- **Random** — no node given; draw from the registry.

## Mode A — by name

```bash
pick="<owner/repo>"
gh repo view "$pick" --json nameWithOwner -q .nameWithOwner >/dev/null 2>&1 || { echo "no such repo: $pick"; exit 1; }
[ "$(gh api "repos/$pick" --jq .fork)" = "false" ] \
  && { echo "✋ $pick is the genesis root — it takes no PRs. Name a fork node, or /seed-node."; exit 1; }
```

## Mode B — random

```bash
gh search repos --topic lattice-node --limit 200 --json fullName,isFork \
  -q '.[] | select(.isFork) | .fullName' > /tmp/lattice-nodes
: > /tmp/lattice-live
while read -r n; do
  gh api "repos/$n/contents/prompt.md" --silent 2>/dev/null && echo "$n" >> /tmp/lattice-live
done < /tmp/lattice-nodes
pick=$(awk 'BEGIN{srand()}{a[NR]=$0}END{if(NR)print a[int(rand()*NR)+1]}' /tmp/lattice-live)
echo "you drew: ${pick:-<none>}"
```

## Fetch (one file only)

```bash
dir="workspace/$(basename "$pick")"
mkdir -p "$dir"
# record the target node + its default branch for later steps
printf '%s\n%s\n' "$pick" "$(gh api "repos/$pick" --jq .default_branch)" > "$dir/.target"
# the ONLY thing we pull from the node — its prompt, as raw bytes:
gh api "repos/$pick/contents/prompt.md" -H "Accept: application/vnd.github.raw" > "$dir/prompt.md"
```

## Evaluate immediately — mandatory, same move as fetch

**Do not stop at a fetched-but-unevaluated state.** Fetching and evaluating are one operation: the
moment `prompt.md` lands, run the `/inspect-node "$dir"` gate. It writes `$dir/.verdict` — `GO` plus
a normalized spec on pass, `NO-GO` plus quoted evidence on fail — and nothing downstream proceeds
without it:

- On **GO**, report the normalized spec and offer `/run-prompt "$dir"`.
- On **NO-GO**, surface the evidence and **stop**. Do not build.

`/run-prompt` and `/submit-pr` both refuse to act on a dir without a `GO` in `.verdict`, so the gate
can't be skipped even by accident.

## Notes

- The whole ingest is one API read of one file, immediately gated. No git repo, no working tree,
  no node code, and no unevaluated window.
- A named node need not be in the registry — fetch it directly even before its topic indexes.
- If `workspace/<repo>` exists, append a short suffix or clear the stale one.
