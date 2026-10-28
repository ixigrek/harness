#!/usr/bin/env bash
# PreToolUse hook on Bash, installed as managed policy in the image: the agent cannot edit or
# disable it, unlike settings.json. Exit 2 blocks the command; stderr goes back to the agent.
# It matches anywhere in the command line, so `bash -c "git push"` is caught too.
# Not a security boundary (a script written to disk then run is not seen): the credentials are.
set -uo pipefail

cmd="$(jq -r '.tool_input.command // ""')"
[[ -n "$cmd" ]] || exit 0
allowed=" ${HARNESS_KUBE_CONTEXTS:-} "

block() { printf 'blocked by the harness: %s. Do not work around it: show the command and let the user run it.\n' "$1" >&2; exit 2; }

w='(^|[[:space:]"'"'"'(;&|`])'   # start of a word

# Git: the user pushes from the host. Global options (-C dir, -c k=v, --x) may precede the verb.
g="${w}git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+"
[[ "$cmd" =~ ${g}push([[:space:]]|$) ]] && block "git push"
[[ "$cmd" =~ ${g}remote[[:space:]]+(add|set-url|rename|remove) ]] && block "git remote change"
[[ "$cmd" =~ ${w}git[[:space:]]+(filter-branch|filter-repo) ]] && block "history rewrite"

# Kubernetes: declared contexts only, read-only
if [[ "$cmd" =~ ${w}(kubectl|helm|flux|argocd|cilium|hubble)[[:space:]] ]]; then
  [[ "$cmd" =~ (--kubeconfig|KUBECONFIG=) ]] && block "kubeconfig override (only ~/.kube/config is allowed)"
  while read -r ctx; do
    [[ -z "$ctx" ]] && continue
    [[ "$allowed" == *" $ctx "* ]] || block "kube context '$ctx' is not in KUBE_CONTEXTS (${HARNESS_KUBE_CONTEXTS:-none declared})"
  done < <(grep -oE -- '--(kube-)?context[= ]+[^[:space:]"'"'"']+' <<< "$cmd" | sed -E 's/--(kube-)?context[= ]+//')
  [[ "$cmd" =~ ${w}kubectl[[:space:]]([^;&|]*[[:space:]])?(apply|create|delete|edit|patch|replace|scale|drain|cordon|uncordon|taint|label|annotate|set|exec|cp|debug|rollout[[:space:]]+(restart|undo|pause|resume))([[:space:]]|$) ]] \
    && block "kubectl mutation (the identity is read-only)"
  [[ "$cmd" =~ ${w}helm[[:space:]]([^;&|]*[[:space:]])?(install|upgrade|uninstall|delete|rollback)([[:space:]]|$) ]] \
    && block "helm mutation (the identity is read-only)"
fi

# Obvious wipes
[[ "$cmd" =~ ${w}rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+)+(/|~|\$HOME|\.\./?|\*)/?([[:space:]]|$) ]] && block "recursive rm on a root"

exit 0
