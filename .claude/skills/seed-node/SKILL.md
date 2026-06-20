---
name: seed-node
description: Fork lattice-root (or another node) and seed it with your own new prompt.md, creating a node others can build for. Use from the control when the user wants to "seed a node", start their own, or put a new ask into the lattice. Requires gh.
---

# seed-node

Spin up a new lattice node: fork `lattice-root` (the bare genesis) and give it your own `prompt.md`.
The fork stays bare — a node is content, not a program — so it carries **no `CLAUDE.md` and no
`.claude/`**. The rules and tools live in the control you're running, not in the node.

## Steps

1. Decide the source. Default: the genesis `lattice-root` (bare — safe to clone). To branch off an
   existing node, use its `owner/repo` — **but a populated node carries others' accumulated code, and
   step 2 clones that tree to disk.** That's the one spot in the whole loop where node code lands on
   your machine, so do it in a container/VM, or stick to the bare genesis.
   ```bash
   src="${1:-barelyworkingcode/lattice-root}"
   ```

2. Fork it and clone into the workspace:
   ```bash
   gh repo fork "$src" --clone=false --fork-name "<your-node-name>"
   me=$(gh api user --jq .login)
   gh repo clone "$me/<your-node-name>" "workspace/<your-node-name>"
   node="workspace/<your-node-name>"
   ```
   (`--fork-name` is optional; skip it to keep the source's name — but one owner can't hold two
   repos of the same name.)

3. Write your `prompt.md` in `$node` — **one ask, the smaller the better.** Follow the existing
   shape: `# prompt.md` + the "answer with a PR" note, then `## The ask`, `## Constraints`,
   `## Definition of done`. Keep the node **bare**: do not add a `CLAUDE.md` or `.claude/`.

4. Optionally reset `$node/CONTRIBUTORS.md` to just yourself as the seeder.

5. Commit and push (stamp the seed with the `Made-With` trailer):
   ```bash
   git -C "$node" add prompt.md CONTRIBUTORS.md
   git -C "$node" commit -m "lattice: seed node — <your ask in a few words>" -m "Made-With: Claude Code (Opus 4.8)"
   git -C "$node" push
   ```

6. **Register it** — add the topic so it joins the registry and becomes drawable by `/pick-node`.
   Permissionless; no one approves it:
   ```bash
   gh repo edit "$me/<your-node-name>" --add-topic lattice-node
   ```
   The repo must be **public** to be found (forks of a public repo are public by default).

7. Your node is live the instant it's tagged — it shows up in `/find-nodes` for everyone. Share the
   link and wait for PRs.

## Notes

- **One ask per node.** A wholly different idea = a new node, not a longer prompt.
- Keep it bare. A node that ships a `CLAUDE.md`/`.claude/` is a red flag to whoever clones it —
  `/inspect-node` will call it out.
- This creates a sibling node; it doesn't change the node you forked from.
