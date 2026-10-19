import Foundation

/// Experimental secp256k1 group operations for PUBLIC points and PUBLIC scalars.
/// Branches and allocations depend on their inputs. This type must never process
/// private keys, signing nonces, or ECDH secret scalars.
internal struct PublicPoint: Sendable {
    // Jacobian representation: affine x = X/Z² and y = Y/Z³. Z = 0 is infinity.
    private let x: PublicFieldElement
    private let y: PublicFieldElement
    private let z: PublicFieldElement

    internal static let infinity = PublicPoint(jacobianX: .zero, y: .one, z: .zero)

    // SEC 2 v2 section 2.4.1, the secp256k1 base point. These fixed constants are
    // public; the failable affine initializer also validates their curve equation.
    internal static let generator = PublicPoint(
        x: PublicFieldElement(bigEndian: Data([
            0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac,
            0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b, 0x07,
            0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9,
            0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98,
        ]))!,
        y: PublicFieldElement(bigEndian: Data([
            0x48, 0x3a, 0xda, 0x77, 0x26, 0xa3, 0xc4, 0x65,
            0x5d, 0xa4, 0xfb, 0xfc, 0x0e, 0x11, 0x08, 0xa8,
            0xfd, 0x17, 0xb4, 0x48, 0xa6, 0x85, 0x54, 0x19,
            0x9c, 0x47, 0xd0, 0x8f, 0xfb, 0x10, 0xd4, 0xb8,
        ]))!
    )!

    /// Accepts a finite point only if it satisfies secp256k1's curve equation.
    internal init?(x: PublicFieldElement, y: PublicFieldElement) {
        guard y.squared() == x.squared().multiplied(by: x).adding(.seven) else { return nil }
        self.x = x
        self.y = y
        self.z = .one
    }

    // Only the identity and formulas applied to validated points call this.
    private init(jacobianX x: PublicFieldElement, y: PublicFieldElement, z: PublicFieldElement) {
        self.x = x
        self.y = y
        self.z = z
    }

    internal var isInfinity: Bool { z == .zero }

    internal var affineCoordinates: (x: PublicFieldElement, y: PublicFieldElement)? {
        guard let inverse = z.inverted() else { return nil }
        let inverseSquared = inverse.squared()
        return (x.multiplied(by: inverseSquared), y.multiplied(by: inverseSquared.multiplied(by: inverse)))
    }

    internal func negated() -> Self {
        guard !isInfinity else { return .infinity }
        return Self(jacobianX: x, y: y.negated(), z: z)
    }

    internal func adding(_ other: Self) -> Self {
        if isInfinity { return other }
        if other.isInfinity { return self }
        let z1Squared = z.squared()
        let z2Squared = other.z.squared()
        let u1 = x.multiplied(by: z2Squared)
        let u2 = other.x.multiplied(by: z1Squared)
        let s1 = y.multiplied(by: other.z.multiplied(by: z2Squared))
        let s2 = other.y.multiplied(by: z.multiplied(by: z1Squared))
        if u1 == u2 {
            return s1 == s2 ? doubled() : .infinity
        }
        // EFD add-1998-cmo-2, with equal and opposite points handled above.
        // https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian.html#addition-add-1998-cmo-2
        let h = u2.subtracting(u1)
        let hSquared = h.squared()
        let hCubed = h.multiplied(by: hSquared)
        let r = s2.subtracting(s1)
        let v = u1.multiplied(by: hSquared)
        let resultX = r.squared().subtracting(hCubed).subtracting(v.adding(v))
        let resultY = r.multiplied(by: v.subtracting(resultX)).subtracting(s1.multiplied(by: hCubed))
        let resultZ = z.multiplied(by: other.z).multiplied(by: h)
        return Self(jacobianX: resultX, y: resultY, z: resultZ)
    }

    /// Variable-time double-and-add. The scalar MUST be public verification data.
    internal func multiplied(by scalar: PublicScalar) -> Self {
        var result = Self.infinity
        for index in stride(from: 255, through: 0, by: -1) {
            result = result.doubled()
            if scalar.bit(at: index) { result = result.adding(self) }
        }
        return result
    }

    private func doubled() -> Self {
        guard !isInfinity else { return .infinity }
        // EFD dbl-1998-cmo-2 with a = 0. A finite y = 0 point would produce Z = 0
        // here, hence infinity; secp256k1's prime odd-order group has no such point.
        // https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian.html#doubling-dbl-1998-cmo-2
        let xx = x.squared()
        let yy = y.squared()
        let xYY = x.multiplied(by: yy)
        let twiceXYY = xYY.adding(xYY)
        let s = twiceXYY.adding(twiceXYY)
        let m = xx.adding(xx).adding(xx)
        let resultX = m.squared().subtracting(s.adding(s))
        let yyyy = yy.squared()
        let twiceYYYY = yyyy.adding(yyyy)
        let fourYYYY = twiceYYYY.adding(twiceYYYY)
        let eightYYYY = fourYYYY.adding(fourYYYY)
        let resultY = m.multiplied(by: s.subtracting(resultX)).subtracting(eightYYYY)
        let yz = y.multiplied(by: z)
        return Self(jacobianX: resultX, y: resultY, z: yz.adding(yz))
    }
}
