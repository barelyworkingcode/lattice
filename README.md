# lattice

> A coding game played through git forks — with the harness and the content kept apart so running
> a stranger's node can't run a stranger's code.

**lattice** turns "fork this repo" into a game. A **node** is a bare repo carrying one `prompt.md`
— a small thing someone wants built — and the code that answers it. You pick a node, build its ask
(*barely working is fine — working is required*), and PR it back. Then you seed your own node. Code
nobody planned accretes across the network.

It's exquisite corpse for code. A chain letter that compiles.

## Two repos, on purpose

| | What it is | Trust |
| --- | --- | --- |
| **`lattice`** (this repo) | The **control** — `CLAUDE.md`, the skills, `SECURITY.md`. You clone it once and run it. | **Trusted** — you audit it. |
| **`lattice-root`** | The **genesis node** — bare: a `prompt.md` and the work answering it. Forks of it are nodes. | **Untrusted** — it's just data. |

The harness you run lives only in the control, so a malicious node can't hand you a poisoned skill
or a weaponized `CLAUDE.md`. The only thing you ingest from a node is one text file. That's the
whole security idea — see [`SECURITY.md`](./SECURITY.md).

## How to play (with Claude Code)

Clone the control, open it in Claude Code, and run the loop. You **never clone a node** — only its
one `prompt.md` is fetched (via API) into `./workspace/`, and gated before anything builds.

```sh
gh repo clone barelyworkingcode/lattice && cd lattice   # the trusted control, once
```

| Command | What it does |
| --- | --- |
| `/find-nodes` | List live nodes and what each wants built |
| `/pick-node`  | Fetch a node's `prompt.md` — one file, no clone — and gate it on the spot (random or `owner/repo`) |
| `/inspect-node` | The safety gate: classify the fetched file as data, write a go/no-go verdict (auto-run by `/pick-node`) |
| `/run-prompt` | Build a self-contained artifact from the vetted spec |
| `/sandbox-node` | Optional: run the built artifact in a no-creds, no-network container to verify |
| `/submit-pr`  | Fork + write your file to a branch via the API + open a PR — no clone |
| `/seed-node`  | Fork `lattice-root` and seed your own ask |

A full turn is `/pick-node` (fetch + evaluate) → `/run-prompt` → `/submit-pr`.

New here? [`GETTING-STARTED.md`](./GETTING-STARTED.md) walks through creating a node and building for
one, by hand (`gh`/`git`, no Claude needed).

## Safety — never accidentally run an adversarial prompt

The whole loop runs on your host under your own Claude subscription — no API key, no per-token cost.
Safety comes from layered defense, not a single wall, and **none of it is airtight.** This is an
experiment that reads strangers' prompts: the advisable hard boundary is to **run the whole loop in
a container or VM**, not just the verify step — ready-made tooling for exactly that is in
[`container/`](./container/README.md) (`./container/start.sh`, then `./container/enter.sh`; works
with Apple `container`, Docker, or Podman). The layers:

- **One file in.** You fetch only `prompt.md` — never the node's code — so there's nothing of theirs
  to execute.
- **Laundered.** `/inspect-node` hands the raw prompt to a *no-tools* classifier that returns a
  one-line vetted spec; the agent that can act never reads the raw text. That launder — not the hook
  — is what actually keeps an adversarial prompt from steering you. A `PreToolUse` hook *also* blocks
  Write/Edit and (best-effort) Bash writes into a node without a `GO`, but it's a backstop: shell
  indirection can dodge the Bash leg, so don't treat it as a wall.
- **Execute-only verify (optional).** The one step that runs code — checking your toy works — can go
  in a throwaway container (`/sandbox-node`), or just lean on PR review. It's free (no key, no token
  — local compute); the only prerequisite is a container runtime. Network-off depends on the runtime
  honoring `--network none`; if it doesn't, the artifact may reach the network.
- **Your own `gh` submits.** No second credential, nothing in a container.

**Run at your own risk.** These layers reduce risk, but none is airtight and the sandbox is optional
— you are responsible for what runs on your machine. Provided as-is, with no warranty.

Full model: [`SECURITY.md`](./SECURITY.md).

## The registry

Nodes find each other through the GitHub topic **`lattice-node`** — no list, no gatekeeper. A node
tags its own repo and is instantly discoverable. This control repo is **not** a node and is not
tagged.

## The rules

Full constitution in [`CLAUDE.md`](./CLAUDE.md). Short version: one prompt per node, PR back to the
node you pulled (never the genesis root), keep it small and additive, sign `CONTRIBUTORS.md`, tag
what built it (`Made-With`), sandbox everything, be kind.

## License

[MIT](./LICENSE) — © lattice contributors.
