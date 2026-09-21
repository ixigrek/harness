ARG TOFU_VERSION=1.12.6
RUN curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tofu.zip \
 && unzip -q -o /tmp/tofu.zip tofu -d /usr/local/bin && rm /tmp/tofu.zip
