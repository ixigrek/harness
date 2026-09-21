# Improvement ideas

Not planned, not ordered. Promote to `ROADMAP.md` when one gets a slot.

- **Interactive first run.** On the first `harness run` for a project, ask the user which tools
  they want (kubectl, helm, argocd, terraform, ...) instead of the fixed `dev`/`infra` split.
  Constraint: the image is immutable and pinned, so "install" means selecting an image target
  or a set of kits, not `apt` inside the VM. Could be a third target built from a list, or a
  per-project `.harness/tools` file that `build.sh` reads. Origin: a `--fresh` run on `talos`
  landed on the `dev` image and had no kubectl (2026-09-21).
