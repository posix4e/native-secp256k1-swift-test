# Winnow native Swift cryptography first pass

Completed 19 October 2026. The isolated package now validates public BIP340
x-only keys with native Swift field arithmetic. It rejects malformed lengths,
x coordinates outside the field and coordinates with no curve point, then
returns the canonical even-y point. This is a completed public-data milestone,
not a full verifier or a replacement for Winnow's P256K dependency.

The package was copied from the tagged-hashing starter; its original hash
implementation, tests and fixtures remain byte-identical. All work used this
task's files and fresh clones. No production wallet source was changed, no
website was published and no maintainers were contacted. The supplied research
and explainer pages returned access errors, including HTTP 403, so no claims
here rely on their contents.

The [capability matrix](capability-scope-matrix.md) accounts for all ten
production files importing P256K at Winnow revision
`6566871db0a40be481dd63b7960790ef4de9192e`. Schnorr still needs secp256k1 group
arithmetic. BIP32 and Taproot need scalar and point tweaks; Winnow's MuSig2
implementation also needs point addition, multiplication, negation and scalar
arithmetic. The production census found no ECDSA or ECDH caller. A development
signet miner uses ECDSA, and Silent Payments would add ECDH beyond today's minimum.

The [Swift package](../README.md) has zero third-party package
dependencies. It retains Apple CryptoKit hashing and adds an internal field
type modulo p = 2²⁵⁶ − 2³² − 977 plus `ExperimentalXOnlyPublicKey`. The field
supports canonical encoding, addition, multiplication, negation and square
roots. The arithmetic is variable time and explicitly restricted to public data.
No secret-operation or production-readiness claim follows from these tests.

| Evidence | Result and limits |
|---|---|
| Swift tests | Seven tests in two suites passed in both debug and release on Apple Swift 6.4, arm64 macOS 27.0.1. The default build failed before tests on resource-bundle codesigning; the deprecated native build-system fallback succeeded. |
| Field arithmetic | 2,624 operand pairs checked against Python arbitrary-precision addition, multiplication and negation modulo p. Includes all 1,600 combinations of 40 boundary values plus 1,024 synthetic pairs. |
| Square roots | 168 cases checked against Python modular exponentiation, including zero and nonresidues. A separate agent audit checked roots by squaring and nonresidues using Euler's criterion. |
| X-only validation | 318 cases, containing 306 distinct encodings; 167 valid and 151 invalid outcomes. Every expected result, including exact even y, agreed between pinned BIP340 Python and libsecp256k1. Includes all 19 official BIP340 public-key columns, not signature-verification tests. |
| Input handling | Wrong lengths from 0 through 64 except 32, plus 255 and 1,024 bytes; x = p, p+1 and maximum 256-bit integer; nonzero-index Data slices and retained immutable values. |
| Existing tagged hashes | Ten known answers retained: seven BIP341 cases and three libsecp256k1 boundary cases. |
| Measured coverage | Debug LLVM reports 151/151 executable library lines, 64/64 regions and 15/15 instrumented functions executed across three source files. No Swift branch counters were emitted. This is execution coverage, not exhaustive input coverage, a CRAP score or security certification. |
| Independent agent review | No actionable defect found in the identified source hashes. Carry, borrow, reduction termination, root exponent, parsing, state and test independence are recorded in the [review](arithmetic-review.md). This is not an independent human cryptographic audit. |

The runnable package is pinned by local commit
`08c955433be034ea3379e9c0f943c5a193a6c0ad` and its `SHA256SUMS`. Implementation,
tests and JSON fixtures match the tested and reviewed bytes; documentation was
finished after the runs. [Validation metadata](evidence/validation-metadata.json),
[debug log](evidence/swift-debug-native.log), [release log](evidence/swift-release-native.log)
and [coverage summary](evidence/llvm-coverage-summary.txt) preserve the evidence.
Oracle reproduction from fresh pinned checkouts produced byte-identical fixtures.
The [reproduction script](../Tools/reproduce_oracles.sh) preserves the
source pins and exact Clang commands; ordinary Swift tests use stored JSON only.

From the package directory, the verified host commands are:

```sh
swift test --build-system native --enable-code-coverage
swift test --build-system native -c release
```

Full BIP340 verification is the next milestone. Add public scalar decoding and
challenge reduction modulo n, point addition/doubling/multiplication with an
explicit infinity representation, and verification of sG − eP. Require the
complete official BIP340 signature suite, independent differential checks,
invalid r/s boundaries, infinity and parity cases, and arbitrary message lengths
before declaring that milestone complete. No signer belongs in that increment.

The [Swift Crypto fit note](swift-crypto-fit.md) proposes an opt-in component
with an internal Swift kernel, narrow typed API and platform hashing adapter.
This is a proposed design, not an implemented Swift Crypto integration.
At the pinned revision, Swift Crypto requires usable BoringSSL support for new
APIs and prior maintainer agreement; its existing CryptoExtras dependency graph
retains BoringSSL on Apple. Native Swift secp256k1 therefore needs a policy and
placement decision. No maintainer agreement is implied.

The successive gates remain **public verification → reviewed secret operations
→ app integration → signed device builds → internal TestFlight**. This pass
completes only x-only validation within the first gate. It does not measure
constant-time behavior, secret erasure, performance, energy or binary-size
improvement. iOS, older Swift/OS versions and non-Apple platforms remain untested.
Randomness is unnecessary for public validation; future secret operations must
use reviewed platform randomness and nonce ownership. No credentials, device
signing, distribution upload or real funds were needed.
