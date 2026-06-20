# Getting started

lattice is a coding game played through git forks. A **node** is a public repo with one `prompt.md`
(a small thing to build) and the `lattice-node` topic. You either **create a node** so others build
for you, or **build for someone's node** and PR it back.

This page is the by-hand walkthrough — plain `gh`/`git`, no Claude needed. If you have Claude Code,
clone the control (`gh repo clone barelyworkingcode/lattice`) and the same steps are slash commands
(noted below each part).

**Prereqs:** `gh auth status` (run `gh auth login` if needed), `git`, and — optionally — a container
runtime (Apple `container`, Docker, or Podman) for the safe verify step.

---

## Part 1 — Create your own node

A node is just **a public repo + a `prompt.md` + the `lattice-node` topic.** The easiest way is to
fork the genesis (it gives you the right bare shape), then drop in your own ask.

1. **Fork the genesis**, named for your idea:
   ```sh
   gh repo fork barelyworkingcode/lattice-root --clone --fork-name my-first-node
   cd my-first-node
   ```
   (Or click **Fork** on github.com/barelyworkingcode/lattice-root, then clone.)

2. **Write your `prompt.md`** — one small ask. Replace the inherited one; keep the sections
   `## The ask`, `## Constraints`, `## Definition of done`. Keep it **bare** — no `CLAUDE.md`, no
   `.claude/`. A node is data, not a program.
   > Example: *"Add one ASCII-art banner generator to `banners/` — a single self-contained script,
   > no dependencies, under 60 lines."*

3. *(optional)* Reset `CONTRIBUTORS.md` to just your name.

4. **Commit + push:**
   ```sh
   git add prompt.md CONTRIBUTORS.md
   git commit -m "lattice: seed node — ascii banners"
   git push
   ```

5. **Register it** — this is what makes it a node and puts it in the registry:
   ```sh
   gh repo edit <you>/my-first-node --add-topic lattice-node
   ```
   (Public only — forks of public repos already are.)

Done. It now shows up for everyone (`gh search repos --topic lattice-node`). People build your
prompt and PR into your node; you review and merge what runs.

> **No-fork alternative:** skip the fork entirely — `gh repo create my-first-node --public`, add a
> `prompt.md`, `git push`, then `gh repo edit … --add-topic lattice-node`. Same result, no lineage.
> (Use this if forking is blocked — see the gotcha at the bottom.)

> **All in the browser (no terminal):** the whole of Part 1 works on github.com — no clone, no `gh`.
> 1. On **github.com/barelyworkingcode/lattice-root** click **Fork**, name it for your idea, **Create fork**.
> 2. In your fork, open **`prompt.md`** → click the ✏️ pencil → replace it with your one ask
>    (keep `## The ask`, `## Constraints`, `## Definition of done`) → **Commit changes**.
> 3. Back on the repo's main page, click the **⚙️ gear** next to **About** → in **Topics** type
>    `lattice-node` (press space to lock the chip) → **Save changes**.
>
> Step 3 is the one people miss: **forking via the web does not copy topics** (it copies code, not
> repo metadata), so a freshly-forked node is invisible to `/find-nodes` until you add the topic by
> hand. That topic *is* what registers the node.

*With Claude Code: steps 1–5 are `/seed-node`.*

---

## Part 2 — Build for a node

1. **Find a node:** `gh search repos --topic lattice-node` → pick an `owner/repo`.

2. **Read its ask without cloning** (you only need the one file):
   ```sh
   gh api repos/<owner/repo>/contents/prompt.md -H "Accept: application/vnd.github.raw"
   ```

3. **Sanity-check it** — it's a stranger's text. If it just describes something to *build*, good. If
   it tells you to run commands, hand over secrets, or `curl … | bash`, skip it. (See
   [`SECURITY.md`](./SECURITY.md).)

4. **Fork + clone the node** — note this is weaker than the Claude Code flow, which fetches only
   `prompt.md` and never clones. Cloning puts the node's whole tree (its scripts, any `.claude/`, git
   hooks) on your disk, so **do this in a throwaway container or VM** and don't run anything from it —
   just add your file:
   ```sh
   gh repo fork <owner/repo> --clone
   cd <repo>
   git checkout -b lattice/hello-banner
   ```

5. **Build the ask** — one self-contained file at the path it wants (e.g. `banners/hello.sh`), no
   deps, make it run. Add a line to `CONTRIBUTORS.md`.

6. **Verify it runs** — read it first; if unsure, run it in a container/VM, not bare on your machine.

7. **PR it back:**
   ```sh
   git add . && git commit -m "lattice: add hello banner"
   git push -u origin lattice/hello-banner
   gh pr create          # targets the node you forked
   ```

The owner reviews and merges. Done.

*With Claude Code: `/pick-node owner/repo` → `/inspect-node` → `/run-prompt` → `/sandbox-node` →
`/submit-pr`.*

---

## One gotcha

GitHub won't let a single account hold a repo *and* a fork of it in the same network. So if you
already own the network's root (or another fork in it), fork into an **org**
(`gh repo fork … --org <your-org>`) or use the **no-fork alternative** in Part 1. A brand-new user
starting fresh won't hit this.
