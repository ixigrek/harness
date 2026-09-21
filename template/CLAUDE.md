# Harness

You run inside a Docker Sandbox (sbx). The workspace is `worktree/`, mounted from the host.

## Layout
- `.bare/` is the git object store. Never edit anything under it.
- Each branch is a directory: `main/`, `<branch>/`. Work inside ONE of them per task. Do not create worktrees; the user does (`harness add`).
- `shared/` holds redacted copies of real datasets. Treat them as representative, not real. The originals are outside the sandbox: never ask for them, never try to reconstruct them.
- `.claude/` holds settings shared by all worktrees.

## Git
- Commit locally, small commits, Conventional Commits, subject 50 chars max.
- Never push, never add or change remotes, never rewrite history that exists on `main`. The user pushes from the host.

## Network and credentials
- The image is immutable: no `apt`, `sudo`, `brew`, or system-wide installs. If a tool is missing, say which one in one line and stop; the user adds it to the image.
- Outbound network is allow-listed. If a download or fetch fails with a network error, report the blocked host in one line and stop. Do not look for workarounds or mirrors.
- Any cloud or cluster credentials present are read-only by design. Do not attempt mutations; describe the change and let the user apply it.

## Go
- Toolchain and modules come from the Go proxy. `go build ./... && go vet ./...` before claiming done.
- `gofmt` on touched files. No new dependency without saying why.

## Token hygiene
- Grep/Glob before Read. Never dump whole large files or directory trees into context.
- Tests: `go test ./... 2>&1 | tail -n 40`. Use `-v` or `-run` only on the failing test.
- No progress narration. Short answers. Code, commands and errors byte-exact.
