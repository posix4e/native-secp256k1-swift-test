# Public BIP340 verification milestone

The native Swift experiment now verifies BIP340 signatures over public data.
It is a concrete step toward Winnow's native secp256k1 backend. It is not yet a
wallet replacement: signing, private derivation, public tweak APIs and MuSig2
primitive parity remain in the [migration plan](native-swift-roadmap.md).
The library has no package dependencies; SHA-256 uses system CryptoKit.

This report covers the source/test/resource set recorded in
[evidence/bip340/bip340-tested-files.json](evidence/bip340/bip340-tested-files.json),
built from the prior published baseline `2ef204167972efc428486e823fc79b1f1bf0e9e7`.
All recorded files stayed byte-identical across the final local runs. The
package-level `SHA256SUMS` also identifies the published source and documents.
The first-pass report and its coverage remain historical evidence for their
own revision.

Implemented behavior:

- Exact 32-byte x-only public keys and 64-byte signatures. Malformed input
  returns false; no implicit sighash-byte stripping, padding or prehashing.
- Canonical field/scalar bounds: r < p and s < n. Zero is a valid public scalar.
  Challenge reduction modulo n is a separate operation from strict parsing.
- Arbitrary message bytes, including empty messages. The challenge hashes
  exactly r || public key || message with the BIP0340/challenge tag.
- Jacobian public point addition, doubling, negation and multiplication,
  field inversion with zero rejection, and explicit infinity handling.
- R = sG − eP, requiring finite R, even y and x = r.

The [BIP340 specification](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0340.mediawiki#verification)
and [EFD Jacobian formulas](https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian.html)
were checked against the implementation. Separate agents reviewed field/point
code and scalar/verifier code, including exceptional cases and offset Data
inputs. No actionable discrepancy was found in that review. This is agent
review, not an independent human cryptographic audit.

| Check | Recorded result |
|---|---|
| Official BIP340 signatures | All 19 decisions agree: 9 valid, 10 invalid; includes arbitrary-message-length rows |
| Generated differential signatures | All 184 decisions agree with pinned libsecp256k1 and BIP340 Python: 32 valid, 152 invalid; 24 message lengths from 0 to 4,096 bytes |
| Independent public point answers | 55 additions, also checked with reversed operands; 26 scalar multiplications; 25 inverses |
| Retained field/key/hash evidence | 2,624 field pairs, 168 roots, 318 x-only inputs and ten tagged-hash answers |
| macOS Debug with coverage | 29 tests / 6 suites passed, 20.414 seconds |
| macOS Release | 29 tests / 6 suites passed, 0.512 seconds |
| iOS simulator Debug | 29 passed, 0 failed, 0 skipped; 6 suites, 17.576 seconds |
| Fresh oracle reproduction | Exact pinned source checkouts fetched and C rebuilt; all generated fixtures byte-identical |
| Mutation tests | Removing parity, removing x equality, or changing the challenge tag each compiled and caused actual assertion failures; restored baseline passed |

The macOS runs used arm64 macOS 27.0.1, Apple Swift 6.4
(`swiftlang-6.4.0.34.1`), Xcode 27.1 (`27A9275`) and the default build system.
Commands used a new scratch directory under `/private/tmp`:

```sh
swift test --scratch-path /path/to/scratch --configuration debug --enable-code-coverage
swift test --scratch-path /path/to/scratch --configuration release
```

The default build system succeeded with that scratch location. The original
Documents-directory resource-metadata failure does not require disabling
signing or using the deprecated native fallback for these runs.

The simulator run used iPhone 17 Pro, arm64 iOS 27.0 (`24A434`), the iOS Simulator
27.1 SDK and Xcode's package test scheme. It preserved the default simulator
signing behavior and needed no developer-account credentials. Its result bundle
reported 29 passes independently of the console log. Two nonfatal build warnings
(a clang sysroot mismatch and skipped AppIntents metadata extraction) remain in
the local log; no runtime warnings were reported. This is not a physical-device,
iOS 17, iOS Release or TestFlight result.

Test durations describe these test runs; they are not latency, throughput,
energy or cross-library benchmarks. The new GitHub workflow runs default-build
macOS Debug and Release tests and checks recorded file hashes. Hosted results
are separate evidence on the pull request; the table above records local runs.

The generated corpus includes key/r/s/message mutations, canonical bounds,
constructed infinity for r = 0 and r = 1, an equation with matching x but odd y,
and malformed lengths. The C adapter rejects wrong lengths before calling C's
fixed-size APIs. It does not test undersized C allocations. The 32 generated
valid signatures also agree byte-for-byte with Python signing. All generator
scalars and auxiliary bytes are predictable public test data, never wallet keys.
See [reproduction and provenance](../Tools/schnorr-fixtures.md).

Mutation testing ran in a disposable copy without changing the checked-in tests.
Removing even-y acceptance caused three assertion failures, including official
case 6 and the generated odd-y case. Removing x equality caused 68 failures,
including official cases 8 and 11. A wrong challenge tag caused 46 failures,
including every valid official signature. Baseline and restored baseline each
passed all four verification-suite tests, and the restored files matched the
published source. These three mutations establish that specific mistakes are
detected; they are not a comprehensive mutation score.

LLVM coverage for the six library sources reports 298/298 executable lines,
37/37 functions and 133/134 regions. The uncovered region is the defensive
failure return when parsing a challenge digest with an impossible length:
CryptoKit SHA-256 always supplies 32 bytes. Swift emitted no branch or MC/DC
counters. No cases were excluded or relabeled to improve this measurement.
This is not a CRAP measurement, an exhaustive correctness argument or a security
certification.

All arithmetic remains variable time. Branching, allocation, equality and
scalar multiplication depend on public input. Using these types with private
keys or secret nonces would require a different security design. Public inputs
can still cause wrong verification decisions if there is an undiscovered bug,
or consume substantial CPU and memory under sustained workloads. Hashing and
copying costs also scale with message size. No adversarial resource budget,
constant-time analysis, secret-lifetime guarantee, formal proof or human audit
has been established.

A verified signature only checks its supplied key and message. Winnow must
still calculate the correct transaction digest, preserve PSBT and threshold
failure semantics, and validate derivation/tweak outputs before replacing its
current backend. The previously validated Winnow fixed-vector demo remains
pinned to the earlier package and has not been tagged or uploaded in this work.
Its CI is not evidence for wallet use of the new verifier.

Published log copies normalize local paths and trailing whitespace; local
originals and the full simulator result bundle were retained.

Saved evidence: [validation metadata](evidence/bip340/validation-metadata.json),
[Debug log](evidence/bip340/bip340-final-debug.log),
[Release log](evidence/bip340/bip340-final-release.log),
[simulator result summary](evidence/bip340/bip340-ios-summary.json),
[coverage summary](evidence/bip340/bip340-coverage-summary.json),
[oracle reproduction](evidence/bip340/schnorr-oracle-reproduction.log),
[mutation summary and logs](evidence/bip340/mutation-summary.json), and
[additional agent review](evidence/bip340/bip340-scalar-verifier-review.txt).
