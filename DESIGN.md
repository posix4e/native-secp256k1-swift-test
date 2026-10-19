# Bitcoin Schnorr and key operations

The library is an independent research implementation intended to be useful to
Winnow and other Bitcoin applications. A possible future contribution to
apple/swift-crypto is a design goal, not an accepted upstream feature. The
currently implemented APIs are `TaggedSHA256.hash(tag:message:)`,
`ExperimentalXOnlyPublicKey.init?(rawRepresentation:)`, and
`ExperimentalBIP340.verify(signature:message:publicKey:)`. The verifier uses
distinct internal field and scalar types, Jacobian point arithmetic and
explicit infinity/parity checks. All arithmetic is variable time and solely
for public data. Secret-key APIs remain future work. See the
[migration plan](research/native-swift-roadmap.md) and
[verification evidence](research/bip340-verification-report.md).

## Library boundary

Keep the fixed-width secp256k1 arithmetic independent of wallet code, Apple
account configuration, network access and persistent key storage. Use separate
field and scalar types internally. Represent scalar zero independently of the
nonzero private-key type, and distinguish invalid point encodings from infinity.
No generic BigInt or custom-curve public API is planned. `PublicScalar` permits
zero, rejects noncanonical external values and separately reduces a 32-byte
challenge modulo n. `PublicPoint` admits finite affine coordinates only after
checking the curve equation; its private Jacobian initializer is restricted to
the identity and group formulas. Infinity has no affine serialization.

The eventual typed API should distinguish compressed public keys, x-only Schnorr
keys, private keys, signatures and tweak results including parity. Verification
operates on the supplied message bytes. The low-level BIP340 API supports
the specification's arbitrary message lengths; an application's transaction
adapter can require exactly 32 bytes. No implicit preliminary message hashing
belongs in that adapter.

Signing should obtain fresh auxiliary randomness through an internal platform
provider. Deterministic auxiliary inputs remain available to the test harness.
Expose secret-key operations only after their arithmetic, compiled execution,
memory ownership and failure behavior have been evaluated. Malformed external
data must produce a defined failure rather than a trap.

Winnow currently owns BIP32 policy, transaction sighashes, PSBTs, Taproot and
MuSig2 orchestration. Replacing its backend requires narrow tweak and group
operations beyond Schnorr sign/verify. The API review must choose whether these
are explicit typed operations or a separate protocol component; copying the
entire P256K API is not the objective. A future MuSig2 session API must own and
consume secret nonces exactly once across aliases, retries and concurrent calls.

## Platform boundary

Apple builds use CryptoKit for SHA-256 and other available standard primitives.
The existing starter directly imports CryptoKit and is Apple-only. Before an
upstream proposal, isolate that hashing adapter from the curve kernel and add
the platforms required by maintainers. A non-Apple Swift Crypto hash adapter
may use C implementations internally; native Swift secp256k1 does not imply
every platform hash or OS service is implemented in Swift.

The public library and its tests must work without an Apple Developer account,
App Store Connect credentials, provisioning profiles, wallet seeds or a Winnow
checkout. App integration and signed TestFlight builds belong to the consumer.

## Potential upstream placement

At swift-crypto revision `0f6f68df04180034ef62e0d5f40195ac3189317a`,
[contribution rules](https://github.com/apple/swift-crypto/blob/0f6f68df04180034ef62e0d5f40195ac3189317a/CONTRIBUTING.md)
require agreement with maintainers before a PR and a usable BoringSSL
implementation for new APIs. A native Swift secp256k1 backend needs a policy
decision. The standard Crypto product re-exports system CryptoKit on Apple;
new code does not automatically become available through existing OS versions.

The preferred proposal is an opt-in component with an internal Swift arithmetic
kernel and a small typed API. Its name, placement and support obligations require
maintainer agreement. CryptoExtras is another possible home, but its current
dependency graph includes BoringSSL on Apple and does not meet a goal of avoiding
bundled C cryptographic code. The independent library remains usable if upstream
chooses a different approach.

## Evidence before integration

1. Implement public-key parsing and BIP340 verification with official valid and
   invalid vectors, independent arithmetic oracles and pinned libsecp comparisons.
2. Add secret operations with deterministic vector comparisons, generated-code
   inspection, memory-lifetime analysis and independent cryptographic review.
3. Prove parity for BIP32 derivation, Taproot tweaks and MuSig2, including scalar
   zero, infinity, malformed input and nonce-lifecycle failures.
4. Run supported-platform build/test matrices, then device benchmarks and
   Bitcoin Core interoperability through the consumer application.

Record source and fixture hashes, toolchain, architecture and optimization
settings with evidence. Keep performance measurements separate from correctness
and side-channel claims. The independent library source is Apache-2.0; imported
test material retains its own provenance and notices.
