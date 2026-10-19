# Continuing Winnow's native Swift backend

The destination is native Swift secp256k1 for the operations Winnow actually
uses, with CryptoKit for standard hashes and platform services. P256K/libsecp256k1
remains an independent reference and Winnow's current backend during the work.
Keeping that reference during migration does not change the destination.
No claim is made that CryptoKit or the operating system is implemented entirely
in Swift, or that this package is accepted by Swift Crypto maintainers.

The initial call-surface inventory was made against Winnow
`6566871db0a40be481dd63b7960790ef4de9192e`; changes to the application require
rechecking that inventory. See the historical capability matrix for file-level
references. The minimum production surface is wider than Schnorr sign/verify.

| Stage | Required behavior and evidence | Current state |
|---|---|---|
| Public verification | Canonical field/scalar parsing, point group operations, BIP340 signature verification; official invalid cases and independent differential oracles | Implemented in this research milestone; results in the accompanying report |
| Public derivation and tweaks | Compressed public-key parsing/serialization, BIP32 public-child operations, Taproot/BIP86 tweaks with parity; reject invalid tweaks and infinity using each caller's existing semantics | Next implementation stage |
| Secret arithmetic and single-signer operations | Separate secret-safe scalar/field representation and multiplication, public-key derivation, private BIP32/tweaks, BIP340 nonce generation and signing | Not implemented; public variable-time arithmetic is not a starting safety guarantee |
| MuSig2 primitive parity | Public aggregation and point/scalar operations required by Winnow's orchestration; one-use secret-nonce ownership across copies, retries, cancellation, crashes and concurrency | Not implemented |
| Wallet replacement and beta | Replace production P256K calls, validate addresses/PSBTs/signatures and error behavior, replay Bitcoin Core workflows, supported toolchains and devices, signed internal beta, then external review | Not implemented |

For public derivation, scalar zero must remain representable independently of a
nonzero private key. An invalid encoding must remain distinguishable from the
point at infinity. A Taproot tweak at least n is rejected, not silently reduced.
BIP32 has its own invalid-child handling. Public key parity must be returned
explicitly where the wallet needs it. These are protocol requirements, not UI
choices.

Secret operations need more than passing vectors. Review must cover compiled
execution on supported toolchains and hardware, secret-dependent branches and
memory access, allocation/copy behavior, key lifetime, randomness failures and
fault handling. The present public arithmetic contains input-dependent work.
A label saying "experimental" does not make it suitable for signing real funds.
A separate agent review is useful engineering feedback, not an independent
human cryptographic audit.

MuSig2 orchestration already belongs to Winnow, but its backend uses point and
scalar operations beyond ordinary signing. Nonces must be consumed once across
all aliases and failure paths. Generic Swift value semantics or `Sendable`
conformance alone cannot enforce that property.

The development-only SignetMiner ECDSA/DER dependency is outside the current
production wallet minimum and should remain separately identified. ECDH/Silent
Payments has no production call in the inspected revision and is not silently
included in this minimum. If either becomes a product requirement, update the
scope and tests before claiming replacement is complete.

Winnow's optional fixed-vector research screen is prepared separately in
[PR #234](https://github.com/winnowwallet/winnow/pull/234). Its exact candidate
`8735394cf95690ab2a9d75950be43ccf29d2a2d3` passed full CI and manual release
validation, but has not been tagged or uploaded for TestFlight in this work.
Its pinned package remains the earlier key validator. That demonstration is
on hold while the native backend advances; it is not the endpoint of this plan.
Its successful UI and wallet tests do not validate the new verifier or future
wallet integration.
