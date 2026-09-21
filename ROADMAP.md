# Claude Code harness: roadmap

Last updated: 2026-09-21

Goal: run Claude Code in a Docker sandbox (sbx) on `worktree/`, with no access to `data/`,
with read-only infra tools, and with token consumption under control.

Legend: [x] done, [~] in progress, [ ] to do, [?] to verify

---

## Step 1. Foundation: sbx + Claude Code + one project, no infra tools [x]

- [x] Directory tree `data/` (outside the sandbox) and `worktree/{.bare, main, shared, .claude, CLAUDE.md}`
- [x] `harness new`: bare repo, `main` worktree, `.git` pointer, `.claude` symlinked and excluded from git
- [x] Relative worktree paths (`worktree.useRelativePaths`, needs git 2.48 or newer). Without this the worktrees break inside the VM
- [x] Repo-level git identity (the VM does not inherit `~/.gitconfig`)
- [x] Root `CLAUDE.md` (English, short) + `.claude/settings.json` (allow Go/git, deny push/remote/apt/sudo)
- [x] Locked Down network policy, the "block, then allow-list" loop validated in the TUI
- [x] Go pilot: endpoint + test + commit from inside the sandbox

Decisions: `CLAUDE.md` in English (fewer tokens). `GOTOOLCHAIN=local`. `apt` and `sudo` forbidden to the agent, the image is immutable.

---

## Step 2. sbx kit: custom image + mixins [x]

- [x] Multi-stage `image/Dockerfile`: `dev` (Go, Bun, Python) and `infra` (dev + kubectl, helm, cilium, hubble, argocd, flux, terraform, tofu, aws, gcloud, az, hcloud, scw, ovhcloud)
- [x] Everything in `/usr/local/bin`, pinned versions, apt only at build time
- [x] `az` via `uv` + a managed Python 3.12 (image ships 3.14, `--prerelease=allow` required)
- [x] `build.sh` (buildx arm64, pushed to Docker Hub, writes `image/TAG`) and `check-versions.py` (bumps via GitHub)
- [x] Mixin kits `harness-dev` and `harness-infra` (network + env), stacked on `--template`
- [x] `harness run [--infra] [--fresh]`: create, then post-create, then run. Reattaches if the sandbox exists
- [x] Validated: Go 1.25.1 / Bun 1.4.2 in `pilot`, 18 allow + 1 deny, infra image with all 14 tools

Decisions: image via `--template` + `mixin` kits (rather than a `sandbox` kit inheriting from `claude`). `claude-code` base without dockerd. Two images so as not to ship 2 GB of cloud CLIs into a Go project. Weekly rebuild is the update mechanism, never apt inside the VM.

Backlog: add `linux/amd64` if ever needed. Helm 3 vs 4 depending on the existing charts.

---

## Step 3. Read-only identities, one provider at a time [~]

Principle: the boundary is the credential, not Claude Code. The `deny` entries in `settings.json` are ergonomics.

Scope (decided 2026-09-21): only what runs today, i.e. the Talos cluster on Proxmox and what sits on
top of it. Everything else is parked, not planned.

### Kubernetes [x]
- [x] `data/agent/`: the only subfolder of `data/` mounted in the VM, as `:ro`, at the same absolute path
- [x] Agent kubeconfig provided by the user (SA `ai-agents:ai-reader`, `can-i create` answers no)
- [x] Project kit `worktree/.harness/kit/spec.yaml`: API server host (derived from the kubeconfig)
- [x] Talos cluster reachable on the LAN, TLS intact, RBAC effective from inside the VM
- [x] `data/agent/.env` (POSIX sh, `$AGENT_DIR`) + `.env.session`; loader written by `post_create` into `/etc/sandbox-persistent.sh`, `~/.profile`, `~/.bashrc`; symlink `~/.kube/config`
- [?] Is the loader sourced by the agent process? (`!echo $AGENT_DIR $KUBECONFIG` in Claude Code after a restart). **Do first**: every other provider relies on it
- [?] The LAN IP in the project kit: the allow was added from the TUI. Bare vs `/32` vs policy level, check with `sbx policy ls`

