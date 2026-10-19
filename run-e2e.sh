#!/usr/bin/env bash
# Full e2e pipeline: API schema validation → Maestro UI assertion
# Usage: ./run-e2e.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Step 1: API schema validation and topic export ==="
cd "$SCRIPT_DIR/api-tests"
RAW_OUTPUT=$(mvn test -Dtest.tags=e2e -q 2>&1)
EXPECTED_TOPICS=$(echo "$RAW_OUTPUT" | grep "^EXPECTED_TOPICS=" | cut -d= -f2-)

if [ -z "$EXPECTED_TOPICS" ]; then
    echo "ERROR: API test did not export EXPECTED_TOPICS. Output was:"
    echo "$RAW_OUTPUT"
    exit 1
fi

export EXPECTED_TOPICS
echo "Topics from API: $EXPECTED_TOPICS"

echo ""
echo "=== Step 2: Maestro UI verification ==="
cd "$SCRIPT_DIR"
~/.maestro/bin/maestro test --include-tags=e2e flows/

echo ""
echo "=== All e2e checks passed ==="
