import Foundation

/// Experimental arithmetic modulo secp256k1's field prime, for PUBLIC data only.
///
/// This implementation is variable time. Comparisons, reduction, allocation, and
/// equality depend on their inputs. It must not process secret scalars, secret
/// coordinates, nonces, or any other secret material.
internal struct PublicFieldElement: Equatable, Sendable {
    // Canonical little-endian base-2^32 limbs. Every instance is strictly below p.
    private let limbs: [UInt32]

    private static let modulus: [UInt32] = [
        0xfffffc2f, 0xfffffffe, 0xffffffff, 0xffffffff,
        0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    ]
    private static let radix: UInt64 = 1 << 32
    private static let squareRootExponent: [UInt32] = [
        0xbfffff0c, 0xffffffff, 0xffffffff, 0xffffffff,
        0xffffffff, 0xffffffff, 0xffffffff, 0x3fffffff,
    ] // (p + 1) / 4, since p is 3 modulo 4.
    private static let inverseExponent: [UInt32] = [
        0xfffffc2d, 0xfffffffe, 0xffffffff, 0xffffffff,
        0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff,
    ] // p - 2; Fermat inversion is defined only for nonzero field elements.

    internal static let zero = PublicFieldElement(canonicalLimbs: Array(repeating: 0, count: 8))
    internal static let one = PublicFieldElement(canonicalLimbs: [1, 0, 0, 0, 0, 0, 0, 0])
    internal static let seven = PublicFieldElement(canonicalLimbs: [7, 0, 0, 0, 0, 0, 0, 0])

    /// Accepts exactly 32 big-endian bytes encoding an integer strictly below p.
    /// The input must be public; this parser is variable time.
    internal init?(bigEndian: Data) {
        guard bigEndian.count == 32 else { return nil }
        // Data slices need not start at index zero. Array provides zero-based bytes.
        let bytes = Array(bigEndian)
        var parsed = [UInt32](repeating: 0, count: 8)
        for index in 0..<8 {
            let offset = 28 - 4 * index
            parsed[index] = UInt32(bytes[offset]) << 24
                | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8
                | UInt32(bytes[offset + 3])
        }
        guard Self.isLessThan(parsed, Self.modulus) else { return nil }
        self.limbs = parsed
    }

    private init(canonicalLimbs: [UInt32]) {
        self.limbs = canonicalLimbs
    }

    internal var bigEndian: Data {
        var bytes = [UInt8]()
        bytes.reserveCapacity(32)
        for word in limbs.reversed() {
            bytes.append(UInt8(truncatingIfNeeded: word >> 24))
            bytes.append(UInt8(truncatingIfNeeded: word >> 16))
            bytes.append(UInt8(truncatingIfNeeded: word >> 8))
            bytes.append(UInt8(truncatingIfNeeded: word))
        }
        return Data(bytes)
    }

    internal var isOdd: Bool { limbs[0] & 1 != 0 }

    internal func adding(_ other: Self) -> Self {
        var wide = [UInt32](repeating: 0, count: 16)
        var carry: UInt64 = 0
        for index in 0..<8 {
            // At most 2 * (2^32 - 1) + 1, safely inside UInt64.
            let sum = UInt64(limbs[index]) + UInt64(other.limbs[index]) + carry
            wide[index] = UInt32(truncatingIfNeeded: sum)
            carry = sum >> 32
        }
        wide[8] = UInt32(carry)
        return Self(canonicalLimbs: Self.reduce(wide))
    }

    internal func multiplied(by other: Self) -> Self {
        var wide = [UInt32](repeating: 0, count: 16)
        for left in 0..<8 {
            var carry: UInt64 = 0
            for right in 0..<8 {
                let index = left + right
                // With B = 2^32, this is bounded by
                // (B - 1)^2 + (B - 1) + (B - 1) = B^2 - 1.
                // Consequently UInt64 cannot overflow, and carry <= B - 1.
                let sum = UInt64(limbs[left]) * UInt64(other.limbs[right])
                    + UInt64(wide[index]) + carry
                wide[index] = UInt32(truncatingIfNeeded: sum)
                carry = sum >> 32
            }
            // Earlier rows reach at most left + 7; this position is still zero.
            wide[left + 8] = UInt32(carry)
        }
        return Self(canonicalLimbs: Self.reduce(wide))
    }

