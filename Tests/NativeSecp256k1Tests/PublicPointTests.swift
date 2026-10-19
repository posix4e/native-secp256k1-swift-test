import CryptoKit
import Foundation
@testable import NativeSecp256k1
import Testing

@Suite("Experimental public secp256k1 point arithmetic")
struct PublicPointTests {
    private struct Coordinates: Decodable {
        let x: String
        let y: String
    }

    private struct Addition: Decodable {
        let name: String
        let left: Coordinates?
        let right: Coordinates?
        let result: Coordinates?
    }

    private struct Multiplication: Decodable {
        let name: String
        let point: Coordinates?
        let scalar: String
        let result: Coordinates?
    }

    private struct Inverse: Decodable {
        let value: String
        let inverse: String?
    }

    private struct Vectors: Decodable {
        let additions: [Addition]
        let multiplications: [Multiplication]
        let inverses: [Inverse]
    }

    @Test("Affine Python reference fixture is pinned and complete")
    func fixtureIdentity() throws {
        let data = try fixtureData()
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(digest == "9db046f678ed448af0a8eb16a87d8cd71f356f32873a9458867cac6b92211c09")
        let values = try JSONDecoder().decode(Vectors.self, from: data)
        #expect(values.additions.count == 55)
        #expect(values.multiplications.count == 26)
        #expect(values.inverses.count == 25)
    }

    @Test("Field inverses match Python integer modular inversion, with zero rejected")
    func fieldInverses() throws {
        for value in try vectors().inverses {
            let input = try field(value.value)
            let inverse = input.inverted()
            if let expected = value.inverse {
                let actual = try #require(inverse)
                #expect(actual.bigEndian == (try hex(expected)))
                #expect(input.multiplied(by: actual) == .one)
            } else {
                #expect(inverse == nil)
            }
        }
    }

    @Test("Field subtraction wraps canonically at zero and the modulus")
    func fieldSubtraction() throws {
        let pMinusOne = try field("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e")
        let pMinusTwo = try field("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2d")
        let two = PublicFieldElement.one.adding(.one)
        #expect(PublicFieldElement.zero.subtracting(.one) == pMinusOne)
        #expect(PublicFieldElement.one.subtracting(.one) == .zero)
        #expect(pMinusOne.subtracting(.one) == pMinusTwo)
        #expect(PublicFieldElement.one.subtracting(pMinusOne) == two)
        #expect(PublicFieldElement.zero.subtracting(.zero) == .zero)
    }

    @Test("Point addition matches independent affine integer answers")
    func additionKnownAnswers() throws {
        for vector in try vectors().additions {
            let left = try point(vector.left)
            let right = try point(vector.right)
            try expectPoint(left.adding(right), equals: vector.result, name: vector.name)
            try expectPoint(right.adding(left), equals: vector.result, name: vector.name + " reversed")
        }
    }

    @Test("Public scalar multiplication matches independent affine integer answers")
    func multiplicationKnownAnswers() throws {
        for vector in try vectors().multiplications {
            let input = try point(vector.point)
            let scalar = try #require(PublicScalar(bigEndian: hex(vector.scalar)))
            try expectPoint(input.multiplied(by: scalar), equals: vector.result, name: vector.name)
        }
    }

    @Test("Infinity, equal and opposite points work for different Jacobian representations")
    func groupIdentities() throws {
        let generator = PublicPoint.generator
        let twice = generator.adding(generator)
        let twiceAffine = try #require(twice.affineCoordinates)
        let reconstructed = try #require(PublicPoint(x: twiceAffine.x, y: twiceAffine.y))
        #expect(PublicPoint.infinity.isInfinity)
        #expect(PublicPoint.infinity.affineCoordinates == nil)
        #expect(PublicPoint.infinity.negated().isInfinity)
        #expect(PublicPoint.infinity.adding(.infinity).isInfinity)
        #expect(PublicPoint.infinity.multiplied(by: .one).isInfinity)
        #expect(generator.multiplied(by: .zero).isInfinity)
        #expect(twice.adding(reconstructed.negated()).isInfinity)
        try expectSame(twice.adding(reconstructed), generator.adding(generator).adding(twice))
        try expectSame(twice.adding(.infinity), twice)
        try expectSame(PublicPoint.infinity.adding(twice), twice)
        try expectSame(twice.negated().negated(), twice)
        try expectSame(generator.multiplied(by: .one), generator)
        try expectSame(twice.adding(generator).adding(reconstructed), twice.adding(generator.adding(reconstructed)))
    }

    @Test("Affine admission rejects off-curve coordinates without constructing a point")
    func invalidAffineCoordinates() throws {
        let generator = try #require(PublicPoint.generator.affineCoordinates)
        #expect(PublicPoint(x: .zero, y: .zero) == nil)
        #expect(PublicPoint(x: .zero, y: .one) == nil)
        #expect(PublicPoint(x: generator.x, y: .zero) == nil)
        #expect(PublicPoint(x: generator.x, y: generator.y.adding(.one)) == nil)
        #expect(PublicPoint(x: generator.x, y: generator.y.negated()) != nil)
        // secp256k1 has odd prime order, so no finite y=0 point can be admitted.
        // The private Jacobian initializer is deliberately unavailable to tests.
    }

    private func expectPoint(_ actual: PublicPoint, equals expected: Coordinates?, name: String) throws {
        #expect(actual.isInfinity == (expected == nil), "\(name) infinity")
        guard let expected else {
            #expect(actual.affineCoordinates == nil, "\(name)")
            return
        }
        let coordinates = try #require(actual.affineCoordinates, "\(name)")
        #expect(coordinates.x.bigEndian == (try hex(expected.x)), "\(name) x")
        #expect(coordinates.y.bigEndian == (try hex(expected.y)), "\(name) y")
        #expect(PublicPoint(x: coordinates.x, y: coordinates.y) != nil, "\(name) curve equation")
    }

    private func expectSame(_ left: PublicPoint, _ right: PublicPoint) throws {
        let lhs = try #require(left.affineCoordinates)
        let rhs = try #require(right.affineCoordinates)
        #expect(lhs.x == rhs.x)
        #expect(lhs.y == rhs.y)
    }

    private func point(_ coordinates: Coordinates?) throws -> PublicPoint {
        guard let coordinates else { return .infinity }
        return try #require(PublicPoint(x: field(coordinates.x), y: field(coordinates.y)))
    }

    private func field(_ value: String) throws -> PublicFieldElement {
        try #require(PublicFieldElement(bigEndian: hex(value)))
    }

    private func fixtureData() throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: "public-point-vectors", withExtension: "json", subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    private func vectors() throws -> Vectors {
        try JSONDecoder().decode(Vectors.self, from: fixtureData())
    }

    private func hex(_ value: String) throws -> Data {
        let characters = Array(value.utf8)
        guard characters.count == 64 else { throw FixtureError.invalidHex }
        return try Data(stride(from: 0, to: characters.count, by: 2).map { offset in
            let pair = String(decoding: characters[offset..<offset + 2], as: UTF8.self)
            return try #require(UInt8(pair, radix: 16))
        })
    }

    private enum FixtureError: Error { case invalidHex }
}
