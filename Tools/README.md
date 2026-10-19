# Reproducing independent public data fixtures

This page describes the original field and x-only fixture generator. For full
BIP340 signature verification and independent point arithmetic, see the
[signature and point reproduction guide](schnorr-fixtures.md).

Ordinary `swift test` uses checked-in JSON fixtures and needs no network, C build
or Python installation. The optional regeneration path needs Git, Python 3 and
Clang, and fetches public source at exact commits. From the package directory:

```sh
sh Tools/reproduce_oracles.sh /absolute/path/to/new-scratch-directory
```

The scratch directory must not already exist. This script compiles an external
libsecp256k1 oracle and rewrites the three arithmetic/validation JSON fixtures
inside this package. Check the changes; deterministic regeneration should be
byte-identical. It does not build or link C into the Swift library.

The Python generator verifies both checkouts' HEADs and rejects tracked source
changes. It uses arbitrary-precision integer arithmetic for field answers and
imports only the pinned reference's `lift_x` for key answers. The C probe calls
x-only parsing and compressed-point parsing, checks they agree, then serializes
the full even-y point. It fails if either oracle disagrees on validity or on the
exact y coordinate. The generator does not call the Swift code.

Inputs comprise 40 distinct field edge values crossed with each other, 1,024
SHA-256-derived pairs, 40 edge plus 128 derived root inputs, all 19 public-key
columns from the official BIP340 CSV, 43 boundary x inputs and 256 derived x
inputs. The derivation domain is `winnow-public-field-v1`; these predictable
synthetic bytes are PUBLIC test data and are not a source of secret randomness.

Arithmetic answers use Python `% p`, multiplication and `pow`; this is an
independent implementation of the arithmetic, not an unrelated mathematical
specification. The BIP340 Python and C implementations are separate backends
with the same protocol definition. Their agreement is strong differential
evidence for these cases, not a proof for every 256-bit input.

The official CSV's signature-validity boolean is deliberately ignored. An
invalid signature can still contain a valid public key. No signing, signature
verification, wallet seeds or real funds are involved in regeneration.
