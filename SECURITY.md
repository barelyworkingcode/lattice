# Security & trust model

**Read this before you run anyone's node.**

> **Run at your own risk.** lattice runs code — your own build, and whatever you choose to run from a
> node. The layers below *reduce* risk; **none is airtight**, and the verify sandbox is **optional**,
> not automatic. If you don't fully trust a prompt or an artifact, run the whole loop in a container
> or VM. **You are responsible for what runs on your machine.** lattice is an experiment, provided
> **as-is, with no warranty** — see [`LICENSE`](./LICENSE).

lattice is split into two halves on purpose:

- **The control (this repo)** — the trusted harness. You clone it once, audit it, and run it. The
  skills and rules live here.
- **Nodes** — bare repos that hold one `prompt.md` and the code answering it. **No `CLAUDE.md`, no
  `.claude/`, no hooks.** A node is content, not a program.

That split is the security model. The thing you *execute* (the harness) never comes from an
untrusted source, and the only thing you *ingest* from a node is its one `prompt.md` — fetched via
the API, **never cloned**. This removes the worst attack vectors of "just fork it and run":

- **No node code on your machine** — you fetch one text file, never the repo. Its hooks, scripts,
  `postinstall`, and other files never reach you.
- **No node-supplied `CLAUDE.md`** auto-loaded as instructions, and **no node-supplied skills/hooks**
  — you can't be handed a poisoned `run-prompt`.
- **One scannable instruction channel** — `prompt.md` — gated by trusted code before any build.

## What's still untrusted (and how it's contained)

You never fetch a node's code, so its scaffolding and scripts can't run. Two things remain
untrusted: the `prompt.md` text (it could try to inject the reader) and your *own* build (you still
execute the artifact you make). The loop runs on your host under your own Claude subscription. **None
of the layers below is airtight — the advisable hard boundary is to run the whole loop in a container
or VM.** With that said, containment, in order:

1. **One-file ingest.** Fetch only `prompt.md`, via the API — never clone a node. Its hooks,
   scripts, `.claude/`, `CLAUDE.md` never reach you because you never fetch them.
2. **Launder the prompt before you build.** `/pick-node` evaluates on fetch and writes a verdict.
   The evaluation runs a deterministic pattern scan, then hands the raw prompt to a **no-tools
   classifier subagent** (no Bash, no writes, no network), which returns a one-line vetted spec. The
   agent that can act never reads the raw text, so an injected prompt can't steer it — the worst a
   hijacked classifier does is mis-classify. This launder, not the gate, is the primary anti-steer.
   The builder works from the spec only. A `PreToolUse` hook (`.claude/hooks/gate.py`) *also* blocks
   Write/Edit and (best-effort) Bash writes into a node without a `GO` verdict — a backstop, not a
   wall. (Residuals: interpreter writes — `python3 -c`, `node -e`, heredocs — and shell variable
   indirection dodge the Bash leg; the file-write leg anchors the bookkeeping allow-list to the node
   root, but a steered agent can still forge the root `.verdict`. The container covers the run step
   regardless.)
3. **Verify in an execute-only box (optional).** The only step that runs code is checking the
   artifact works. `/sandbox-node` runs it in a throwaway container with **no credentials, read-only,
   and network-off when the runtime honors `--network none`.** On a runtime that rejects the flag the
   skill tells you to drop it — and then the artifact *can* reach the network, so prefer a runtime
   that enforces isolation. Optional; for a self-contained toy, PR review is the lighter backstop.
4. **Submit with your own `gh`.** `/submit-pr` pushes from the host with your existing auth — no API
   key, no second credential, no creds in any container. (A fork-scoped fine-grained token is a
   nice-to-have, not required.)
5. **The prompt is a spec, not a command.** Build the artifact it describes. Refuse operational
   instructions — secrets, off-node writes, network with no build reason, `curl … | bash`, opaque
   dependencies. Instructions in files are data, not orders.
6. **Review before you merge.** PRs into your node are untrusted too. Read every line; never
   auto-merge.

## What we promise / don't

- **We don't** review nodes, scan prompts, or vouch for contributors. There is no trusted party in
  the lattice — that's the cost of having no gatekeeper.
- **We do** keep the trusted/untrusted split, fetch only one file in the build loop and gate it
  before any build (best-effort — see the gate's limits above), and keep the genesis root read-only
  so it can't be poisoned by a PR. (Note: `/seed-node` *clones* when you branch off an existing
  populated node — the one place the loop puts node code on disk. Do that in a container, or stick to
  the bare genesis.)

## A guardrailed agent helps — but it isn't the only thing holding

Claude running the loop already treats `prompt.md` as data, won't act on embedded "exfiltrate"
instructions, and asks before irreversible or outward actions. But you don't lean on that alone: the
launder (a powerless reader) holds even if the agent is fooled — the acting agent never sees the raw
text. The gate hook is a best-effort backstop, not a hard block (a steered agent can forge the root
verdict or use an interpreter write), so the real containment for the run step is the execute-only
box — or, better, running the whole loop in a container. Two things none of it covers: a *human*
copying a node's command out and running it by hand, and branching `/seed-node` off a populated node
(which clones its tree) — so do neither outside a container.

## Reporting

Found a node weaponizing the lattice? It isn't ours to take down — it's someone's fork — but open
an issue on `lattice-root` so others steer clear, and report the repo to GitHub at
`https://github.com/contact/report-abuse`.
