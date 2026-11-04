#!/bin/bash
# Runs Maestro with credentials from .env.
# Usage: ./run-tests.sh [maestro test args...]
#   ./run-tests.sh --include-tags=end-to-end flows/
#   ./run-tests.sh flows/onboarding-select-topics.yaml
#   ./run-tests.sh --device emulator-5554 flows/onboarding-select-topics.yaml
#
# Failed tests are rerun once and reported as flaky if they then pass.
# Turn this off with RETRY=0 (in .env or before the command).
# Reports go to test-output/: report.html (open in a browser), JUnit XML
# (report.xml) plus, in debug/<test>/,
# a screenshot of the failed step, a step-by-step log (commands.json) and logs.
# Each run replaces the previous run's test-output/.
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
DEBUG_DIR="$REPORT_DIR/debug"
RETRY_DEBUG_DIR="$REPORT_DIR/debug-retry"
mkdir -p "$REPORT_DIR"
# Clear the previous run's output (only what this script writes)
rm -rf "$REPORT" "$RETRY_REPORT" "$DEBUG_DIR" "$RETRY_DEBUG_DIR" "$REPORT_DIR/report.html"

# Maestro's logs record the values passed with -e, so replace the account
# details with **** in the text files of test-output/ (safe to share or upload).
mask_secrets() {
  local name
  for name in GOVUK_PASSWORD GOVUK_TOTP_SECRET GOVUK_EMAIL; do
    [ -n "${!name:-}" ] || continue
    grep -rlF --include='*.log' --include='*.json' --include='*.xml' -- "${!name}" "$REPORT_DIR" 2>/dev/null \
      | while IFS= read -r f; do SECRET="${!name}" perl -pi -e 's/\Q$ENV{SECRET}\E/****/g' "$f"; done
  done
  return 0
}

# Prints "<file>: <reason>" for each failed test in a JUnit report
failure_reasons() {
  [ -f "$1" ] || return 0
  awk '
    /<testcase / {
      file = ""
      if ($0 ~ /status="(ERROR|CANCELED|STOPPED)"/ && match($0, /file="[^"]+"/))
        file = substr($0, RSTART + 6, RLENGTH - 7)
    }
    /<failure/ && file != "" {
      msg = $0
      sub(/.*<failure[^>]*>/, "", msg)
      sub(/<\/failure>.*/, "", msg)
      print file ": " msg
      file = ""
    }' "$1" | sed -e 's/&quot;/"/g' -e "s/&apos;/'/g" -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g'
}

# Prints each failed test, the step that failed, and its screenshot
print_failures() {
  local report="$1" debug_dir="$2" file name shot
  while IFS= read -r line; do
    file="${line%%: *}"
    name="$(basename "$file" .yaml)"
    echo "  $file"
    echo "    ${line#*: }"
    shot="$(ls "$debug_dir/$name/screenshots/"*.png 2>/dev/null | tail -1 || true)"
    if [ -n "$shot" ]; then echo "    screenshot: ${shot#$SCRIPT_DIR/}"; fi
  done < <(failure_reasons "$report")
}

print_reports() {
  # HTML summary from the JUnit and step logs; a problem here never changes the test result
  python3 "$SCRIPT_DIR/scripts/maestro-report.py" "$REPORT_DIR" \
    || echo "Warning: could not build test-output/report.html"
  echo ""
  echo "Reports (test-output/):"
  echo "  report.html              open in a browser: results, every step, failure screenshots"
  echo "  report.xml               JUnit results"
  echo "  debug/<test>/            screenshot of the failed step, commands.json (every step), logs/"
  if [ -f "$RETRY_REPORT" ]; then
    echo "  report-retry.xml         JUnit results of the rerun"
    echo "  debug-retry/<test>/      the same for the rerun"
  fi
}

set +e
run_maestro --format junit --output "$REPORT" \
  --debug-output "$DEBUG_DIR" --flatten-debug-output "$@"
STATUS=$?
set -e
mask_secrets

if [ "$STATUS" -ne 0 ]; then
  echo ""
  echo "=== Failed tests ==="
  print_failures "$REPORT" "$DEBUG_DIR"
fi

if [ "$STATUS" -eq 0 ] || [ "${RETRY:-1}" = "0" ] || [ ! -f "$REPORT" ]; then
  print_reports
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
  print_reports
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
  --debug-output "$RETRY_DEBUG_DIR" --flatten-debug-output \
  ${OPTIONS[@]+"${OPTIONS[@]}"} "${FAILED[@]}"
RETRY_STATUS=$?
set -e
mask_secrets

echo ""
echo "=== Retry summary ==="
for file in "${FAILED[@]}"; do
  if grep -F "file=\"$file\"" "$RETRY_REPORT" 2>/dev/null | grep -q 'status="SUCCESS"'; then
    echo "  FLAKY   $file (failed, then passed on retry)"
  else
    echo "  FAILED  $file (failed twice)"
  fi
done

if [ "$RETRY_STATUS" -ne 0 ]; then
  echo ""
  echo "=== Still failing after the rerun ==="
  print_failures "$RETRY_REPORT" "$RETRY_DEBUG_DIR"
fi
print_reports

exit "$RETRY_STATUS"