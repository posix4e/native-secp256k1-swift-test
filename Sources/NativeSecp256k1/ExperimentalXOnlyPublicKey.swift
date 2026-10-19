import Foundation

/// An experimental validator for PUBLIC BIP340 x-only secp256k1 keys.
///
/// This type checks the field range and the curve equation y² = x³ + 7 and
/// selects the even y coordinate. It does not verify signatures or implement
/// group operations. Its arithmetic is variable time and must never be used
/// with secret material. It has not received a cryptographic security review.
public struct ExperimentalXOnlyPublicKey: Equatable, Sendable {
    /// The canonical 32-byte, big-endian x coordinate.
    public let rawRepresentation: Data

    /// The canonical 32-byte, big-endian even y coordinate, for public inspection.
    public let evenYRepresentation: Data

    /// Validates exactly 32 public bytes using the BIP340 lift_x conditions.
    ///
    /// Returns nil for a wrong length, an x coordinate at least p, or an x whose
    /// curve equation has no square root. This initializer is variable time.
    public init?(rawRepresentation: Data) {
        guard let x = PublicFieldElement(bigEndian: rawRepresentation) else { return nil }
        let square = x.multiplied(by: x)
        let rightHandSide = square.multiplied(by: x).adding(.seven)
        guard let root = rightHandSide.squareRoot() else { return nil }
        let evenRoot = root.isOdd ? root.negated() : root
        self.rawRepresentation = x.bigEndian
        self.evenYRepresentation = evenRoot.bigEndian
    }
}
