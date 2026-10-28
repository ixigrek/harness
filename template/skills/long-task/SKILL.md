---
name: long-task
description: Protocol for long or multi-step work (new feature, cross-cutting refactor, migration, anything that takes hours or may be resumed in another session). Written and committed plan, verified milestones, resumable after compaction, `--fresh` or a new session.
---
# Long task

All state lives in `docs/tasks/<slug>/` inside the worktree, committed with the code: that is what
lets the next session resume after a compaction, a `harness run --fresh` or a budget stop.

## 0. Where, and resume or start
- A long task runs in its own worktree (`<branch>/`, not `main/`). If none fits, ask once, in one
  line, for `harness add <slug>`, and stop until it exists. You do not create worktrees.
- If `docs/tasks/<slug>/progress.md` exists, read `plan.md` and `progress.md`, check the real state
  (`git log`, tests) and resume at `next:`.

## 1. Understand
Read `CLAUDE.md` and any `intent.md`/`spec.md` given. If the code area is large or unknown, launch
1 to 3 `explorer` in parallel on distinct questions; otherwise read it yourself.

## 2. Plan (in this loop, no subagent; `opusplan` gives this step to Opus)
Write `docs/tasks/<slug>/plan.md`:
```markdown
# Plan: <title>
## Goal and acceptance criteria
## Files that change
## Milestones (each one shippable and testable)
## Risks: what could break
## Proof: tests, commands, expected output
```
and `docs/tasks/<slug>/progress.md`:
```markdown
status: in-progress
next: milestone 1 - <summary>
## Log
- <date> plan written
```
Commit both. In an interactive session, present the plan and wait for approval before
implementing. In a headless run (`claude -p`), go on.

## 3. Execute milestone by milestone
1. Implement it yourself. When a milestone splits into chunks with disjoint files, launch one
   `implementer` per chunk in the same message, then review and commit their result.
2. Run the targeted tests; delegate to `verifier` when the output is large.
3. Commit, then update `progress.md` (`next:` + one log line) in the same or the next commit.
4. When execution departs from the plan, update `plan.md` in the same commit.

If blocked (missing tool or host, read-only credential, product decision, action refused by a
hook), write `status: blocked` and the precise question in `progress.md`, commit, and stop with
that question.

## 4. Close
1. `verifier` on the whole (build, lint, full tests, acceptance criteria).
2. `reviewer` on `git diff main...HEAD` with the plan. Fix the sure findings, list the others.
3. `status: done` in `progress.md`, commit.
4. Final summary: branch and last commit (the user pushes from the host), what is verified,
   what is not, open points.
