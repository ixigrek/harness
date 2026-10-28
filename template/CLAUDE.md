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

## Tasks and subagents
- Short task (a file or two, obvious cause): do it in this loop. No written plan, no subagent.
- Long task (several modules, hours, or likely resumed): use the `long-task` skill. State lives in
  `docs/tasks/<slug>/`, committed, so the next session resumes from it.
- Do the work yourself by default: you keep the whole context, a subagent's summary loses it.
  Delegate only in these cases, independent ones in the same message so they run in parallel:
  - `explorer` (haiku): broad read-only search that would bloat your context. Not for a known path.
  - `implementer` (sonnet): chunks of a long task with disjoint files, in parallel.
  - `verifier` (haiku): full build/lint/test run, condensed verdict.
  - `reviewer` (opus): cold review of a long task's diff against its plan.
- Brief a subagent completely (goal, files, what is ruled out, expected output) and check its
  conclusion against the code before relying on it. Planning stays in this loop.
- A hook in the image blocks pushes, remote changes, kube mutations and contexts outside
  `HARNESS_KUBE_CONTEXTS`. When it blocks, explain and stop; never work around it.
