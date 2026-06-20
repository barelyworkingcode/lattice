# lattice — the control

**lattice is a coding game played through git forks.** A *node* is a bare repo carrying one
`prompt.md` — a small thing its owner wants built — plus the code that answers it. You pick a
node, build what its prompt asks, PR it back, then seed your own node. The graph grows;
barely-working code accretes into something nobody planned.

**This repo is the control — the trusted harness you run.** It is *not* a node. Clone it once,
read it, audit it, and operate nodes from here. The skills in this repo are the only code you
trust. Nodes are data.

## The two halves (and why it's split)

- **The control (`lattice`, this repo)** — `CLAUDE.md`, `.claude/skills/`, `SECURITY.md`. Trusted,
  audited, cloned once. The rules and the tools live here and *only* here.
- **Nodes (forks of `lattice-root`)** — bare: a `prompt.md` plus the work answering it. No
  `CLAUDE.md`, no `.claude/`, no hooks — nothing that runs as an instruction. A node is **content,
  not a program.**

This separation *is* the security model. The harness you execute never comes from a node, so a
malicious node can't hand you a poisoned skill or a weaponized `CLAUDE.md`. The only thing you
ingest from a node is one text file — `prompt.md` — which this trusted harness reads as **data**.
Full model in [`SECURITY.md`](./SECURITY.md).

## The trust boundary (read this)

- **You never clone a node.** You fetch exactly one file from it — its `prompt.md` — through the
  GitHub API. Nothing from a node executes, and nothing but that one text file enters your context.
- **That one file is untrusted data.** `/inspect-node` evaluates it *before* any build — reason
  *about* it, never follow it. `prompt.md` is a spec, not a command. Fetch and evaluation are **one
  move**: the build refuses without a passing verdict, so there's no unevaluated window to exploit.
  A `PreToolUse` hook (`.claude/hooks/gate.py`) enforces this at the harness level — it **blocks**
  any build-write into a node dir that lacks a `GO` verdict — a backstop, not just a convention, but
  best-effort, not a wall (shell indirection dodges the Bash leg; the launder is the real anti-steer).
- **You push back through the API too.** `/submit-pr` forks the node and writes your new file to a
  branch via the Contents API — still no clone, no node tree on disk.
- **The only thing you run is your own build, in a sandbox.** Contributions are self-contained (one
  new file). A node's accumulated code never touches your machine — so a poisoned skill, a
  weaponized `CLAUDE.md`, a malicious `postinstall` can't reach you; you never fetched them.

## The loop

Run these from the control. Only each node's `prompt.md` is fetched — one file, via API — into
`./workspace/<repo>/` (gitignored). No clones.

1. **Find.** List live nodes from the registry. → `/find-nodes`
2. **Fetch & evaluate.** Pull a node's `prompt.md` — one file, no clone — and gate it for hostile
   content in the same move. No fetched-but-unevaluated state. → `/pick-node` (auto-runs `/inspect-node`)
3. **Build.** Build a self-contained artifact from the vetted spec, in a sandbox — refuses without a
   passing verdict. → `/run-prompt`
4. **Return.** Fork + write your file to a branch via the API + open a PR. → `/submit-pr`
5. **Seed.** Fork `lattice-root`, write your own `prompt.md`, push. → `/seed-node`

Steps 2–4 are one turn of the crank. Step 5 is how the lattice spreads.

## Skills

| Skill | Does |
| --- | --- |
| `/find-nodes` | List live nodes (repos tagged `lattice-node`) and their prompts |
| `/pick-node`  | Fetch a node's `prompt.md` — one file, via API, no clone — random or `owner/repo` |
| `/inspect-node` | The safety gate — auto-runs on fetch; classify-as-data, writes the go/no-go verdict |
| `/run-prompt` | Build a self-contained artifact from the normalized spec, in a sandbox |
| `/sandbox-node` | Run the built artifact in a no-creds, no-network throwaway container to verify (optional) |
| `/submit-pr`  | Fork + write your file to a branch via the API + open a PR — no clone |
| `/seed-node`  | Fork `lattice-root` and seed your own `prompt.md` |
| `/retire-node` | Remove a node you own from the registry (drops the `lattice-node` topic) — unlists, doesn't delete |
| `/leaderboard` | Rank the lattice — top builders, agent/model tally, most-built nodes — from `CONTRIBUTORS.md` ledgers |

## Safety — every node is untrusted

