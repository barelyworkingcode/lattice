---
name: leaderboard
description: Rank the lattice — top builders, the agent/model tally (Made-With), and most-built nodes — from the CONTRIBUTORS.md ledgers across every node. Use from the control when the user wants standings, "who's winning", the leaderboard, or which model built the most. Read-only, API-only, no clone. Requires gh.
---

# leaderboard

Score the lattice. Every contribution signs the node's `CONTRIBUTORS.md` in a fixed shape —
`- <handle> — <what> — <attribution> — <node>` — so the ledger is already the scoreboard. This
sweeps that one file from every node (via the Contents API, as data — **no clone**), and tallies
three boards:

- **Builders** — who landed the most accepted contributions (column 1).
- **Made-With** — which agent/model, or `human`, built the most (column 3).
- **Nodes** — which prompts attracted the most builds (column 4).

Read-only, API-only — same trust boundary as `/find-nodes`. Nothing from a node executes.

## The one trick: dedupe inherited lines

Forks copy their parent's `CONTRIBUTORS.md`, so an ancestor's lines reappear byte-for-byte in
every descendant. Counting per fetched-file would multiply old contributions by the fork count.
Each ledger line carries its *own* node in column 4, so the fix is exact: concatenate every
node's lines and `sort -u` — identical inherited copies collapse to one before any tally.

## Steps

1. Confirm `gh` is authenticated: `gh auth status`. If not, tell the user to run `gh auth login`.

2. List the nodes (forks included — every node but the genesis is a fork). `--limit 1000` is
   GitHub's search ceiling; the query warns when it hits the cap, because past it the board is
   silently incomplete:
   ```bash
   gh search repos --topic lattice-node --include-forks true --limit 1000 \
     --json fullName -q '.[].fullName' > /tmp/lb-nodes
   n=$(wc -l < /tmp/lb-nodes | tr -d ' ')
   echo "nodes: $n"
   [ "$n" -ge 1000 ] && echo "⚠️  hit GitHub's 1000-result search cap — more nodes exist than were swept. This board is INCOMPLETE and undercounts; an aggregate ledger (see Notes) is needed past this point." >&2
   ```

3. Sweep each node's `CONTRIBUTORS.md` (raw, via API) into one stream, keep only ledger lines,
   then dedupe inherited copies:
   ```bash
   : > /tmp/lb-lines
   while read -r node; do
     gh api "repos/$node/contents/CONTRIBUTORS.md" -H "Accept: application/vnd.github.raw" 2>/dev/null \
       | grep ' — ' | grep -E '^[[:space:]]*[-*]' >> /tmp/lb-lines
   done < /tmp/lb-nodes
   sort -u /tmp/lb-lines > /tmp/lb-uniq
   echo "contributions: $(wc -l < /tmp/lb-uniq | tr -d ' ')  (from $(wc -l < /tmp/lb-lines | tr -d ' ') raw lines)"
   ```

4. Render the three boards. Fields are split from the **end** so an em-dash inside the "what"
   column never shifts attribution or node:
   ```bash
   rank() { sort | uniq -c | sort -rn | awk '{c=$1; $1=""; sub(/^ +/,""); printf "  %2d. %-30s %3d\n", NR, $0, c}'; }

   echo "── BUILDERS ───────────────────────────────"
   awk -F' — ' '{h=$1; sub(/^[[:space:]]*[-*][[:space:]]*/,"",h); gsub(/^ +| +$/,"",h); print h}' /tmp/lb-uniq | rank
   echo "── MADE-WITH (agent / model) ──────────────"
   awk -F' — ' 'NF>=4{a=$(NF-1); gsub(/^ +| +$/,"",a); print a}' /tmp/lb-uniq | rank
   echo "── NODES (most-built) ─────────────────────"
   awk -F' — ' 'NF>=4{n=$NF; gsub(/^ +| +$/,"",n); print n}' /tmp/lb-uniq | rank
   ```

5. Present the standings. Default to all three boards; if the user asked for one
   (`builders` / `models` / `nodes`), show just that. Lead with the headline (top builder, top
   model). Note total contributions and node count.

## Notes

- **Self-reported.** The ledger is whatever contributors signed — the rules require the line, but
  nothing enforces it, and it's the only source carrying the *model*. For an authoritative builder
  count you can cross-check merged PRs per node (`gh pr list -R <node> --state merged`), at one
  extra call per node — but that can't attribute the model, so the ledger stays the primary source.
- **Reward breadth, not volume.** A raw count invites low-effort PRs. When it matters, weight
  distinct nodes touched over sheer line count — it tracks the spirit ("merge what runs, be kind")
  better.
- **Robust to malformed lines.** Only bullet lines containing ` — ` are counted; node/model
  tallies require all four fields (`NF>=4`), so stray prose is ignored.
- Read-only and clone-free: it fetches one text file per node via the API and computes locally.
- **Scales to the 1000-node search cap, then needs an aggregate.** This sweeps one file per node
  serially, so it's latency-bound at hundreds of nodes (parallelize the fetch when it bites) and
  blind past GitHub's 1000-result search ceiling (see `/find-nodes` Notes). The clean fix past that
  is a central aggregate updated by an **on-merge GitHub Action** in each node — the write fires on
  the trusted event (a merge), so reads become O(1) without re-sweeping the graph.
- **Keep scoring anchored to the merge.** A `CONTRIBUTORS.md` line is weak self-report but gated:
  it only lands because a node owner merged the PR. Do **not** move scoring to a source anyone can
  write without a merge (e.g. Discussion comments) — that removes the gate and lets anyone inflate
  their own count. Comments are fine for enumeration *hints* (verify each, as in `/find-nodes`) and
  for human-facing chatter, but never as the tally's source of truth.
