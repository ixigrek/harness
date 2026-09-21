ARG OVHCLOUD_VERSION=0.15.0
RUN mkdir -p /tmp/ovh \
 && curl -fsSL "https://github.com/ovh/ovhcloud-cli/releases/download/v${OVHCLOUD_VERSION}/ovhcloud-cli_linux_${TARGETARCH}.tar.gz" | tar -xz -C /tmp/ovh \
 && install -m 0755 "$(find /tmp/ovh -type f -name 'ovhcloud*' | head -1)" /usr/local/bin/ovhcloud \
 && rm -rf /tmp/ovh
