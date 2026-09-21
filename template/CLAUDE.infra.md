
## Kubernetes / infra
- `KUBECONFIG` points to a read-only identity (mounted read-only from outside the workspace). `apply`/`delete`/`patch`/`exec` fail with 403. Do not retry: show the manifest or the command and let the user run it.
- On `Unauthorized` or an expired credential, say so in one line and stop; the user refreshes the file.
- `helm`: `template`, `show`, `lint` only. `terraform`/`tofu`: `fmt`, `validate`; `plan` only when the user says a backend is set up for you.
- `cilium status` without `--verbose`; `hubble observe` only via the relay endpoint the user gives you.
