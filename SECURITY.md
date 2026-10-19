# Research safety and reporting

This is experimental public-data arithmetic and BIP340 signature verification.
There is no supported production release, signer or independent human
cryptographic audit. No version is approved here for protecting real funds.
The arithmetic is variable time and must not process private keys, secret
nonces or shared secrets.

A wrong result still matters on public data. Canonical parsing, field carry and
borrow handling, reduction, square-root existence and even-y selection can fail
independently. Point addition, doubling, inversion, scalar modulus selection,
challenge hashing, infinity and parity checks add new failure cases. A key
accepted by the key parser is not proof of a valid signature. A successful
verifier result checks the supplied key, message and signature; it does not
establish a correct address, transaction digest or wallet spending policy.
Repeated valid-length inputs incur arithmetic work, and message hashing/copying
scales with message length. No application-level resource budget or
denial-of-service benchmark has been established.

The recorded tests cover bounded cases on their named toolchains. They do not
establish constant-time behavior, exhaustive input correctness, iOS support,
secret erasure, performance or suitability for wallet integration. A separate
agent reviewed the sources, but agents can share mistakes. The earlier field
[research review](research/arithmetic-review.md) applies to its recorded revision.
New group/scalar/verifier evidence is in the
[verification report](research/bip340-verification-report.md), with exact hashes.
The historical first-pass coverage percentage must not be applied to new code.

For a finding confined to this public-input experiment, an issue can include the
commit, toolchain, public input, expected result, actual result and reproduction
command. Use public vectors or synthetic inputs. Do not include wallet seeds,
private keys, live signing nonces, credentials or someone else's private data.
If a finding also affects another project, follow that project's disclosure
process before posting details here. No response-time commitment or security
support contract is implied.
