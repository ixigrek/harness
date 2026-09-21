# az via uv, with a uv-managed Python 3.12 (the image ships 3.14, not yet supported by azure-cli).
# --prerelease=allow: azure-cli pins pre-release dependencies (azure-batch==x.y.zb1).
# Everything lives under /opt/uv; only the `az` shim lands in /usr/local/bin.
ARG AZ_VERSION=2.90.0
RUN command -v uv >/dev/null \
 || (curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv.sh && UV_INSTALL_DIR=/usr/local/bin sh /tmp/uv.sh && rm /tmp/uv.sh)
RUN UV_PYTHON_INSTALL_DIR=/opt/uv/python UV_TOOL_DIR=/opt/uv/tools UV_TOOL_BIN_DIR=/usr/local/bin \
    uv tool install --python 3.12 --prerelease=allow "azure-cli==${AZ_VERSION}" \
 && chmod -R a+rX /opt/uv \
 && az version >/dev/null
