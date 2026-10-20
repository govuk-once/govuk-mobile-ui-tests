#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

TOTP_CODE=""
if [ -n "${GOVUK_TOTP_SECRET:-}" ]; then
  TOTP_CODE=$(python3 -c "
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
fi

ENV_FLAGS=""
[ -n "${GOVUK_EMAIL:-}" ] && ENV_FLAGS="$ENV_FLAGS -e GOVUK_EMAIL=$GOVUK_EMAIL"
[ -n "${GOVUK_PASSWORD:-}" ] && ENV_FLAGS="$ENV_FLAGS -e GOVUK_PASSWORD=$GOVUK_PASSWORD"
[ -n "$TOTP_CODE" ] && ENV_FLAGS="$ENV_FLAGS -e GOVUK_TOTP_CODE=$TOTP_CODE"

maestro test $ENV_FLAGS "$@"
