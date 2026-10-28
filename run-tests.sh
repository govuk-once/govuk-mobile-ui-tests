#!/bin/bash
# Runs Maestro with credentials from .env.
# Usage: ./run-tests.sh [maestro test args...]
#   ./run-tests.sh --include-tags=end-to-end flows/
#   ./run-tests.sh flows/onboarding-select-topics.yaml
#   ./run-tests.sh --device emulator-5554 flows/onboarding-select-topics.yaml
#
# Failed tests are rerun once and reported as flaky if they then pass.
# Turn this off with RETRY=0 (in .env or before the command).
# JUnit reports are written to test-output/.
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
run_maestro() {
  ~/.maestro/bin/maestro test \
    ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} \
    -e GOVUK_EMAIL="$GOVUK_EMAIL" \
    -e GOVUK_PASSWORD="$GOVUK_PASSWORD" \
    -e GOVUK_TOTP_SECRET="${GOVUK_TOTP_SECRET:-}" \
    "$@"
}

# If the caller chose their own report format, run once as before.
if [[ " $* " == *" --format"* ]]; then
  run_maestro "$@"
  exit $?
fi

REPORT_DIR="$SCRIPT_DIR/test-output"
REPORT="$REPORT_DIR/report.xml"
RETRY_REPORT="$REPORT_DIR/report-retry.xml"
mkdir -p "$REPORT_DIR"
rm -f "$REPORT" "$RETRY_REPORT"

set +e
run_maestro --format junit --output "$REPORT" "$@"
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ] || [ "${RETRY:-1}" = "0" ] || [ ! -f "$REPORT" ]; then
  exit "$STATUS"
fi

# Files of the tests that failed (from the JUnit report)
FAILED=()
while IFS= read -r file; do
  [ -n "$file" ] && FAILED+=("$file")
done < <(grep -E '<testcase .*status="(ERROR|CANCELED|STOPPED)"' "$REPORT" \
           | sed -E 's/.* file="([^"]+)".*/\1/')

# Nothing to rerun (e.g. Maestro stopped before any test ran)
if [ ${#FAILED[@]} -eq 0 ]; then
  exit "$STATUS"
fi

# Keep the caller's options (device, tags, -e ...) but swap the test paths
# for the failed files. An argument is a test path if it exists and is not
# the value of an option such as "--device X".
OPTIONS=()
PREV=""
for arg in "$@"; do
  if [ -e "$arg" ] && { [[ "$PREV" != -* ]] || [[ "$PREV" == *=* ]]; }; then
    :
  else
    OPTIONS+=("$arg")
  fi
  PREV="$arg"
done

echo ""
echo "=== Rerunning ${#FAILED[@]} failed test(s) once ==="
printf '  %s\n' "${FAILED[@]}"
echo ""

set +e
run_maestro --format junit --output "$RETRY_REPORT" \
  ${OPTIONS[@]+"${OPTIONS[@]}"} "${FAILED[@]}"
RETRY_STATUS=$?
set -e

echo ""
echo "=== Retry summary ==="
for file in "${FAILED[@]}"; do
  if grep -F "file=\"$file\"" "$RETRY_REPORT" 2>/dev/null | grep -q 'status="SUCCESS"'; then
    echo "  FLAKY   $file (failed, then passed on retry)"
  else
    echo "  FAILED  $file (failed twice)"
  fi
done
echo "Reports: test-output/report.xml, test-output/report-retry.xml"

exit "$RETRY_STATUS"