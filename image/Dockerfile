# syntax=docker/dockerfile:1
#
# sbx harness image. Two targets:
#   dev   : Claude Code base + pinned Go, Bun, Python
#   infra : dev + kubectl, helm, cilium, hubble, argocd, flux, terraform, tofu,
#           aws, gcloud, az, hcloud, scw, ovhcloud
#
# Rules:
#   - every binary ends up in /usr/local/bin (sbx may override PATH)
#   - versions as ARGs, pinned; the build fails loudly if an asset was renamed
#   - apt only here, at build time, never inside the sandbox
#
# Versions checked on 2026-09-20 (arm64 assets exist) except GO, AWSCLI, GCLOUD
# (hosts not reachable from the checking tool). To bump: ./check-versions.py

ARG BASE=docker/sandbox-templates:claude-code

# ---------------------------------------------------------------- dev --
FROM ${BASE} AS dev
ARG TARGETARCH
ARG GO_VERSION=1.25.1
ARG BUN_VERSION=1.4.2

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip xz-utils jq \
 && rm -rf /var/lib/apt/lists/*

# Go: replaces the base image's copy with a pinned version
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz" -o /tmp/go.tgz \
 && rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tgz && rm /tmp/go.tgz \
 && ln -sf /usr/local/go/bin/go /usr/local/bin/go \
 && ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Bun (also provides a node-compatible runtime + bunx)
RUN arch=$([ "$TARGETARCH" = arm64 ] && echo aarch64 || echo x64) \
 && curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${arch}.zip" -o /tmp/bun.zip \
 && unzip -q /tmp/bun.zip -d /tmp \
 && install -m 0755 "/tmp/bun-linux-${arch}/bun" /usr/local/bin/bun \
 && ln -sf bun /usr/local/bin/bunx \
 && rm -rf /tmp/bun*

# Python: the base image's copy + uv (already present in the Docker templates) is enough.

ENV GOTOOLCHAIN=local \
    GOFLAGS=-mod=mod \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

USER agent
WORKDIR /home/agent

# -------------------------------------------------------------- infra --
FROM dev AS infra
ARG TARGETARCH
ARG KUBECTL_VERSION=1.37.0
ARG HELM_VERSION=4.3.0
ARG CILIUM_CLI_VERSION=0.20.0
ARG HUBBLE_VERSION=1.19.4
ARG ARGOCD_VERSION=3.5.3
ARG FLUX_VERSION=2.9.5
ARG TERRAFORM_VERSION=1.16.3
ARG TOFU_VERSION=1.12.6
ARG AWSCLI_VERSION=2.31.6
ARG GCLOUD_VERSION=546.0.0
ARG AZ_VERSION=2.90.0
ARG HCLOUD_VERSION=1.68.0
ARG SCW_VERSION=2.62.0
ARG OVHCLOUD_VERSION=0.15.0

USER root

# kubectl, helm
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
 && chmod 0755 /usr/local/bin/kubectl \
 && curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" | tar -xz -C /tmp \
 && install -m 0755 "/tmp/linux-${TARGETARCH}/helm" /usr/local/bin/helm \
 && rm -rf /tmp/linux-*

# cilium, hubble
RUN curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/v${CILIUM_CLI_VERSION}/cilium-linux-${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin cilium \
 && curl -fsSL "https://github.com/cilium/hubble/releases/download/v${HUBBLE_VERSION}/hubble-linux-${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin hubble

# argocd, flux
RUN curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${TARGETARCH}" -o /usr/local/bin/argocd \
 && chmod 0755 /usr/local/bin/argocd \
 && curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin flux

# terraform, opentofu
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tf.zip \
 && unzip -q -o /tmp/tf.zip terraform -d /usr/local/bin && rm /tmp/tf.zip \
 && curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tofu.zip \
 && unzip -q -o /tmp/tofu.zip tofu -d /usr/local/bin && rm /tmp/tofu.zip

# aws cli v2
RUN arch=$([ "$TARGETARCH" = arm64 ] && echo aarch64 || echo x86_64) \
 && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch}-${AWSCLI_VERSION}.zip" -o /tmp/aws.zip \
 && unzip -q /tmp/aws.zip -d /tmp \
 && /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli \
 && rm -rf /tmp/aws /tmp/aws.zip

# gcloud (no extra components, no auto-update)
RUN arch=$([ "$TARGETARCH" = arm64 ] && echo arm || echo x86_64) \
 && curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-${arch}.tar.gz" | tar -xz -C /opt \
 && /opt/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=false --bash-completion=false \
 && ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
 && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
 && rm -rf /opt/google-cloud-sdk/.install/.backup

# az via uv, with a uv-managed Python 3.12 (the image ships 3.14, not yet supported by azure-cli).
# --prerelease=allow: azure-cli pins pre-release dependencies (azure-batch==x.y.zb1).
# Everything lives under /opt/uv; only the `az` shim lands in /usr/local/bin.
RUN command -v uv >/dev/null \
 || (curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv.sh && UV_INSTALL_DIR=/usr/local/bin sh /tmp/uv.sh && rm /tmp/uv.sh)
RUN UV_PYTHON_INSTALL_DIR=/opt/uv/python UV_TOOL_DIR=/opt/uv/tools UV_TOOL_BIN_DIR=/usr/local/bin \
    uv tool install --python 3.12 --prerelease=allow "azure-cli==${AZ_VERSION}" \
 && chmod -R a+rX /opt/uv \
 && az version >/dev/null

# hcloud, scw, ovhcloud
RUN curl -fsSL "https://github.com/hetznercloud/cli/releases/download/v${HCLOUD_VERSION}/hcloud-linux-${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin hcloud \
 && curl -fsSL "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_VERSION}/scaleway-cli_${SCW_VERSION}_linux_${TARGETARCH}" -o /usr/local/bin/scw \
 && chmod 0755 /usr/local/bin/scw \
 && mkdir -p /tmp/ovh \
 && curl -fsSL "https://github.com/ovh/ovhcloud-cli/releases/download/v${OVHCLOUD_VERSION}/ovhcloud-cli_linux_${TARGETARCH}.tar.gz" | tar -xz -C /tmp/ovh \
 && install -m 0755 "$(find /tmp/ovh -type f -name 'ovhcloud*' | head -1)" /usr/local/bin/ovhcloud \
 && rm -rf /tmp/ovh

# Telemetry / update checks off: nothing should try to phone home on its own
ENV CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true \
    CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=true \
    AZURE_CORE_COLLECT_TELEMETRY=false \
    CHECKPOINT_DISABLE=1 \
    HCLOUD_CLI_TELEMETRY=off \
    SCW_DISABLE_CHECK_VERSION=true

USER agent
WORKDIR /home/agent
