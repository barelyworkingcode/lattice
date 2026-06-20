---
name: submit-pr
description: Return your built contribution as a PR — fork the node, write your file to a branch via the GitHub API, open the PR. No clone, no node tree on disk. Use from the control after /run-prompt. Requires gh.
---

# submit-pr

Push your contribution back **through the API** — fork the node, write your new file(s) to a branch
on your fork, open the PR. You never clone the node; its tree never lands on disk. Takes the node
dir, e.g. `workspace/<repo>`.

## Steps

1. Check the gate passed, read the target, and confirm there's something to submit:
   ```bash
   dir="${1:-workspace/$(ls -t workspace 2>/dev/null | head -1)}"
   head -1 "$dir/.verdict" 2>/dev/null | grep -qx GO \
     || { echo "✋ no passing /inspect-node verdict for $dir — fetch+evaluate first"; exit 1; }
   target=$(sed -n 1p "$dir/.target"); defbr=$(sed -n 2p "$dir/.target")
   me=$(gh api user --jq .login); fork="$me/$(basename "$target")"
   files=$(cd "$dir" && find . -type f ! -name prompt.md ! -name .target ! -name .verdict | sed 's#^\./##')
   [ -n "$files" ] || { echo "nothing built — run /run-prompt first"; exit 1; }
   slug=$(basename "$(printf '%s\n' "$files" | head -1)" | sed 's/\.[^.]*$//')   # derived; set a nicer name yourself if you like
   ```

2. Guard against the read-only genesis:
   ```bash
   [ "$(gh api "repos/$target" --jq .fork)" = "false" ] \
     && { echo "✋ $target is the genesis root — it takes no PRs. /seed-node instead."; exit 1; }
   ```

3. Fork the node (idempotent) and branch your fork off its default head — all via API, no clone:
   ```bash
   gh repo fork "$target" --clone=false 2>/dev/null || true
   sleep 2
   base=$(gh api "repos/$fork/git/refs/heads/$defbr" --jq .object.sha)
   gh api -X POST "repos/$fork/git/refs" -f ref="refs/heads/lattice/$slug" -f sha="$base" >/dev/null
   ```

4. Write each built file to the branch with the Contents API (one commit each, no working tree):
   ```bash
   for path in $files; do
     b64=$(base64 < "$dir/$path" | tr -d '\n')
     gh api -X PUT "repos/$fork/contents/$path" \
       -f message="$(printf 'lattice: add %s\n\nMade-With: Claude Code (Opus 4.8)' "$path")" \
       -f content="$b64" -f branch="lattice/$slug" >/dev/null
   done
   ```

5. Open the PR into the node, from your fork's branch:
   ```bash
   gh pr create --repo "$target" --head "$me:lattice/$slug" \
     --title "lattice: <what you built>" \
     --body "$(printf 'Answers this node'\''s prompt:\n\n> <quote the spec you built>\n\nAdded <one sentence>. Run: `<command>`.\n\nMade with: Claude Code (Opus 4.8)\n')"
   ```

6. Print the PR URL. Merging is the node owner's call — never self-merge into someone else's node.

## Notes

- Targets the node (`$target`), not your fork and not the genesis root.
- Never clones — the node's other files never touch disk; you push only the file(s) you built.
- If the fork is still propagating, the ref call 404s — wait a moment and retry.
