import Foundation

/// Canonical integers modulo secp256k1's group order, for PUBLIC data only.
///
/// This variable-time type is intentionally distinct from field elements modulo
/// p. It must not hold private keys, signing nonces or any other secret scalar.
internal struct PublicScalar: Equatable, Sendable {
    // Exactly 32 big-endian bytes, encoding an integer strictly less than n.
    private let bytes: [UInt8]

    private static let order: [UInt8] = [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe,
        0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b,
        0xbf, 0xd2, 0x5e, 0x8c, 0xd0, 0x36, 0x41, 0x41,
    ]

    internal static let zero = PublicScalar(canonicalBytes: Array(repeating: 0, count: 32))
    internal static let one = PublicScalar(canonicalBytes: Array(repeating: 0, count: 31) + [1])

    /// Accepts exactly 32 public bytes with value less than n. Zero is valid.
    internal init?(bigEndian: Data) {
        guard bigEndian.count == 32 else { return nil }
        let parsed = Array(bigEndian)
        guard parsed.lexicographicallyPrecedes(Self.order) else { return nil }
        bytes = parsed
    }

    /// Reduces exactly 32 public bytes modulo n, for a SHA-256 challenge.
    /// Since 2^255 < n, a 256-bit input is less than 2n; one subtraction suffices.
    internal init?(reducingBigEndian: Data) {
        guard reducingBigEndian.count == 32 else { return nil }
        let parsed = Array(reducingBigEndian)
        bytes = parsed.lexicographicallyPrecedes(Self.order) ? parsed : Self.subtractOrder(parsed)
    }

    private init(canonicalBytes: [UInt8]) {
        bytes = canonicalBytes
    }

    internal var bigEndian: Data { Data(bytes) }

    /// Reads bit 0 (least significant) through bit 255 (most significant).
    /// The index is an internal algorithm constant, never an unvalidated input.
    internal func bit(at index: Int) -> Bool {
        precondition((0..<256).contains(index))
        return bytes[31 - index / 8] & (UInt8(1) << (index % 8)) != 0
    }

    // Requires value >= n. The caller's unsigned lexicographic comparison proves it.
    private static func subtractOrder(_ value: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            let difference = Int(value[index]) - Int(order[index]) - borrow
            if difference < 0 {
                result[index] = UInt8(difference + 256)
                borrow = 1
            } else {
                result[index] = UInt8(difference)
                borrow = 0
            }
        }
        return result
    }
}
