#!/usr/bin/env bash
# SessionStart hook (managed policy): tells the agent which long tasks are open, so that a new
# session or a `--fresh` sandbox resumes them instead of starting over. Stdout goes to the context.
set -uo pipefail
base="${CLAUDE_PROJECT_DIR:-$PWD}"
found=0
for f in "$base"/docs/tasks/*/progress.md "$base"/*/docs/tasks/*/progress.md; do
  [[ -f "$f" ]] || continue
  st="$(sed -n 's/^status:[[:space:]]*//p' "$f" | head -1)"
  [[ "$st" == in-progress || "$st" == blocked ]] || continue
  [[ "$found" == 1 ]] || { echo "Open long tasks (long-task skill):"; found=1; }
  next="$(sed -n 's/^next:[[:space:]]*//p' "$f" | head -1)"
  echo "- ${f#"$base"/} [$st] next: ${next:-see file}"
done
[[ "$found" == 1 ]] && echo "If the request is about one of them, read its plan.md and progress.md before acting."
[[ -n "${HARNESS_KUBE_CONTEXTS:-}" ]] && echo "Kube contexts available: $HARNESS_KUBE_CONTEXTS"
exit 0
