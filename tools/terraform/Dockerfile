ARG TERRAFORM_VERSION=1.16.3
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/tf.zip \
 && unzip -q -o /tmp/tf.zip terraform -d /usr/local/bin && rm /tmp/tf.zip
