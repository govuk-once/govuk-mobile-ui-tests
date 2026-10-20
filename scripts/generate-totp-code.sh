#!/bin/bash
# Generates a 6-digit TOTP code from a secret key.
# Usage: ./scripts/generate-totp-code.sh YOUR_SECRET_KEY
#
# Used during initial account setup to complete the authenticator app step.

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <TOTP_SECRET>"
  echo "Example: $0 QCKNRT7OEYFKDU2JLTEFUNO2I6XXCZEN"
  exit 1
fi

python3 -c "
import hmac, hashlib, struct, time, base64
key = base64.b32decode('$1')
counter = int(time.time()) // 30
msg = struct.pack('>Q', counter)
h = hmac.new(key, msg, hashlib.sha1).digest()
offset = h[-1] & 0x0F
code = (struct.unpack('>I', h[offset:offset+4])[0] & 0x7FFFFFFF) % 1000000
print(f'{code:06d}')
"
