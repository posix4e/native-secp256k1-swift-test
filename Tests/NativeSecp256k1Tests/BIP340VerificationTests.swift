import CryptoKit
import Foundation
import NativeSecp256k1
import Testing

@Suite("Independent public BIP340 signature verification")
struct BIP340VerificationTests {
    private struct Vector: Decodable {
        let name: String
        let publicKey: String
        let signature: String
        let message: String
        let expected: Bool
        let comment: String
    }

    @Test("All 19 official full-signature decisions, including arbitrary-length messages")
    func officialKnownAnswers() throws {
        let vectors = try load("bip340-verification-official")
        #expect(vectors.map(\.name) == (0...18).map { "bip340-\($0)" })
        #expect(vectors.filter(\.expected).count == 9)
        #expect(try vectors.suffix(4).map { try hex($0.message).count } == [0, 1, 17, 100])
        for vector in vectors {
            #expect(try verifies(vector) == vector.expected, "\(vector.name): \(vector.comment)")
        }
    }

    @Test("Pinned libsecp256k1 and BIP340 Python agree on 184 generated and hostile cases")
    func differentialKnownAnswers() throws {
        let vectors = try load("bip340-verification-differential")
        #expect(vectors.count == 184)
        #expect(vectors.filter(\.expected).count == 32)
        #expect(vectors.filter { $0.name.hasPrefix("constructed-infinity-") }.count == 2)
        #expect(vectors.contains { $0.name == "constructed-odd-r" && !$0.expected })
        #expect(try vectors.map { try hex($0.message).count }.max() == 4096)
        for vector in vectors {
            #expect(try verifies(vector) == vector.expected, "\(vector.name): \(vector.comment)")
        }
    }

    @Test("Wrong public-key and signature lengths fail before arithmetic")
    func malformedLengths() throws {
        let vector = try #require(try load("bip340-verification-official").first)
        let key = try hex(vector.publicKey)
        let signature = try hex(vector.signature)
        let message = try hex(vector.message)
        for length in Array(0...96) + [255, 1024] where length != 32 {
            #expect(!ExperimentalBIP340.verify(signature: signature, message: message,
                                               publicKey: Data(repeating: 0, count: length)),
                    "public key length \(length)")
        }
        for length in Array(0...96) + [255, 1024] where length != 64 {
            #expect(!ExperimentalBIP340.verify(signature: Data(repeating: 0, count: length),
                                               message: message, publicKey: key),
                    "signature length \(length)")
        }
    }

    @Test("Nonzero-offset Data inputs preserve public key, signature and exact message bytes")
    func offsetSlices() throws {
        let vectors = try load("bip340-verification-official")
        for index in [0, 6, 9, 12, 13, 15, 16, 17, 18] {
            let vector = vectors[index]
            let key = (Data([0xa1, 0xa2]) + (try hex(vector.publicKey)) + Data([0xa3])).dropFirst(2).dropLast()
            let signature = (Data([0xb1]) + (try hex(vector.signature)) + Data([0xb2])).dropFirst().dropLast()
            let message = (Data([0xc1, 0xc2, 0xc3]) + (try hex(vector.message)) + Data([0xc4])).dropFirst(3).dropLast()
            #expect(key.startIndex == 2)
            #expect(signature.startIndex == 1)
            #expect(message.startIndex == 3)
            #expect(ExperimentalBIP340.verify(signature: signature, message: message, publicKey: key)
                    == vector.expected, "\(vector.name) offset inputs")
        }
    }

    private func verifies(_ vector: Vector) throws -> Bool {
        ExperimentalBIP340.verify(signature: try hex(vector.signature),
                                  message: try hex(vector.message), publicKey: try hex(vector.publicKey))
    }

    private func load(_ name: String) throws -> [Vector] {
        let expectedDigest: String
        switch name {
        case "bip340-verification-official":
            expectedDigest = "c005451e8b883b2ca7a59ea2a7485027c7cb5f3312ee4a9a3c0c45a986126b01"
        case "bip340-verification-differential":
            expectedDigest = "6463d122bfa44e4e850ff371d724b10b157f0f129230312b8f5be0e2979433d8"
        default:
            throw FixtureError.unexpectedFixture
        }
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try #require(digest == expectedDigest, "pinned independent fixture changed")
        return try JSONDecoder().decode([Vector].self, from: data)
    }

    private func hex(_ string: String) throws -> Data {
        let characters = Array(string.utf8)
        guard characters.count.isMultiple(of: 2) else { throw FixtureError.invalidHex }
        var bytes = Data()
        for offset in stride(from: 0, to: characters.count, by: 2) {
            let pair = String(decoding: characters[offset..<offset + 2], as: UTF8.self)
            guard let value = UInt8(pair, radix: 16) else { throw FixtureError.invalidHex }
            bytes.append(value)
        }
        return bytes
    }

    private enum FixtureError: Error { case invalidHex, unexpectedFixture }
}
