# Bun (also provides a node-compatible runtime + bunx)
ARG BUN_VERSION=1.4.2
RUN arch=$([ "$TARGETARCH" = arm64 ] && echo aarch64 || echo x64) \
 && curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${arch}.zip" -o /tmp/bun.zip \
 && unzip -q /tmp/bun.zip -d /tmp \
 && install -m 0755 "/tmp/bun-linux-${arch}/bun" /usr/local/bin/bun \
 && ln -sf bun /usr/local/bin/bunx \
 && rm -rf /tmp/bun*
