#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

ENV_FLAGS=""
[ -n "${GOVUK_EMAIL:-}" ] && ENV_FLAGS="$ENV_FLAGS -e GOVUK_EMAIL=$GOVUK_EMAIL"
[ -n "${GOVUK_PASSWORD:-}" ] && ENV_FLAGS="$ENV_FLAGS -e GOVUK_PASSWORD=$GOVUK_PASSWORD"

maestro test $ENV_FLAGS "$@"
