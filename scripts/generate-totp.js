// Generates the current 6-digit TOTP code (RFC 6238, HMAC-SHA1, 30s step)
// from GOVUK_TOTP_SECRET and exposes it to the flow as ${output.totp}.
// Maestro's JS runtime has no crypto module, so SHA-1 is implemented here.

function base32ToBytes(input) {
    var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    var clean = String(input).toUpperCase().replace(/[\s=-]/g, '');
    var bits = 0;
    var value = 0;
    var bytes = [];
    for (var i = 0; i < clean.length; i++) {
        var idx = alphabet.indexOf(clean.charAt(i));
        if (idx === -1) throw new Error('GOVUK_TOTP_SECRET is not valid base32');
        value = (value << 5) | idx;
        bits += 5;
        if (bits >= 8) {
            bytes.push((value >>> (bits - 8)) & 0xff);
            bits -= 8;
        }
    }
    return bytes;
}

function sha1(bytes) {
    var h0 = 0x67452301, h1 = 0xefcdab89, h2 = 0x98badcfe, h3 = 0x10325476, h4 = 0xc3d2e1f0;
    var msg = bytes.slice();
    var bitLen = bytes.length * 8;
    msg.push(0x80);
    while (msg.length % 64 !== 56) msg.push(0);
    for (var s = 56; s >= 0; s -= 8) msg.push(s >= 32 ? 0 : (bitLen >>> s) & 0xff);

    var w = new Array(80);
    for (var off = 0; off < msg.length; off += 64) {
        for (var i = 0; i < 16; i++) {
            w[i] = (msg[off + i * 4] << 24) | (msg[off + i * 4 + 1] << 16) |
                (msg[off + i * 4 + 2] << 8) | msg[off + i * 4 + 3];
        }
        for (var t = 16; t < 80; t++) {
            var x = w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16];
            w[t] = (x << 1) | (x >>> 31);
        }
        var a = h0, b = h1, c = h2, d = h3, e = h4;
        for (var j = 0; j < 80; j++) {
            var f, k;
            if (j < 20) { f = (b & c) | (~b & d); k = 0x5a827999; }
            else if (j < 40) { f = b ^ c ^ d; k = 0x6ed9eba1; }
            else if (j < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8f1bbcdc; }
            else { f = b ^ c ^ d; k = 0xca62c1d6; }
            var temp = (((a << 5) | (a >>> 27)) + f + e + k + w[j]) | 0;
            e = d; d = c; c = (b << 30) | (b >>> 2); b = a; a = temp;
        }
        h0 = (h0 + a) | 0; h1 = (h1 + b) | 0; h2 = (h2 + c) | 0; h3 = (h3 + d) | 0; h4 = (h4 + e) | 0;
    }

    var out = [];
    [h0, h1, h2, h3, h4].forEach(function (h) {
        out.push((h >>> 24) & 0xff, (h >>> 16) & 0xff, (h >>> 8) & 0xff, h & 0xff);
    });
    return out;
}

function hmacSha1(key, message) {
    if (key.length > 64) key = sha1(key);
    var inner = [];
    var outer = [];
    for (var i = 0; i < 64; i++) {
        var kb = i < key.length ? key[i] : 0;
        inner.push(kb ^ 0x36);
        outer.push(kb ^ 0x5c);
    }
    return sha1(outer.concat(sha1(inner.concat(message))));
}

function totp(secret, timeMs) {
    var counter = Math.floor(timeMs / 1000 / 30);
    var msg = [0, 0, 0, 0, 0, 0, 0, 0];
    for (var i = 7; i >= 0; i--) {
        msg[i] = counter & 0xff;
        counter = Math.floor(counter / 256);
    }
    var hash = hmacSha1(base32ToBytes(secret), msg);
    var offset = hash[hash.length - 1] & 0x0f;
    var code = ((hash[offset] & 0x7f) << 24) | (hash[offset + 1] << 16) |
        (hash[offset + 2] << 8) | hash[offset + 3];
    var str = String(code % 1000000);
    while (str.length < 6) str = '0' + str;
    return str;
}

if (typeof GOVUK_TOTP_SECRET === 'undefined' || !GOVUK_TOTP_SECRET) {
    throw new Error('GOVUK_TOTP_SECRET is not set - pass it with -e or run ./run-tests.sh');
}

output.totp = totp(GOVUK_TOTP_SECRET, Date.now());