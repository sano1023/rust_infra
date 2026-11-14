# Official stable release, pinned to a patch version and Debian suite.
# Keep shared toolchain dependencies here; future production build/runtime
# stages can be added separately from the development target.
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
    && mkdir -p /app/target /usr/local/cargo/registry /usr/local/cargo/git \
    && chown -R "$LOCAL_UID:$LOCAL_GID" /app /usr/local/cargo /usr/local/rustup

COPY --chmod=755 dev-start.sh /usr/local/bin/dev-start

ENV CARGO_TARGET_DIR=/app/target
WORKDIR /app
USER dev

EXPOSE 5150
CMD ["/usr/local/bin/dev-start"]
