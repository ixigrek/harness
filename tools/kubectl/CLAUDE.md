## Kubernetes
- `KUBECONFIG` points to a read-only identity (mounted read-only from outside the workspace). `apply`/`delete`/`patch`/`exec` fail with 403. Do not retry: show the manifest or the command and let the user run it.
- On `Unauthorized` or an expired credential, say so in one line and stop; the user refreshes the file.
- `kubectl get`, `describe`, `logs`, `explain` only. `-o yaml` on one object, never on a whole namespace.
