---
name: find-nodes
description: List every live lattice node from the registry (repos carrying the lattice-node topic) with its prompt and lineage. Use from the control when the user wants to "see the lattice", find a node to build for, or map the network. Read-only. Requires gh authenticated.
---

# find-nodes

List the live nodes of the lattice and what each wants built. Membership is the **registry** —
every public repo carrying the `lattice-node` topic — so this is one search, no fork-graph crawl,
and no one approves who's listed. Read-only: it clones and modifies nothing.

Run this from the control repo. (The control itself is not a node and won't appear — it isn't
tagged.)

## Steps

1. Confirm `gh` is authenticated: `gh auth status`. If not, tell the user to run `gh auth login`.

2. Pull the registry — every node, newest-active first. **`--include-forks true` is
   load-bearing:** every node except the genesis is a fork of `lattice-root`, and GitHub's
   search API drops forks by default — without it you get back only the root. `--limit 1000` is
   the ceiling GitHub's search API allows; past that the registry is *silently* truncated, so the
   query warns when it lands on the cap.
   ```bash
   gh search repos --topic lattice-node --include-forks true --limit 1000 \
     --json fullName,description,url,pushedAt,isFork \
     -q 'sort_by(.pushedAt) | reverse | .[].fullName' > /tmp/lattice-nodes
   n=$(wc -l < /tmp/lattice-nodes | tr -d ' ')
   echo "registry: $n nodes"
   [ "$n" -ge 1000 ] && echo "⚠️  hit GitHub's 1000-result search cap — the lattice is larger than this list and topic search cannot enumerate the rest. This view is INCOMPLETE; a central registry (see Notes) is needed past this point." >&2
   ```

3. For each node, show the ask and lineage; flag the read-only genesis:
   ```bash
   while read -r node; do
     # Ask = first line under "## The ask"; fall back to the first non-heading,
     # non-blank line so free-form prompts (not the lattice-root template) still resolve.
     ask=$(gh api "repos/$node/contents/prompt.md" -H "Accept: application/vnd.github.raw" 2>/dev/null \
       | awk '
           /^## The ask/ {f=1; next}
           f && NF {ask=$0; exit}
           !first && NF && $0 !~ /^#/ {first=$0}
           END { line = (ask != "" ? ask : first);
                 if (length(line) > 100) line = substr(line,1,99) "…";
                 print line }')
     read -r isfork parent < <(gh api "repos/$node" --jq '[.fork, (.parent.full_name // "—")] | @tsv' 2>/dev/null)
     [ "$isfork" = "false" ] && tag="genesis · read-only (no PRs)" || tag="forked from $parent"
     printf '%s — %s — %s\n' "$node" "${ask:-(no prompt)}" "$tag"
   done < /tmp/lattice-nodes
   ```

4. Present a compact list, one line per node. Flag `(no prompt)` as dormant and the genesis as
   read-only. To go build something, hand off to `/pick-node`.

## Notes

- The registry is GitHub's topic search across the whole fork field — but only with
  `--include-forks true`. Forks are excluded by default, and since nodes spread *by* forking
  `lattice-root`, the default query hides the entire lattice and returns just the genesis. If a
  run ever comes back with only the root, this flag is the first thing to check.
- Not every node follows the `lattice-root` template. The ask is read from a `## The ask`
  heading when present, otherwise from the first real line of `prompt.md`, so off-template prompts
  still resolve. `(no prompt)` now means the file is genuinely missing or empty — a dormant node.
- The search API and the `lattice-node` topic web page use different indexes. The web page can
  show a node the search API hasn't picked up yet — indexing lag runs minutes to hours, and a
  brand-new owner/org can be absent from the search index longer. The fork graph is immediate, so
  `/pick-node owner/repo` works by name even before a node indexes.
- **The 1000-node ceiling is architectural, not a flag.** GitHub topic search returns at most 1000
  results, ever — `--limit 1000` is the max, and pagination can't exceed it. "The search index *is*
  the registry" holds up to ~1000 nodes; past that, enumeration (this skill, `/leaderboard`, random
  `/pick-node`) goes silently incomplete. The fix is a *central list* nodes self-register in (a
  pinned issue, a Discussion, or a file) to dodge the cap — but that list is an untrusted **hint**,
  not truth: verify each claimed repo by **direct** lookup (`gh api repos/{owner}/{name}` — not
  search, so no cap) and confirm it's public, carries `lattice-node`, and is a real fork before
  trusting it. The topic tag on a repo you control stays the authenticity anchor; the list only
  points. A registered entry can *claim* a repo its poster doesn't own — verification is what drops
  the fakes.
