# gcloud (no extra components, no auto-update)
ARG GCLOUD_VERSION=546.0.0
RUN arch=$([ "$TARGETARCH" = arm64 ] && echo arm || echo x86_64) \
 && curl -fsSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-${arch}.tar.gz" | tar -xz -C /opt \
 && /opt/google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=false --bash-completion=false \
 && ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud \
 && ln -sf /opt/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil \
 && rm -rf /opt/google-cloud-sdk/.install/.backup
