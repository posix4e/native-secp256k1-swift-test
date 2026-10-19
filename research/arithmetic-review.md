# Independent review of the public-data arithmetic milestone

Reviewed 19 October 2026. No actionable arithmetic, parsing, or oracle-correctness defect was found in the exact files identified below. This conclusion applies to the experimental public-data field and x-only validation scope. It is an independent agent's source review and fixture audit, not a cryptographic security audit, formal verification, constant-time certification, or approval for secrets or production integration.

All methods and initializers in `PublicFieldElement.swift` and `ExperimentalXOnlyPublicKey.swift`, plus the new test suite and both fixture-generation tools, were read. No implementation or test files were changed by the reviewer. No CRAP score or coverage percentage is claimed; neither was measured in this review.

| Area | Review outcome |
|---|---|
| Canonical representation and parsing | Eight little-endian 32-bit limbs represent integers strictly below `p = 2^256 − 2^32 − 977`. The byte initializer requires exactly 32 bytes and rejects `p` and larger values instead of reducing them. Conversion through an array handles nonzero `Data` slice indices. All private constructor call sites preserve length and canonicality. Serialization emits exactly 32 big-endian bytes. |
| Addition and multiplication | For `B = 2^32`, addition's accumulator is at most `2B − 1`. Multiplication's accumulator is bounded by `(B−1)^2 + (B−1) + (B−1) = B^2−1`, exactly `UInt64.max`; intermediate nonnegative additions also fit. The row carry is at most `B−1`. Earlier rows cannot have written the final carry destination at `left+8`. The full 16-word product is preserved. |
| Borrow and negation | Subtraction is called only with `lhs ≥ rhs`. `rhsWord + borrow ≤ B`; the underflow branch computes a value in `0..<B` without overflowing `UInt64`. Zero has a dedicated negation case, and nonzero `p−a` is canonical. |
| Modular reduction | Folding uses `B^8 ≡ B+977 (mod p)`. Initially each low accumulator is at most `979(B−1)`; incoming carry keeps it below `979B`, hence below `2^42`. After normalization, the high word is at most `B+977`. Folding it back represents less than `B^8+(B+977)^2`, so the next high is at most one. If it is one, the remaining low value is less than `(B+977)^2`; adding `B+977` cannot overflow `B^8`. Thus at most two loop iterations suffice. Afterward the value is below `B^8 < 2p`, so one conditional subtraction produces a canonical result. This argument covers any 16 input limbs and therefore all addition and multiplication outputs. |
| Square roots | The stored exponent reconstructs `(p+1)/4`; `p ≡ 3 (mod 4)`. The loop scans its bits from most to least significant. The final square comparison rejects nonresidues and handles zero correctly. Root parity is examined only after canonical reduction. |
| X-only validation | The initializer checks `x < p`, evaluates `x^3+7`, rejects a missing square root, and chooses the even root. This matches the pinned BIP340 `lift_x` procedure. It performs no signature verification or secret operation. |
| State, failure handling, and concurrency | Values contain immutable arrays or `Data`; there is no global mutable state, nonce lifecycle, or session state. Invalid public inputs return `nil`. Allocation and comparison timing vary, as documented. `Sendable` is consistent with the value members, but no concurrency stress test or timing analysis was performed. |

The reference rule is [BIP340 `lift_x` at `927b6de9915c9262615a6399de51b200f81e5aa4`](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0340/reference.py#L78-L85). The C oracle calls the [libsecp256k1 x-only parser at `1a53f4961f337b4d166c25fce72ef0dc88806618`](https://github.com/bitcoin-core/secp256k1/blob/1a53f4961f337b4d166c25fce72ef0dc88806618/src/modules/extrakeys/main_impl.h#L22-L44) and separately parses the even compressed point to obtain its public y coordinate.

The fixture expectations are independent of the Swift implementation. Addition, multiplication, and negation use Python arbitrary-precision integers. Root generation uses Python modular exponentiation. X-only fixtures require agreement between the pinned BIP340 Python reference and the C oracle. The generator takes only the public-key column from all 19 BIP340 CSV rows: it correctly avoids treating signature-verification booleans as key-validity answers. The C oracle validates input length and hexadecimal characters, checks agreement between full and x-only parsing, checks serialization success and length, and checks even parity. It has no secret-key inputs.

The reviewer separately audited all 2,624 arithmetic pairs using integer division/remainders; all 168 root cases using the curve equation and Euler's criterion for nonresidues; and all 318 x-only cases using the range, curve equation, Euler's criterion, and an independent invocation of the existing C oracle. All passed. The 318 cases contain 167 valid and 151 invalid outcomes; these are case counts, not a claim of 318 distinct keys. All 19 public-key columns were matched back to the pinned CSV. Malformed C-oracle inputs returned the documented nonzero exits. The review script and result remain in this task's `work/` directory.

The observed debug Swift Testing log reports seven tests passing, including all five new field/x-only tests, under the native build-system fallback. This reviewer did not run another Swift package build concurrently. The task's final validation report must state its own debug/release results and the default build-system signing failure accurately. The mathematical and fixture audit does not replace running the Swift implementation. Bounded vectors do not prove all inputs correct; public-key cases do not constitute the full BIP340 signature suite. This review establishes no speed, energy, binary-size, compiler-side-channel, iOS-device, or memory-erasure result.

For reproducibility, the generator verifies clean tracked source revisions but accepts a separately supplied C-oracle executable. Its provenance therefore also depends on the recorded build command and binary identity. The oracle used in this audit had SHA-256 `b6a7b095e2000cdc612445928ccc43470f3c44206242647bc6a0fc00a4dc0c88`. Record the new fixture-generation commands and provenance in the final package documentation. This is an evidence-documentation requirement, not an arithmetic defect.

Reviewed source and fixture SHA-256 values (paths relative to `outputs/NativeSecp256k1/`):

| File | SHA-256 |
|---|---|
| `Sources/NativeSecp256k1/PublicFieldElement.swift` | `4a6a4434730a2f5ffd7389daf0293f6f5b615a00904fb1aad716caf2302ce719` |
| `Sources/NativeSecp256k1/ExperimentalXOnlyPublicKey.swift` | `7f1ed3c0628e1b26fc83c4488c7d6b30d91f619ffdfd2c03f433ab55019a0b63` |
| `Tests/NativeSecp256k1Tests/PublicFieldTests.swift` | `e60bb335a16d876c1d3fcf174f07acec93d53d810ae0d104ffa01eb85320817b` |
| `Tools/generate_vectors.py` | `bf51c4304cb2a185314ebfa6cfd0fcbd97769591dbb9442ef8ace4ca3a64b837` |
| `Tools/xonly_oracle.c` | `16238d8a4a9be712130a91b23cf7dc3f76445bc08a9bd98d555c0f9c529f1b64` |
| `Tests/NativeSecp256k1Tests/Fixtures/field-arithmetic.json` | `cfe1d21d4dabf6ce628e29b7ef1c9dd00454cc4d9edae9126aaaeff4a67d31f2` |
| `Tests/NativeSecp256k1Tests/Fixtures/field-roots.json` | `79e2684a8fd4d35cd8df6930cb20295101626746f2b967200c258c1b452cfb86` |
| `Tests/NativeSecp256k1Tests/Fixtures/xonly-validation.json` | `e2c1e6f7a544afc8b00bae9bbdc689dd0d818f872fe71da179b9605e4b0ef79c` |

Any change to those files requires checking the applicable review conclusions again. The next code milestone should stay within public verification and add independently checked point operations before attempting BIP340 signature verification. Secret operations require a later, separate review gate.
