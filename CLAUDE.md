# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`harness` is the tooling that runs Claude Code inside a Docker Sandbox (`sbx`) with no access to real
data and only read-only infra credentials. It is self-hosted: this very checkout lives in a harness
layout, and the `../CLAUDE.md` you also see is the copy of `template/CLAUDE.md` that `harness new`
installed for this project. Those root rules (git, network, token hygiene) apply here; this file only
adds what is specific to developing the harness itself.

Everything is bash and a single Python script. There is no build, no test suite, no linter.
`ROADMAP.md` is the source of truth for what is done, in progress, and decided; update it when a step
changes status.

## Commands

Runnable from inside the sandbox:

```bash
bash -n harness build.sh              # syntax check (no shellcheck in the image)
./check-versions.py                   # compare tools/*/Dockerfile *_VERSION ARGs with GitHub latest; exit 1 = something to bump
TOOLS="go kubectl" DRY=1 ./build.sh x # print the Dockerfile that would be built for that tool set
PROJECTS_ROOT=/tmp/hp ./harness new t1 --purpose p --tools "kubectl helm" </dev/null   # end-to-end layout + render, no sbx needed
```

Host only (need `sbx`, `docker buildx`, a registry login; none of that exists in the sandbox):

```bash
harness new <name> [remote-url] [--purpose S] [--cluster S] [--tools "a b"]   # lay out <PROJECTS_ROOT>/<name>/, ask what is not given
harness md [--purpose S] [--cluster S] [--tools "a b"]                        # regenerate CLAUDE.md, settings.json, kit; asks once if no descriptor
HARNESS_IMAGE_REPO=docker.io/<user>/harness harness build [tag]               # this project's image from its tools, via build.sh
PUSH=0 harness build                                                          # local --load instead of --push
harness add <branch> [dir]                                                    # new worktree under worktree/
harness repair                                                                # re-relativise worktree paths
harness policy                                                                # sbx policy allow for every tool's hosts + Claude
harness run [--fresh]                                                         # harness md, then create/reattach sandbox, workspace = worktree/
HARNESS_PLAIN=1 harness run                                                   # default sbx image, no kit
```

`harness new` / `md` render without sbx and can be exercised here (see above); `build` and `run`
cannot. Say what the user should run on the host to validate those.

## Architecture

### Host layout produced by `harness new`

```
<PROJECTS_ROOT>/<name>/
  data/                 real data, chmod 700, NEVER mounted
  data/agent/           (kubectl in the tools) the one subfolder mounted in the VM, :ro, same absolute path
    .env, .env.session, kubeconfig
  worktree/             the sbx workspace, mounted rw
    .bare/              bare repo; worktree/.git is "gitdir: ./.bare"
    main/, <branch>/    git worktrees, each with .claude -> ../.claude
    .claude/settings.json    generated
    CLAUDE.md           generated between <!-- harness:begin/end --> markers; text outside is kept
    shared/             redacted datasets, produced on the host
    .harness/           git-excluded, host-side
      project.env       the descriptor: PURPOSE, CLUSTER, TOOLS (written by `new`, edited by hand)
      hosts             optional extra network hosts for the kit
      kit/spec.yaml     generated per-project mixin kit
      tools             effective tool set at the last render; image.tag, image.tools at the last build
```

Everything under `worktree/` except `.bare`, `main/`, `shared/` and `.harness/project.env` is
derived: `render_project` in `harness` rewrites it from the descriptor plus `detect_tools` (markers
in `main/`: `go.mod`, `package.json`, `pyproject.toml`, manifests, `Chart.yaml`, `*.tf`). `run` calls
it every time, so never hand-edit the generated files; edit the descriptor, the templates or `tools/`.

Why a bare repo plus `worktree.useRelativePaths` (git >= 2.48): the workspace is mounted at a
different path inside the VM, and absolute worktree pointers would break. `harness repair` re-applies
this. Git identity is set at repo level because the VM does not inherit `~/.gitconfig`.

### Tool catalogue, image and kits

- A tool is a directory `tools/<name>/`, listed in `tools/ORDER` (canonical order, also the layer
  order). Files, all optional: `Dockerfile` (`ARG X_VERSION=` + `RUN`, binaries in `/usr/local/bin`,
  a renamed upstream asset must fail the build), `CLAUDE.md` (the section rendered for the agent),
  `allow` (settings.json permission entries), `hosts` (kit network allow-list, `#` comments allowed,
  quote wildcards), `env` (kit `environment.variables` lines). Languages (`go`, `bun`, `python`)
  are tools like the others. `az` installs through `uv` with a managed Python 3.12 because the base
  image ships a Python that azure-cli does not support yet.
- One image per project: `build.sh` concatenates `image/Dockerfile.base` + the selected fragments +
  `image/Dockerfile.tail` and tags `<repo>:<project>-<tag>`. `harness build` passes the project's
  effective tools and records `.harness/image.tag` and `.harness/image.tools`; `run` uses that tag
  and warns when the tool set has drifted. `check-versions.py` reads the `ARG`s from the fragments.
- `kits/harness-base` (github hosts, telemetry denies, base env) is stacked with the generated
  project kit: tool hosts + `.harness/hosts` + the k8s API host from the kubeconfig (when `kubectl`
  is in the tools), tool env. `harness run` refuses to start while the kit still contains `CHANGEME`
  or omits that host.
- Image and kits are frozen when the sandbox is created. `--fresh` removes and recreates it.

### Credential flow (step 3 of the roadmap)

The security boundary is the credential, not Claude Code: every identity handed to the agent is
read-only (k8s `view` SA, `Reader` SP, read tokens). The `deny` list in `settings.json` is ergonomics
and can be bypassed from bash.

`harness run` does create, then `post_create`, then attach. `post_create` runs inside the VM and
installs a loader that exports `AGENT_DIR` and sources `data/agent/.env` and `.env.session` into
`/etc/sandbox-persistent.sh`, `~/.profile` and `~/.bashrc`, and symlinks the kubeconfig to
`~/.kube/config`. `.env` is POSIX sh (dash), long-lived, readable in clear in the VM; `.env.session`
is for 1h tokens and will be generated by a future `harness env`. Simple bearer APIs should use
`sbx secret` proxy injection instead so the VM never sees the key. An optional
`worktree/.harness/post-create.sh` runs after the loader.

`k8s/claude-ro.yaml` is a reference RBAC manifest for such a read-only identity, not something the
harness applies.

### Templates

`template/` is read by every `harness md`, so editing it changes every project at its next `run`.
`template/CLAUDE.md` is the head, `CLAUDE.tail.md` the tail, `settings.json` has the `@@ALLOW@@`
placeholder, `project-kit/spec.yaml` the `@@HOSTS@@`/`@@ENV@@` lines, `project.env` the descriptor
skeleton. BSD awk on the host rejects newlines in `-v` strings: generated lines go through temp
files and `getline`, keep it that way.

## Conventions specific to this repo

- Keep `harness` a single file, `set -euo pipefail`, `die`/`log` helpers, one `cmd_*` per subcommand,
  usage text in the header comment (the fallback `case` prints lines 2-15 of the file, so keep the
  usage block there).
- Pin versions; never install anything at run time. Weekly image rebuild is the update path.
- Comments and docs in English (fewer tokens). Shell must stay portable to the VM's `sh` where it is
  executed there (the loader in `post_create`).
