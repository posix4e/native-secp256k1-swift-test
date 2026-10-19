# Third-party fixture notices

The test fixture `bip341-taptweak.json` contains selected values from the
bitcoin/bips BIP341 wallet test vectors. BIP341 names Pieter Wuille, Jonas Nick
and Anthony Towns as authors and states: "This document is licensed under the
3-clause BSD license."

Source and license declaration:
https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0341.mediawiki

BSD-3-Clause terms:

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The separate boundary fixture contains hash outputs obtained from
swift-secp256k1 0.23.2/libsecp256k1. No source code from that implementation is
copied or linked into this package. The pinned oracle is attributed in
`Tests/NativeSecp256k1Tests/Fixtures/README.md`.


The x-only fixture includes public-key fields from the BIP340 test vectors.
The verification fixture additionally includes their public message, signature,
expected-verification result and explanatory fields; it omits private-key and
auxiliary-randomness columns. The same license selection below applies.
BIP340 names Pieter Wuille, Jonas Nick and Tim Ruffing as authors. At pinned
revision `927b6de9915c9262615a6399de51b200f81e5aa4`, its code and test vectors are
available under BSD-2-Clause OR MIT OR CC0-1.0; this extraction uses CC0-1.0.
See the [pinned license declaration](https://github.com/bitcoin/bips/blob/927b6de9915c9262615a6399de51b200f81e5aa4/bip-0340.mediawiki#copyright)
and [CC0 1.0 terms](https://creativecommons.org/publicdomain/zero/1.0/legalcode).
The expected curve coordinates and arithmetic outputs are derived numeric
results. The BIP340 reference and libsecp256k1 source are external oracle tools;
none of their implementation source is vendored or linked into the Swift product.
