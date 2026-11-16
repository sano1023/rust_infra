# Official releases, pinned to patch versions and Debian suites.
# Keep shared toolchain dependencies here; future production build/runtime
# stages can be added separately from the development target.
FROM node:24.22.3-bookworm-slim AS node
FROM rust:1.99.1-bookworm AS base

FROM base AS development

ARG LOCAL_UID=1000
ARG LOCAL_GID=1000
ARG WATCHEXEC_VERSION=2.8.0

# The host GID may already exist in Debian (e.g. macOS staff = 20).
RUN test "$LOCAL_UID" -gt 0 && test "$LOCAL_GID" -gt 0 \
    && if ! getent group "$LOCAL_GID" >/dev/null; then groupadd --gid "$LOCAL_GID" dev; fi \
    && useradd --uid "$LOCAL_UID" --gid "$LOCAL_GID" --create-home --shell /bin/bash dev \
    && cargo install --locked --version "$WATCHEXEC_VERSION" --root /usr/local watchexec-cli \
    && mkdir -p /app /usr/local/cargo/registry /usr/local/cargo/git /usr/local/cargo/target \
    && chown -R "$LOCAL_UID:$LOCAL_GID" /app /usr/local/cargo /usr/local/rustup

RUN apt-get update \
    && apt-get install -y --no-install-recommends ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/dev/.codex /home/dev/.claude \
    && printf '%s\n' 'cli_auth_credentials_store = "file"' > /home/dev/.codex/config.toml \
    && chown -R "$LOCAL_UID:$LOCAL_GID" /home/dev \
    && chmod 700 /home/dev/.codex /home/dev/.claude

# Install complete npm packages, including Codex's background-server files.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm/ /usr/local/lib/node_modules/npm/

ARG CODEX_VERSION=0.169.0
ARG CLAUDE_CODE_VERSION=2.1.325

RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && npm install --global --include=optional --no-audit --no-fund \
        --allow-scripts=@anthropic-ai/claude-code \
        "@openai/codex@$CODEX_VERSION" \
        "@anthropic-ai/claude-code@$CLAUDE_CODE_VERSION" \
    && npm cache clean --force \
    && codex --version \
    && claude --version

COPY --chmod=755 dev-start.sh /usr/local/bin/dev-start

ENV CARGO_TARGET_DIR=/usr/local/cargo/target
ENV DISABLE_AUTOUPDATER=1
WORKDIR /app
USER dev

EXPOSE 5150
CMD ["/usr/local/bin/dev-start"]
