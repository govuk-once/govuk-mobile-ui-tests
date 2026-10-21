#!/bin/bash
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

# Generate TOTP code from the secret
GOVUK_TOTP_CODE=""
if [ -n "${GOVUK_TOTP_SECRET:-}" ]; then
  GOVUK_TOTP_CODE=$(python3 -c "
import hmac, hashlib, struct, time, base64
secret = '${GOVUK_TOTP_SECRET}'
key = base64.b32decode(secret)
counter = int(time.time()) // 30
msg = struct.pack('>Q', counter)
h = hmac.new(key, msg, hashlib.sha1).digest()
offset = h[-1] & 0x0F
code = (struct.unpack('>I', h[offset:offset+4])[0] & 0x7FFFFFFF) % 1000000
print(f'{code:06d}')
")
  echo "Generated TOTP code: $GOVUK_TOTP_CODE"
else
  echo "Warning: GOVUK_TOTP_SECRET not set in .env — OTP step will fail"
fi

# Pass all credentials to Maestro via -e flags
~/.maestro/bin/maestro test \
  -e GOVUK_EMAIL="$GOVUK_EMAIL" \
  -e GOVUK_PASSWORD="$GOVUK_PASSWORD" \
  -e GOVUK_TOTP_CODE="$GOVUK_TOTP_CODE" \
  "$@"