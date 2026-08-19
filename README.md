# Crypto64

64-bit (amd64) port of [bbext/Crypto](https://github.com/bbext/Crypto) for the
64-bit BlackBox Component Builder (bbcp). Drop-in replacement: module names
are identical to the 32-bit package (`CryptoAES`, `CryptoTLS`, ...), the
subsystem folder in the world is `Crypto`.

Source of truth: `Mod/*.odc.txt` (UTF-8). Build into the world:

```sh
./build.sh        # sync .odc.txt -> .odc (OdcTextU in BB64 console), compile via dev0
```

## Port changes vs upstream

- `CryptoAosCompat`: all x86-32 `[code]` inline-asm helpers (UAdd64Raw,
  USubInline64, ULSH64Raw, UDiv/UMod 8/16/32, Bsr32, ULss/UGtr, CDQ,
  UGetHighBits64) rewritten in pure Component Pascal. `ADDRESS* = LONGINT`
  (`SIZE*` stays `INTEGER` — host APIs are 32-bit).
- `CryptoAosStrings.TryParseSize`: ADDRESS->SIZE conversions via SHORT.
- `CryptoFortunaRng`: `DevHeapSpy.par.allocated` is LONGINT in 64-bit, SHORT
  at the call site.
- `CryptoAosBigNumbers`/`CryptoAosStreams`: `100000000L` kept as-is on purpose
  — in BB 2.0 the `L` suffix is a 64-bit HEX literal, so `100000000L` =
  0x100000000 = 2^32, matching the A2 original `100000000H`. Do not "fix".
- `AllTests.odc` is a launcher document (commanders), not a module — excluded
  from Compile-List.

## Status

All tests pass in the 64-bit world: hashes (MD5/SHA1/SHA2-256/SHA3),
HMAC, BigNumbers Test1, ciphers (AES/DES/3DES/ARC4/CAST/IDEA, ECB/CBC/CTR),
DH (SSL512/SSH), RSA Test1, X25519 (Generate/Agreement/FromPrivateKey).

Note: in the console host a failed command (`command error: ...`) aborts the
rest of stdin — run remaining commands in a fresh session.
