#!/usr/bin/env python3
"""Compare the Dockerfile's *_VERSION ARGs against the latest GitHub releases (no API, via redirects)."""
import re, sys, pathlib, urllib.request, urllib.error
DF = pathlib.Path(__file__).parent / "image" / "Dockerfile"
REPOS = {  # ARG -> (repo, arm64 asset pattern or None)
 "BUN_VERSION": ("oven-sh/bun", "bun-linux-aarch64.zip"),
 "KUBECTL_VERSION": ("kubernetes/kubernetes", None),
 "HELM_VERSION": ("helm/helm", None),
 "CILIUM_CLI_VERSION": ("cilium/cilium-cli", "cilium-linux-arm64.tar.gz"),
 "HUBBLE_VERSION": ("cilium/hubble", "hubble-linux-arm64.tar.gz"),
 "ARGOCD_VERSION": ("argoproj/argo-cd", "argocd-linux-arm64"),
 "FLUX_VERSION": ("fluxcd/flux2", "flux_VER_linux_arm64.tar.gz"),
 "TERRAFORM_VERSION": ("hashicorp/terraform", None),
 "TOFU_VERSION": ("opentofu/opentofu", "tofu_VER_linux_arm64.zip"),
 "AZ_VERSION": ("Azure/azure-cli", None),
 "HCLOUD_VERSION": ("hetznercloud/cli", "hcloud-linux-arm64.tar.gz"),
 "SCW_VERSION": ("scaleway/scaleway-cli", "scaleway-cli_VER_linux_arm64"),
 "OVHCLOUD_VERSION": ("ovh/ovhcloud-cli", "ovhcloud-cli_linux_arm64.tar.gz"),
}
class NR(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
op = urllib.request.build_opener(NR)
def head(url, method="HEAD"):
    try: op.open(urllib.request.Request(url, method=method, headers={"User-Agent": "harness"}), timeout=20); return 200, None
    except urllib.error.HTTPError as e: return e.code, e.headers.get("Location")
pinned = dict(re.findall(r"ARG (\w+_VERSION)=(\S+)", DF.read_text()))
rc = 0
for arg, (repo, pat) in REPOS.items():
    code, loc = head(f"https://github.com/{repo}/releases/latest")
    if code not in (301, 302): print(f"?    {arg:20} {repo}: HTTP {code}"); continue
    tag = loc.rsplit("/", 1)[-1]; latest = re.sub(r"^(bun-)?v|^azure-cli-", "", tag)
    cur = pinned.get(arg, "?"); mark = "OK  " if cur == latest else "BUMP"
    asset = ""
    if pat:
        a = pat.replace("VER", latest); c, _ = head(f"https://github.com/{repo}/releases/download/{tag}/{a}")
        asset = a if c in (301, 302) else f"MISSING ASSET: {a}"
    if mark == "BUMP": rc = 1
    print(f"{mark} {arg:20} {cur:>8} -> {latest:8} {asset}")
print("Not checked here: GO_VERSION (go.dev/dl), AWSCLI_VERSION (awscli.amazonaws.com), GCLOUD_VERSION (dl.google.com).")
sys.exit(rc)
