# Research safety and reporting

This is experimental public-data arithmetic. There is no supported production
release, no signer, no full signature verifier and no independent human
cryptographic audit. No version is approved here for protecting real funds.
The arithmetic is variable time and must not process private keys, secret
nonces or shared secrets.

A wrong result still matters on public data. Canonical parsing, field carry and
borrow handling, reduction, square-root existence and even-y selection can fail
independently. A key accepted by this package is not proof of a valid signature,
key ownership, a correct address or a correct wallet spending policy. Repeated
valid-length inputs also incur arithmetic work; no application-level resource
budget or denial-of-service benchmark has been established.

The recorded tests cover bounded cases on one macOS toolchain. They do not
establish constant-time behavior, exhaustive input correctness, iOS support,
secret erasure, performance or suitability for wallet integration. A separate
agent reviewed the sources, but agents can share mistakes. Review evidence and
its exact file hashes are in [the research review](research/arithmetic-review.md).

For a finding confined to this public-input experiment, an issue can include the
commit, toolchain, public input, expected result, actual result and reproduction
command. Use public vectors or synthetic inputs. Do not include wallet seeds,
private keys, live signing nonces, credentials or someone else's private data.
If a finding also affects another project, follow that project's disclosure
process before posting details here. No response-time commitment or security
support contract is implied.