### In scope [ ]
| Provider | Identity | Delivery | Status |
|---|---|---|---|
| ArgoCD | account/role `get` only | `sbx secret` (bearer) + host in project kit | to do, next provider; validates proxy injection |
| Flux | nothing: goes through the kubeconfig | n/a | done de facto |
| Cilium / Hubble | via kubeconfig (`cilium.io` CRDs, `kube-system` portforward) | `HUBBLE_SERVER` in `.env` | to test |
| Terraform/OpenTofu | none | **no state in the VM** (decided): the agent writes HCL, `plan`/`apply` run on the host or in CI. Talos machine secrets live in the state and must never enter the sandbox | decided |

Decisions: Proxmox gets no identity of its own (host-only concern; no CLI in the image anyway).
Terraform state stays outside: redacted state and RO backend both rejected.

### Parked (not in use, do not implement)
Azure (`Reader` SP), Hetzner (read token), Scaleway (`AllProductsReadOnly`), AWS (`ViewOnlyAccess`),
GCP (`roles/viewer`), OVH (`GET /*` keys). The delivery mechanisms are known (`.env`, `sbx secret`,
`.env.session`); pick them up only when a project actually needs one.

Backlog: the `infra` image ships `aws`, `gcloud`, `az`, `hcloud`, `scw`, `ovhcloud` for nothing.
Consider dropping them at the next rebuild to shrink the image.

Out of scope (decided): the Grafana/Loki/Tempo stack. Logs are `data/` through another door.

Closing test per provider: a read succeeds, a mutation fails with 403 **from inside** the sandbox.

---

## Step 4. Host launcher [dropped]

Only existed for AWS/GCP 1h session tokens, which are parked. The mechanism (`.env.session` mounted
`:ro`, loader) stays in place; a `harness env` generator is written only if such a provider returns.

---

## Step 5. Token cost, measured [ ] (priority: this is what hurts today)

Order: the cheap win first, the measurement second, Headroom last and only if still needed.

- [ ] MCP inventory: list what `mcp-gateway.docker.internal` exposes in a session. Gmail, Google Calendar, Google Drive and Claude Docs are loaded in a harness session and none is needed here. Disable per project with `/mcp`
- [ ] Baseline: one week of sessions with adapted effort/model (Sonnet for execution, Opus for planning, recaps cut, unused MCPs off)
- [ ] Headroom inside the VM (local proxy to api.anthropic.com through the sbx proxy); check that the path holds with Anthropic credential injection
- [ ] One week with it, cost comparison
- [ ] Keep only if the gain is clear; no stacking with rtk/caveman-proxy

Reminder: Headroom sets `ANTHROPIC_BASE_URL`, so the context is handled as 200k, not 1M.

---

## Step 6. Generalisation [ ]

- [ ] Document the harness (README) so it can be picked up again in six months. Before the migration: it is what makes the rest survive
- [ ] Migrate the existing sandboxes (`claude-*`) to `harness new`; `my-bank-account` with a deterministic redaction script from `data/` to `shared/`
- [ ] `CLAUDE.md` template per project type (Go / Bun / infra) with the cluster/provider context
- [ ] Weekly image rebuild (`check-versions.py`, then `build.sh`, then `harness run --fresh`)

---

## Order of work (decided 2026-09-21)

1. Close the two Kubernetes `[?]` (minutes, host)
2. Step 5: MCP inventory, then the baseline week
3. Step 3: ArgoCD read-only identity
4. Step 5: Headroom trial, if the baseline still hurts
5. Step 6: README, then migration, then rebuild routine

---

## Open points / debt

- [?] `/etc/sandbox-persistent.sh` loader sourced by the agent (see step 3)
- [?] Does `sbx create` accept the same syntax as `sbx run` (create/post-create/run has not yet been exercised with `--fresh`)
- [?] Private IPs in the kits
- `downloads.claude.ai` hit at boot despite `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` (probably sbx provisioning the agent). Benign
- `azcliprod.blob.core.windows.net` blocked (`az` auto-update). Intended
- The `deny` entries in `settings.json` can be bypassed via bash (demonstrated on `.bare/`). The sandbox and the credentials are what protect, not them
- `mcp-gateway.docker.internal` heavily used: inventory what the MCP gateway exposes before measuring tokens