    internal func negated() -> Self {
        guard self != .zero else { return .zero }
        return Self(canonicalLimbs: Self.subtract(Self.modulus, limbs))
    }

    internal func subtracting(_ other: Self) -> Self {
        adding(other.negated())
    }

    internal func squared() -> Self {
        multiplied(by: self)
    }

    /// Returns the multiplicative inverse of a PUBLIC nonzero element.
    /// Zero has no inverse. This is variable-time modular exponentiation.
    internal func inverted() -> Self? {
        guard self != .zero else { return nil }
        return raised(to: Self.inverseExponent)
    }

    /// Returns a square root, or nil for a non-residue. Either root may be returned.
    /// This operation is variable time and accepts public field elements only.
    internal func squareRoot() -> Self? {
        let candidate = raised(to: Self.squareRootExponent)
        return candidate.squared() == self ? candidate : nil
    }

    private func raised(to exponent: [UInt32]) -> Self {
        var candidate = Self.one
        for word in exponent.reversed() {
            for bit in stride(from: 31, through: 0, by: -1) {
                candidate = candidate.squared()
                if word & (UInt32(1) << bit) != 0 {
                    candidate = candidate.multiplied(by: self)
                }
            }
        }
        return candidate
    }

    private static func isLessThan(_ lhs: [UInt32], _ rhs: [UInt32]) -> Bool {
        for index in stride(from: 7, through: 0, by: -1) {
            if lhs[index] != rhs[index] { return lhs[index] < rhs[index] }
        }
        return false
    }

    // Requires lhs >= rhs. All callers establish this with canonicality or comparison.
    private static func subtract(_ lhs: [UInt32], _ rhs: [UInt32]) -> [UInt32] {
        var result = [UInt32](repeating: 0, count: 8)
        var borrow: UInt64 = 0
        for index in 0..<8 {
            let subtrahend = UInt64(rhs[index]) + borrow
            let value = UInt64(lhs[index])
            if value >= subtrahend {
                result[index] = UInt32(value - subtrahend)
                borrow = 0
            } else {
                result[index] = UInt32(value + radix - subtrahend)
                borrow = 1
            }
        }
        return result
    }

    // Reduces 16 base-B limbs using B^8 = B + 977 (mod p), where B = 2^32.
    private static func reduce(_ wide: [UInt32]) -> [UInt32] {
        var folded = [UInt64](repeating: 0, count: 9)
        for index in 0..<8 {
            folded[index] += UInt64(wide[index]) + 977 * UInt64(wide[index + 8])
            folded[index + 1] += UInt64(wide[index + 8])
        }
        // Before normalization each low word is <= 979 * (B - 1).
        // Including incoming carry, it remains <= 979 * B - 1 (< 2^42).
        // The normalized high word is <= B + 977.
        normalizeLowWords(&folded)

        while folded[8] != 0 {
            let high = folded[8]
            folded[8] = 0
            folded[0] += 977 * high
            folded[1] += high
            // On the first pass high <= B + 977. All words remain below 2^42.
            // The represented integer is < B^8 + (B + 977)^2, so the next
            // high is at most 1. If it is 1, the remaining low value is
            // < (B + 977)^2; adding B + 977 cannot overflow B^8. Thus this
            // loop needs at most two iterations for any 16-limb input.
            normalizeLowWords(&folded)
        }

        let result = folded.prefix(8).map { UInt32($0) }
        // result < B^8 and p > B^8 / 2, so a single subtraction suffices.
        return isLessThan(result, modulus) ? result : subtract(result, modulus)
    }

    private static func normalizeLowWords(_ words: inout [UInt64]) {
        for index in 0..<8 {
            words[index + 1] += words[index] >> 32
            words[index] &= 0xffffffff
        }
    }
}
