---
name: retire-node
description: Remove a node you own from the lattice network by dropping its lattice-node topic. Use from the control when the prompt has been answered, the node is abandoned, or the owner wants out. Unlists from the registry; does not delete the repo. Requires gh with admin on the node.
---

# retire-node

Take a node out of the network. Membership **is** the `lattice-node` topic, so a node leaves the
registry the instant its owner removes that topic — it stops showing in `/find-nodes` and stops
being drawable by `/pick-node`. The repo, its `prompt.md`, its merged contributions, and its place
in the fork graph all stay; it's an unlisting, not a deletion.

Use this when a node's prompt has been answered to the owner's satisfaction, the node is abandoned,
or the owner just wants out. Only the **owner** can do it — topic edits need admin on the repo —
so you can only retire your own nodes.

## Steps

1. Confirm `gh` is authenticated: `gh auth status`. If not, tell the user to run `gh auth login`.

2. Name the node to retire — `owner/repo` (required; this acts on one specific node):
   ```bash
   node="<owner/repo>"
   ```

3. Pre-flight — read the node's state and gate on it. Refuse in three cases below:
   ```bash
   read -r isfork admin tagged < <(gh api "repos/$node" \
     --jq '[.fork, .permissions.admin, ([.topics[] | select(. == "lattice-node")] | length > 0)] | @tsv' 2>/dev/null)
   echo "node=$node fork=$isfork admin=$admin tagged=$tagged"
   ```
   - **Not tagged (`tagged=false`)** — it isn't in the registry. Nothing to retire; stop.
   - **No admin (`admin=false`)** — you don't own it. `gh repo edit` would fail; stop and say so.
   - **Genesis (`fork=false`)** — this is a non-fork genesis root (e.g. `lattice-root`). Retiring it
     unlists the root of a whole lineage. **Refuse by default** — confirm explicitly with the user
     that they really mean to delist a genesis before continuing.

4. Confirm with the user before mutating — it changes a public repo. State plainly: this unlists
   `$node` from the registry, leaves the repo and all merged work intact, and is reversible by
   re-adding the topic. Wait for a yes.

5. Remove the topic:
   ```bash
   gh repo edit "$node" --remove-topic lattice-node
   ```

6. Verify it's gone from the registry (topic search is the registry — note the index can lag a few
   minutes, so also confirm the topic is off the repo directly):
   ```bash
   gh api "repos/$node" --jq '.topics'                 # lattice-node should be absent
   gh search repos --topic lattice-node --include-forks true --limit 200 --json fullName \
     -q '.[].fullName' | grep -qx "$node" && echo "still indexed (lag)" || echo "delisted"
   ```

## Notes

- **Reversible.** To bring a node back, re-add the topic: `gh repo edit "$node" --add-topic lattice-node`.
- **This is not a delete.** The repo, prompt, contributions, and fork lineage survive — the node is
  just no longer listed. To actually destroy a repo, that's `gh repo delete` (destructive, out of
  scope; never run it as part of retiring).
- **Open PRs are untouched.** Retiring doesn't close pending PRs into the node; resolve those
  separately if you want them gone.
- **Pairs with `/seed-node`.** Seed adds the `lattice-node` topic to put a node in; retire removes
  it to take a node out. Same control, opposite direction.
