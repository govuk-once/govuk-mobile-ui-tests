#!/usr/bin/env bash
# Full e2e pipeline: API contract tests (REST Assured) -> API-to-UI check (Maestro)
# Usage: ./run-e2e.sh [maestro options, e.g. --device <id>]
# Optional: BASE_URL / API_BASE_URL to test another API environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export JAVA_HOME="${JAVA_HOME:-$HOME/java/jdk-21/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"

echo "=== Step 1: API contract tests (REST Assured) ==="
cd "$SCRIPT_DIR/api-tests"
set +e
./mvnw -q test
API_STATUS=$?
set -e
# HTML report, built whether the tests passed or not
./mvnw -q surefire-report:report-only || echo "Warning: could not build the API HTML report"
echo "API report: api-tests/target/reports/surefire.html"
if [ "$API_STATUS" -ne 0 ]; then
  echo "API contract tests failed, so the API-to-UI check was not run."
  exit "$API_STATUS"
fi

echo ""
echo "=== Step 2: API-to-UI check (Maestro) ==="
cd "$SCRIPT_DIR"
EXTRA_ENV=()
if [ -n "${API_BASE_URL:-${BASE_URL:-}}" ]; then
  EXTRA_ENV=(-e API_BASE_URL="${API_BASE_URL:-$BASE_URL}")
fi
./run-tests.sh ${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"} "$@" flows/e2e/topics-match-api.yaml

echo ""
echo "=== All e2e checks passed ==="