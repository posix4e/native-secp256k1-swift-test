# Experimental native Swift secp256k1 verification

This independent research package implements BIP340 signature verification,
x-only public-key validation and tagged SHA-256. It has no Winnow dependency and
declares zero third-party package dependencies. **The arithmetic is variable time
and only for public data. Do not use it for private keys, nonces or shared secrets.**

The curve arithmetic is native Swift. Tagged hashing uses Apple's CryptoKit;
this does not imply the operating system's hash implementation is entirely Swift.
Original code is Apache-2.0; fixture provenance and notices are separate.
There has been no independent human cryptographic audit or production approval.

```swift
import Foundation
import NativeSecp256k1

// All arguments are PUBLIC data. A Bitcoin transaction adapter supplies its
// already-computed transaction digest as message; this API does not prehash it.
let verified = ExperimentalBIP340.verify(
    signature: signatureBytes,  // exactly 64 bytes, r || s
    message: messageBytes,      // arbitrary length, including empty
    publicKey: publicKeyBytes   // exactly 32 bytes, x-only
)
```

The verifier rejects malformed lengths, invalid public points, r ≥ p and s ≥ n.
It computes the BIP340 challenge and R = sG − eP, then requires R to be finite,
have even y, and have x = r. A false result is a signature-verification failure;
it does not say which input was wrong. Verification has no signing state,
randomness, network access or persistent storage.

`ExperimentalXOnlyPublicKey(rawRepresentation:)` remains available for the
separate operation of validating a public key and exposing its canonical x and
even-y coordinates. `TaggedSHA256.hash(tag:message:)` supplies domain-separated
hashing. A `TapTweak` hash alone is not a tweaked key.

Internally, field elements modulo p and scalars modulo n are distinct types.
Public point arithmetic uses Jacobian coordinates, with explicit infinity,
negation, addition and multiplication. Zero is a valid public scalar. None of
these internal types is a private-key abstraction or safe for secret inputs.

There is no signer, private-key derivation, BIP32 API, Taproot tweak API, MuSig2
backend or ECDH. This milestone cannot replace Winnow's P256K dependency by
itself. The [migration plan](research/native-swift-roadmap.md) retains the goal
of a native Swift secp256k1 backend covering Winnow's production call surface.

The package declares Swift 6.0+, iOS 17+ and macOS 14+. Run:

```sh
swift test
swift test -c release
```

On the research host, Swift 6.4's default build system encountered Finder or
resource-fork metadata under the Documents directory. An external scratch path
avoids carrying that generated-bundle metadata into builds. The earlier pass
used the deprecated `--build-system native` fallback. Every evidence record
names the actual command, toolchain and scope; a failed build is not a test pass.

The [verification milestone report](research/bip340-verification-report.md)
records the new tests and their limits. Official signature vectors now exercise
full verification, separately from the first pass's 318 key-validation cases.
Generated cases use pinned external implementations and synthetic public test
material. They do not use wallet keys. Ordinary tests read checked-in fixtures
and do not build or link a C backend into the Swift package.

See [fixture provenance](Tests/NativeSecp256k1Tests/Fixtures/README.md),
[signature and point evidence](Tools/schnorr-fixtures.md),
[oracle reproduction](Tools/README.md), [design](DESIGN.md),
[research safety](SECURITY.md), and [third-party notices](THIRD_PARTY_NOTICES.md).
The historical [first-pass report](research/first-pass-report.md),
[capability matrix](research/capability-scope-matrix.md),
[agent arithmetic review](research/arithmetic-review.md), and
[Swift Crypto proposal](research/swift-crypto-fit.md) describe the earlier
revision. Their coverage numbers and conclusions do not certify this new code.
