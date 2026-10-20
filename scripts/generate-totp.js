var secret = GOVUK_TOTP_SECRET;

var base32Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
var bits = '';
for (var i = 0; i < secret.length; i++) {
    var val = base32Chars.indexOf(secret.charAt(i).toUpperCase());
    if (val >= 0) {
        var b = val.toString(2);
        while (b.length < 5) b = '0' + b;
        bits += b;
    }
}
var keyBytes = [];
for (var i = 0; i + 8 <= bits.length; i += 8) {
    keyBytes.push(parseInt(bits.substring(i, i + 8), 2));
}

var counter = Math.floor(Date.now() / 1000 / 30);
var counterBytes = [];
for (var i = 7; i >= 0; i--) {
    counterBytes[i] = counter & 0xff;
    counter = Math.floor(counter / 256);
}

var SecretKeySpec = Java.type('javax.crypto.spec.SecretKeySpec');
var Mac = Java.type('javax.crypto.Mac');

var keyArray = Java.type('byte[]');
var key = new keyArray(keyBytes.length);
for (var i = 0; i < keyBytes.length; i++) {
    key[i] = (keyBytes[i] > 127) ? keyBytes[i] - 256 : keyBytes[i];
}

var counterArray = new keyArray(8);
for (var i = 0; i < 8; i++) {
    counterArray[i] = (counterBytes[i] > 127) ? counterBytes[i] - 256 : counterBytes[i];
}

var keySpec = new SecretKeySpec(key, 'HmacSHA1');
var mac = Mac.getInstance('HmacSHA1');
mac.init(keySpec);
var hash = mac.doFinal(counterArray);

var offset = hash[hash.length - 1] & 0x0f;
var code = ((hash[offset] & 0x7f) << 24)
    | ((hash[offset + 1] & 0xff) << 16)
    | ((hash[offset + 2] & 0xff) << 8)
    | (hash[offset + 3] & 0xff);
code = code % 1000000;

var otp = '' + code;
while (otp.length < 6) otp = '0' + otp;

output.totp = otp;
