# Fixture provenance

## Official BIP341 cases

`bip341-taptweak.json` extracts all seven entries from `scriptPubKey` in the
[official wallet vectors](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0341/wallet-test-vectors.json).
The pinned bitcoin/bips revision is
`927b6de9915c9262615a6399de51b200f81e5aa4`, retrieved 2026-10-19.

For each zero-based source index, the extraction copies
`given.internalPubkey`, `intermediary.merkleRoot` (including null), and
`intermediary.tweak`. The last field is renamed `expectedTweak`. No expected
hashes were recomputed. The no-tree case hashes the internal key alone; the
remaining six cases append the provided Merkle root. Unneeded scripts,
transactions, signatures and private-key data are omitted.

The upstream file was byte-identical to the copy in Winnow revision
`6566871db0a40be481dd63b7960790ef4de9192e` used in the initial research.

SHA-256 of original upstream file:
`403e19fb81dd1f31e745699216308f61fb403774b2aafa87b631b8f7c042d37f`

SHA-256 of extracted fixture:
`c0a82588e04dbb40547b5e45b851ea0d51d1f6822f8f9b73ea661f3eef473892`

BIP341 authors: Pieter Wuille, Jonas Nick and Anthony Towns. The specification
declares BSD-3-Clause licensing. See the package's third-party notices.

## Independent boundary answers

`libsecp-tagged-hash.json` contains answers generated on 2026-10-19 by calling
`secp256k1_tagged_sha256(secp256k1_context_static, ...)` from the C source
vendored in swift-secp256k1 **0.23.2**, commit
`e70a10e036a55fffea31568f0af92d69b6d449cd`.

The cases are:

- Empty tag and empty message, both passed with length zero.
- 129 ASCII `t` bytes as the tag, with message bytes `0x00...0x40` (65 bytes).
- UTF-8 bytes for `tag\u0000é` as the tag, with message `00ff0080`.

A standalone C probe linked the already-built `secp256k1.c.o`,
`precomputed_ecmult.c.o` and `precomputed_ecmult_gen.c.o`, and printed the 32-byte
result for each case. The probe and C library were outside this package and
are not build, test or runtime dependencies. Reproduction uses the pinned
library's public tagged-hash API with the explicit bytes above; JSON string
escaping does not change the tag bytes.

Pinned oracle source:
[Sources/libsecp256k1/src/secp256k1.c](https://github.com/21-DOT-DEV/swift-secp256k1/blob/e70a10e036a55fffea31568f0af92d69b6d449cd/Sources/libsecp256k1/src/secp256k1.c)

SHA-256 of that source:
`6a3cad3929bfd49c8f99d36c3e949f4067380dd40c4ba6b81a1ddc608fc65fd4`

SHA-256 of generated boundary fixture:
`8b346d1830842b7ab7c6e6f87850c2b60f2d80dc7381292abcdbcff2ab232a48`

These boundary fixtures are derived outputs of a separate implementation, not
official BIP vectors. They are kept distinct from the official cases.

## Public field and x-only validation fixtures

Added in the isolated first pass on 2026-10-19. `field-arithmetic.json` contains
2,624 pairs: 1,600 Cartesian combinations of 40 edge values and 1,024
SHA-256-derived public pairs. Each expected sum, product and negation is computed
with Python arbitrary-precision integers modulo p, independently of Swift.
`field-roots.json` contains 168 root/nonresidue answers from Python `pow`.
`xonly-validation.json` contains 318 cases (306 distinct x encodings): all 19
BIP340 public-key columns, 43 boundaries and 256 synthetic public inputs.
Both pinned oracles agree on every result, including exact even y coordinates:
167 valid cases and 151 invalid cases. Signature-verification booleans from the
BIP340 CSV are not used as key-validity answers.

Pinned sources:

- [BIP340 reference](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0340/reference.py), SHA-256 `4b1d4ad9e60820df4a6d239733d52b014bc03e4c47afd757a2fe4d3b586d892c`.
- [BIP340 CSV](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0340/test-vectors.csv), SHA-256 `34c9d1d9c3a88d524bc80778540dc43f8306ec249a7485293063c376db851c2d`.
- [libsecp256k1 v0.7.1](https://github.com/bitcoin-core/secp256k1/tree/1a53f4961f337b4d166c25fce72ef0dc88806618), separate from Winnow's P256K dependency.

The C probe calls `secp256k1_xonly_pubkey_parse` and separately parses the even
compressed point, then serializes its full coordinates. The original oracle
binary's SHA-256 is `b6a7b095e2000cdc612445928ccc43470f3c44206242647bc6a0fc00a4dc0c88`.
Binary hashes may differ with toolchain/build paths; the source revisions,
commands and deterministic fixture hashes are the portable reproduction evidence.

[Reproduction instructions](../../../Tools/README.md) and the accompanying
`reproduce_oracles.sh` preserve the exact Clang build commands and regeneration
procedure. It was run successfully from fresh pinned checkouts, with
byte-identical fixture results. Normal Swift tests use JSON and do not build C.
The package-level `SHA256SUMS` records final fixture and source hashes.
