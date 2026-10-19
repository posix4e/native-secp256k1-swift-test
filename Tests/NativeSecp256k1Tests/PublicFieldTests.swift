import Foundation
@testable import NativeSecp256k1
import Testing

@Suite("Public secp256k1 field and x-only validation")
struct PublicFieldTests {
    private struct ArithmeticVector: Decodable {
        let a: String
        let b: String
        let sum: String
        let product: String
        let negation: String
    }
    private struct RootVector: Decodable {
        let value: String
        let evenRoot: String?
    }
    private struct KeyVector: Decodable {
        let name: String
        let x: String
        let evenY: String?
    }

    @Test("Python big-integer arithmetic answers across limb and modulus boundaries")
    func arithmeticKnownAnswers() throws {
        let vectors: [ArithmeticVector] = try load("field-arithmetic")
        #expect(vectors.count == 2624)
        for (index, vector) in vectors.enumerated() {
            let a = try #require(PublicFieldElement(bigEndian: hex(vector.a)))
            let b = try #require(PublicFieldElement(bigEndian: hex(vector.b)))
            #expect(a.bigEndian == (try hex(vector.a)), "round trip \(index)")
            #expect(a.adding(b).bigEndian == (try hex(vector.sum)), "addition \(index)")
            #expect(a.multiplied(by: b).bigEndian == (try hex(vector.product)), "multiplication \(index)")
            #expect(a.negated().bigEndian == (try hex(vector.negation)), "negation \(index)")
        }
    }

    @Test("square roots, zero and nonresidues against Python modular exponentiation")
    func rootKnownAnswers() throws {
        let vectors: [RootVector] = try load("field-roots")
        #expect(vectors.count == 168)
        #expect(vectors.contains { $0.evenRoot == nil })
        for vector in vectors {
            let a = try #require(PublicFieldElement(bigEndian: hex(vector.value)))
            let root = a.squareRoot()
            if let expected = vector.evenRoot {
                let actual = try #require(root)
                let even = actual.isOdd ? actual.negated() : actual
                #expect(even.bigEndian == (try hex(expected)), "root of \(vector.value)")
            } else {
                #expect(root == nil, "nonresidue \(vector.value)")
            }
        }
    }

    @Test("all BIP340 public-key columns and synthetic inputs checked by two oracles")
    func xOnlyKnownAnswers() throws {
        let vectors: [KeyVector] = try load("xonly-validation")
        #expect(vectors.count == 318)
        #expect(vectors.filter { $0.name.hasPrefix("bip340-key-") }.count == 19)
        for vector in vectors {
            let bytes = try hex(vector.x)
            let actual = ExperimentalXOnlyPublicKey(rawRepresentation: bytes)
            if let y = vector.evenY {
                let point = try #require(actual, "\(vector.name)")
                #expect(point.rawRepresentation == bytes, "\(vector.name) x")
                #expect(point.evenYRepresentation == (try hex(y)), "\(vector.name) y")
            } else {
                #expect(actual == nil, "\(vector.name)")
            }
        }
    }

    @Test("wrong lengths and noncanonical encodings fail without reduction")
    func malformedInputs() throws {
        for length in Array(0...64) + [255, 1024] where length != 32 {
            let input = Data(repeating: 0, count: length)
            #expect(PublicFieldElement(bigEndian: input) == nil)
            #expect(ExperimentalXOnlyPublicKey(rawRepresentation: input) == nil)
        }
        for value in [
            "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f",
            "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc30",
            "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        ] {
            let input = try hex(value)
            #expect(PublicFieldElement(bigEndian: input) == nil)
            #expect(ExperimentalXOnlyPublicKey(rawRepresentation: input) == nil)
        }
    }

    @Test("offset Data slices and retained immutable values preserve bytes")
    func offsetSlices() throws {
        let gx = try hex("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        let gy = try hex("483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8")
        var storage = Data([0xaa, 0xbb]) + gx + Data([0xcc])
        let slice = storage.dropFirst(2).dropLast()
        #expect(slice.startIndex == 2)
        let point = try #require(ExperimentalXOnlyPublicKey(rawRepresentation: slice))
        let field = try #require(PublicFieldElement(bigEndian: slice))
        storage.resetBytes(in: storage.startIndex..<storage.endIndex)
        #expect(point.rawRepresentation == gx)
        #expect(point.evenYRepresentation == gy)
        #expect(field.bigEndian == gx)
    }

    private func load<T: Decodable>(_ name: String) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func hex(_ string: String) throws -> Data {
        let characters = Array(string.utf8)
        guard characters.count.isMultiple(of: 2) else { throw FixtureError.invalidHex }
        var bytes = Data()
        for offset in stride(from: 0, to: characters.count, by: 2) {
            let pair = String(decoding: characters[offset..<offset+2], as: UTF8.self)
            guard let value = UInt8(pair, radix: 16) else { throw FixtureError.invalidHex }
            bytes.append(value)
        }
        return bytes
    }

    private enum FixtureError: Error { case invalidHex }
}
