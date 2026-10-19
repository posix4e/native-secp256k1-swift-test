# Experimental native Swift public key validation

This independent research package implements BIP340 x-only public-key validation
and tagged SHA-256. It has no Winnow dependency and declares zero third-party
package dependencies. **The new arithmetic is variable time and only for public
data. Do not use it for private keys, nonces or shared secrets.**

The arithmetic is native Swift. Tagged hashing uses Apple's CryptoKit; this does
not imply the operating system's hash implementation is entirely Swift.
Original code is Apache-2.0; fixture provenance and notices are separate.

`ExperimentalXOnlyPublicKey` accepts exactly 32 big-endian bytes, rejects x ≥ p
and x values without a point on y² = x³ + 7, and selects the even y coordinate.
The internal field supports canonical encoding, addition, multiplication,
negation and square roots modulo p = 2²⁵⁶ − 2³² − 977.

```swift
import Foundation
import NativeSecp256k1

// publicKeyBytes is untrusted PUBLIC data, not a private scalar.
if let key = ExperimentalXOnlyPublicKey(rawRepresentation: publicKeyBytes) {
    let x = key.rawRepresentation       // canonical 32-byte x
    let y = key.evenYRepresentation     // canonical 32-byte even y
    let hash = TaggedSHA256.hash(tag: "TapTweak", message: x)
    // hash is only a tagged hash; this package does not perform a key tweak.
}
```

There is no signature verification, signing, scalar arithmetic modulo the group
order, point addition/multiplication, BIP32, Taproot tweaking, MuSig2 or ECDH.
This package cannot replace Winnow's P256K dependency. Its API is experimental
and has not received an independent human cryptographic audit.

The package declares Swift 6.0+, iOS 17+ and macOS 14+. This pass tested only
Apple Swift 6.4 on arm64 macOS 27.0.1. Linux, older toolchains, iOS simulators
and physical devices are untested. From this directory, run `swift test`.

On the research host the default Swift 6.4 build system failed while codesigning
a generated resource bundle because of Finder/resource-fork metadata. These
commands completed successfully with seven tests in two suites in each mode:

```sh
swift test --build-system native --enable-code-coverage
swift test --build-system native -c release
```

Swift 6.4 marks the native fallback deprecated. The default run failed before
tests and is not counted as successful. No developer account or signing
credentials are needed for the successful local tests.

The suite checks 2,624 Python integer arithmetic pairs, 168 root/nonresidue
answers, 318 x-only inputs agreed by the pinned BIP340 Python reference and
libsecp256k1, malformed lengths, noncanonical encodings and offset Data slices.
It retains all ten tagged-hash known answers from the copied starter. The 19
BIP340 public-key columns are key-validation inputs; these are **not** signature
verification tests.

The debug LLVM export reports 151/151 executable lines and 64/64 regions covered
across the three library sources. Swift emitted no branch counters. Coverage is
not exhaustive arithmetic testing, a CRAP measurement, a security audit, a timing
result or a performance benchmark.

See [fixture provenance](Tests/NativeSecp256k1Tests/Fixtures/README.md),
[oracle reproduction](Tools/README.md), [design](DESIGN.md), and
[third-party notices](THIRD_PARTY_NOTICES.md). The next milestone is complete
public BIP340 verification, after independent tests of point operations and
scalar parsing/reduction. Secret operations follow their own review gate.


The [first-pass research report](research/first-pass-report.md) records the tested
source revision and results. The [capability matrix](research/capability-scope-matrix.md),
[independent agent review](research/arithmetic-review.md), and
[Swift Crypto fit proposal](research/swift-crypto-fit.md) describe scope and next
steps. Saved evidence records local macOS runs; no hosted CI result is claimed.
This private test repository contains the original experiment commit plus a
packaging commit for these reports. The library, tests and fixtures are unchanged.
