import Foundation
@testable import NativeSecp256k1
import Testing

@Suite("Public secp256k1 scalar encodings")
struct PublicScalarTests {
    private let order = "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141"
    private let prime = "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f"

    @Test("Canonical scalars accept zero through n-1 and reject n through maximum")
    func canonicalBoundaries() throws {
        for value in [
            String(repeating: "0", count: 64),
            String(repeating: "0", count: 63) + "1",
            "8000000000000000000000000000000000000000000000000000000000000000",
            "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140",
        ] {
            let bytes = try hex(value)
            let scalar = try #require(PublicScalar(bigEndian: bytes))
            #expect(scalar.bigEndian == bytes)
        }
        for value in [
            order,
            "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142",
            prime,
            String(repeating: "f", count: 64),
        ] {
            #expect(PublicScalar(bigEndian: try hex(value)) == nil)
        }
        #expect(PublicScalar(bigEndian: Data(repeating: 0, count: 32)) == .zero)
        #expect(PublicScalar(bigEndian: try hex(String(repeating: "0", count: 63) + "1")) == .one)
    }

    @Test("256-bit modular reduction agrees with independent integer boundary answers")
    func reductionBoundaries() throws {
        // Expected values were computed with Python integers: int(input, 16) % n.
        let cases = [
            (String(repeating: "0", count: 64), String(repeating: "0", count: 64)),
            ("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140",
             "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140"),
            (order, String(repeating: "0", count: 64)),
            ("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142",
             String(repeating: "0", count: 63) + "1"),
            ("8000000000000000000000000000000000000000000000000000000000000000",
             "8000000000000000000000000000000000000000000000000000000000000000"),
            ("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2e",
             "000000000000000000000000000000014551231950b75fc4402da1722fc9baed"),
            (prime, "000000000000000000000000000000014551231950b75fc4402da1722fc9baee"),
            (String(repeating: "f", count: 64),
             "000000000000000000000000000000014551231950b75fc4402da1732fc9bebe"),
        ]
        for (input, expected) in cases {
            let reduced = try #require(PublicScalar(reducingBigEndian: try hex(input)))
            #expect(reduced.bigEndian == (try hex(expected)), "input \(input)")
            #expect(PublicScalar(bigEndian: reduced.bigEndian) == reduced)
        }
    }

    @Test("The field prime and group order are different encoding boundaries")
    func fieldIsNotScalar() throws {
        let orderBytes = try hex(order)
        #expect(PublicFieldElement(bigEndian: orderBytes) != nil)
        #expect(PublicScalar(bigEndian: orderBytes) == nil)
        let primeBytes = try hex(prime)
        #expect(PublicFieldElement(bigEndian: primeBytes) == nil)
        #expect(PublicScalar(bigEndian: primeBytes) == nil)
        #expect(PublicScalar(reducingBigEndian: orderBytes) == .zero)
        #expect(PublicScalar(reducingBigEndian: primeBytes) != .zero)
    }

    @Test("Neither parser silently pads or truncates wrong-length input")
    func wrongLengths() {
        for length in Array(0...65) + [128, 1024] where length != 32 {
            let input = Data(repeating: 0xff, count: length)
            #expect(PublicScalar(bigEndian: input) == nil)
            #expect(PublicScalar(reducingBigEndian: input) == nil)
        }
    }

    @Test("Bit access crosses byte and word boundaries with little-endian bit numbering")
    func bitPositions() throws {
        let scalar = try #require(PublicScalar(bigEndian: try hex(
            "c000000000000000000000000000000180000000000000018000000180000183"
        )))
        #expect((0..<256).filter { scalar.bit(at: $0) } == [0, 1, 7, 8, 31, 32, 63, 64, 127, 128, 254, 255])
        #expect((0..<256).filter { PublicScalar.one.bit(at: $0) } == [0])
        #expect((0..<256).allSatisfy { !PublicScalar.zero.bit(at: $0) })
    }

    @Test("Offset slices retain value semantics in strict and reducing parsers")
    func offsetSlices() throws {
        let maximum = Data(repeating: 0xff, count: 32)
        var storage = Data([0xaa, 0xbb]) + maximum + Data([0xcc])
        let slice = storage.dropFirst(2).dropLast()
        #expect(slice.startIndex == 2)
        let reduced = try #require(PublicScalar(reducingBigEndian: slice))
        storage.resetBytes(in: storage.startIndex..<storage.endIndex)
        #expect(reduced.bigEndian == (try hex(
            "000000000000000000000000000000014551231950b75fc4402da1732fc9bebe"
        )))
        let encodedOne = Data([0xaa]) + PublicScalar.one.bigEndian
        #expect(PublicScalar(bigEndian: encodedOne.dropFirst()) == .one)
    }

    private func hex(_ text: String) throws -> Data {
        let characters = Array(text.utf8)
        guard characters.count.isMultiple(of: 2) else { throw InvalidHex.input }
        return Data(try stride(from: 0, to: characters.count, by: 2).map { index in
            let pair = String(decoding: characters[index..<index + 2], as: UTF8.self)
            return try #require(UInt8(pair, radix: 16))
        })
    }

    private enum InvalidHex: Error { case input }
}