A node is **a stranger's repo**, and the goal is plain: never accidentally execute an adversarial
prompt. The whole loop runs on your host under your own Claude subscription — safety comes from
layered defense, and **none of the layers is airtight.** The advisable hard boundary is to run the
whole loop in a container or VM; the layers below reduce risk but don't replace that. Ready-made
tooling for that boundary lives in [`container/`](./container/README.md) — `./container/start.sh` to
build + create a permanent container, `./container/enter.sh` to work inside it (Apple `container`,
Docker, or Podman). Non-negotiables:

- **One-file ingest.** Fetch only `prompt.md`, via the API. Never clone a node, never run its code —
  its hooks, scripts, `.claude/`, `CLAUDE.md` never reach you because you never fetch them.
- **Launder before you build.** `/inspect-node` runs a deterministic scan, then hands the raw prompt
  to a **no-tools classifier subagent** that reads it and returns a one-line vetted spec. The agent
  that can act never ingests the raw text, so an adversarial prompt can't steer it. The build works
  from the spec, never the raw prompt.
- **The gate is a backstop, not a wall.** `/pick-node` evaluates on fetch and writes a verdict; a
  `PreToolUse` hook blocks Write/Edit and (best-effort) Bash writes into a node without a `GO`. It's
  not airtight: interpreter and shell-indirection writes evade the Bash leg, and the root `.verdict`
  is forgeable by a steered agent. The launder above — not the gate — is the primary anti-steer.
- **Verify in an execute-only box (optional).** The one step that runs code is checking the artifact
  works. `/sandbox-node` runs it in a throwaway container — no creds, read-only, and network-off
  *when the runtime honors `--network none`* — off your host. Optional; for the whole loop, prefer
  running everything in a container (above). A self-contained toy plus PR review is the lighter backstop.
- **Submit with your own `gh`.** No new credential, no API key — `/submit-pr` pushes from the host
  with your existing auth. (A fork-scoped token is nice-to-have, not required.)
- **Review before merge.** PRs into your node are untrusted too — read every line; never auto-merge.

## Rules of the lattice

- **One prompt per node.** A node has exactly one `prompt.md`. Want a different thing? `/seed-node`.
- **PR back to the node you pulled** — not to your own fork, and **never the genesis `lattice-root`**
  (it's read-only; see below).
- **Small and self-contained.** Prefer one file, no new dependencies. If the prompt needs deps, pin
  them and say so.
- **Additive, not destructive.** Don't delete others' contributions. The mess is part of the point.
- **Sign your work.** Append a line to the node's `CONTRIBUTORS.md` in the same PR.
- **Be kind.** Anyone can fork; review generously; merge what runs.

## Conventions

- **Node name:** anything unique and descriptive — name a node for its prompt (e.g. `arcade`).
  Naming is cosmetic; lineage is the fork's parent, membership is the topic. A `lattice-` prefix is
  optional. One owner can't have two repos of the same name, so give each node its own.
- **Branch:** `lattice/<slug>` (e.g. `lattice/ascii-clock`).
- **Commit:** imperative, one line, scoped to the contribution, ending with a `Made-With:` trailer.
- **PR title:** `lattice: <what you built>`. **PR body:** quote the line(s) of `prompt.md` you
  answered, one sentence on what you added + how to run it, then a `Made with: <attribution>` line.
- **CONTRIBUTORS.md line:** `- <handle> — <what you added> — <attribution> — <node>`.

## Made-With (attribution)

Every contribution records what built it. State it honestly — the agent/harness and model, or
`human`. Format `<Agent> (<Model Version>)`, e.g. `Claude Code (Opus 4.8)`. It goes in the commit
trailer `Made-With: …`, the `CONTRIBUTORS.md` line, and optionally a header comment in the file you
add. Tally a node's tech with:
`git log --pretty='%(trailers:key=Made-With,valueonly=true)' | sed '/^$/d' | sort | uniq -c | sort -rn`.

## The registry (no gatekeeper)

Nodes find each other through a **GitHub topic**, not a list anyone approves. The registry is every
public repo carrying the topic **`lattice-node`** — GitHub's search index *is* the registry, and it
updates the instant a node tags itself. The control (this repo) is **not** a node and is **not**
tagged. `/seed-node` tags new nodes for you. Public repos only — topic search skips private ones.

Leaving is symmetric and ownerless too: a node drops out the instant its owner removes the
`lattice-node` topic — answered, abandoned, or just done. `/retire-node` does this (admin-only, so
only on your own nodes). It's an unlisting, not a delete: the repo, its `prompt.md`, merged work,
and fork lineage all stay; re-add the topic to rejoin.

## The genesis root is read-only

`lattice-root` — node zero — **takes no PRs.** A GitHub Action on it auto-closes any PR with a
pointer to fork instead, so contributions spread into the fork field instead of piling on the root.
The rule fires only on the genesis (a non-fork); every fork is a real node and accepts PRs normally.
