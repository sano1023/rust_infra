#!/bin/sh
set -eu

if [ ! -f /app/Cargo.toml ]; then
    printf '%s\n' \
        'No Cargo.toml in /app; the Rust development container is idle.' \
        'Clone repia-app into html/app, then run: docker compose restart app'
    exec sleep infinity
fi

# Poll bind mounts for reliable changes on Docker Desktop as well as Linux.
# Ignore build output and Git metadata to avoid rebuild loops.
exec watchexec \
    --restart \
    --watch /app \
    --project-origin /app \
    --ignore target \
    --ignore .git \
    --poll "${WATCH_POLL_INTERVAL:-1s}" \
    --stop-signal SIGTERM \
    --stop-timeout 10s \
    --shell none \
    -- sh -c "${APP_COMMAND:-cargo run -- start --binding 0.0.0.0 --port 5150}"
