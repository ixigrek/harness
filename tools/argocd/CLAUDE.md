## Argo CD
- Server from `ARGOCD_SERVER`, token injected by the proxy. `argocd app get`, `list`, `diff` only; never `sync`, `rollback`, `set`. Describe the change and let the user sync.
