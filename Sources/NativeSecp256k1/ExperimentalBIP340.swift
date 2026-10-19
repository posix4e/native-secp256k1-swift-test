import Foundation

/// Experimental, variable-time verification of PUBLIC BIP340 signatures.
///
/// This API has not received an independent human cryptographic audit. It does
/// not implement signing, nonce generation or any operation on secret scalars.
/// A successful result is a signature check, not a transaction-policy decision.
public enum ExperimentalBIP340 {
    /// Verifies a 64-byte signature for an exact 32-byte x-only public key.
    ///
    /// Messages may contain any number of bytes, including zero. No prehashing,
    /// truncation, sighash-byte removal or Bitcoin transaction hashing is implicit.
    /// Wrong encodings, invalid points and incorrect signatures return false.
    /// Runtime depends on public inputs; callers must bound workload as needed.
    public static func verify(signature: Data, message: Data, publicKey: Data) -> Bool {
        guard signature.count == 64, publicKey.count == 32 else { return false }
        guard let point = liftPublicKey(publicKey),
              let r = PublicFieldElement(bigEndian: signature.prefix(32)),
              let s = PublicScalar(bigEndian: signature.suffix(32)) else { return false }

        var challengeInput = r.bigEndian
        challengeInput.append(publicKey)
        challengeInput.append(message)
        let digest = TaggedSHA256.hash(tag: "BIP0340/challenge", message: challengeInput)
        guard let challenge = PublicScalar(reducingBigEndian: digest) else { return false }

        let candidate = PublicPoint.generator.multiplied(by: s)
            .adding(point.multiplied(by: challenge).negated())
        // Infinity has no affine coordinates, and must be rejected explicitly.
        guard let affine = candidate.affineCoordinates else { return false }
        return !affine.y.isOdd && affine.x == r
    }

    private static func liftPublicKey(_ bytes: Data) -> PublicPoint? {
        guard let key = ExperimentalXOnlyPublicKey(rawRepresentation: bytes),
              let x = PublicFieldElement(bigEndian: key.rawRepresentation),
              let y = PublicFieldElement(bigEndian: key.evenYRepresentation) else { return nil }
        return PublicPoint(x: x, y: y)
    }
}
