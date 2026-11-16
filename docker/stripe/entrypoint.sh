#!/bin/sh
set -eu

# This service is dedicated to Sandbox development.
for argument in "$@"; do
    case "$argument" in
        --live=false) ;;
        --live|--live=*)
            printf '%s\n' 'This development service uses Stripe Sandboxes. Live mode is disabled.' >&2
            exit 2
            ;;
    esac
done

if [ "$#" -eq 1 ] && [ "$1" = listen ]; then
    if ! /bin/stripe whoami --format json >/dev/null 2>&1; then
        printf '%s\n' \
            'Waiting for Stripe login. On the host, run: make stripe-login' \
            'Select your Sandbox, then run: make stripe-up'
        # Keep the container available without starting an unattended login flow.
        exec sleep infinity
    fi

    exec /bin/stripe listen --live=false --skip-update --all-snapshot \
        --forward-to "${STRIPE_FORWARD_TO:-http://app:5150/api/v1/billing/webhooks/stripe}"
fi

exec /bin/stripe "$@"
