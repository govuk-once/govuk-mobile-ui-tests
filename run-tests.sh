#!/bin/bash
# Runs Maestro with credentials from .env.
# Usage: ./run-tests.sh [maestro test args...]
#   ./run-tests.sh --include-tags=end-to-end flows/
#   ./run-tests.sh flows/onboarding-select-topics.yaml
#   ./run-tests.sh --device emulator-5554 flows/onboarding-select-topics.yaml
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env variables
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
else
  echo "Error: .env file not found in $SCRIPT_DIR"
  echo "Create one with GOVUK_EMAIL, GOVUK_PASSWORD, and GOVUK_TOTP_SECRET"
  exit 1
fi

if [ -z "${GOVUK_TOTP_SECRET:-}" ]; then
  echo "Warning: GOVUK_TOTP_SECRET not set in .env — security code step will fail"
fi

# Pick a device unless one was passed. Without this Maestro picks whichever
# device it finds first, which may be an emulator without the app installed.
# Defaults to the iPhone 18 Pro simulator; override with DEVICE_ID or
# DEVICE_NAME in .env, or pass --device.
DEVICE_ARGS=()
if [[ " $* " != *" --device "* && " $* " != *" --device="* ]]; then
  DEVICE="${DEVICE_ID:-}"
  if [ -z "$DEVICE" ] && command -v xcrun >/dev/null; then
    DEVICE_NAME="${DEVICE_NAME:-iPhone 18 Pro}"
    DEVICE=$(xcrun simctl list devices available | grep -F "    $DEVICE_NAME (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)
    if [ -z "$DEVICE" ]; then
      echo "Error: no simulator named '$DEVICE_NAME' found"
      exit 1
    fi
    # Boot it if needed (no-op error if already booted)
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    xcrun simctl bootstatus "$DEVICE" -b >/dev/null
  fi
  if [ -n "$DEVICE" ]; then
    echo "Using device: $DEVICE"
    DEVICE_ARGS=(--device "$DEVICE")
  fi
fi

# Pass credentials to Maestro via -e flags.
# TOTP code is generated inline by flows/auth/sign-in.yaml (runScript)
# so it is fresh when typed — not stale from script start.
~/.maestro/bin/maestro test \
  ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} \
  -e GOVUK_EMAIL="$GOVUK_EMAIL" \
  -e GOVUK_PASSWORD="$GOVUK_PASSWORD" \
  -e GOVUK_TOTP_SECRET="${GOVUK_TOTP_SECRET:-}" \
  "$@"