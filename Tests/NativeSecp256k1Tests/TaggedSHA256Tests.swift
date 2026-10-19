import Foundation
import NativeSecp256k1
import Testing

@Suite("Independent tagged SHA-256 known answers")
struct TaggedSHA256Tests {
    private struct TapTweakVector: Decodable {
        let sourceIndex: Int
        let internalPubkey: String
        let merkleRoot: String?
        let expectedTweak: String
    }

    private struct OracleVector: Decodable {
        let name: String
        let tag: String
        let messageHex: String
        let expectedHash: String
    }

    @Test("all seven official BIP341 wallet TapTweak hashes")
    func tapTweakKnownAnswers() throws {
        let vectors: [TapTweakVector] = try load("bip341-taptweak")
        #expect(vectors.map(\.sourceIndex) == Array(0...6))
        #expect(vectors.filter { $0.merkleRoot == nil }.count == 1)
        for vector in vectors {
            let key = try hex(vector.internalPubkey)
            let root = try hex(vector.merkleRoot ?? "")
            #expect(key.count == 32)
            #expect(root.isEmpty || root.count == 32)
            let actual = TaggedSHA256.hash(tag: "TapTweak", message: key + root)
            #expect(actual == (try hex(vector.expectedTweak)), "BIP341 case \(vector.sourceIndex)")
        }
    }

    @Test("pinned libsecp256k1 answers for empty, long and UTF-8/NUL tags")
    func libsecpKnownAnswers() throws {
        let vectors: [OracleVector] = try load("libsecp-tagged-hash")
        #expect(vectors.map(\.name) == ["empty", "long-tag", "utf8-and-nul"])
        for vector in vectors {
            let message = try hex(vector.messageHex)
            let expected = try hex(vector.expectedHash)
            #expect(TaggedSHA256.hash(tag: vector.tag, message: message) == expected, "\(vector.name)")

            // A Data slice need not start at index zero. Keep the oracle bytes
            // unchanged while testing the public API with an offset slice.
            let padded = Data([0xA5]) + message
            let slice = padded.dropFirst()
            #expect(TaggedSHA256.hash(tag: vector.tag, message: slice) == expected, "\(vector.name) slice")
        }
    }

    private func load<T: Decodable>(_ name: String) throws -> T {
        let url = try #require(Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func hex(_ string: String) throws -> Data {
        let characters = Array(string.utf8)
        #expect(characters.count.isMultiple(of: 2))
        guard characters.count.isMultiple(of: 2) else { throw FixtureError.invalidHex }
        var result = Data()
        for offset in stride(from: 0, to: characters.count, by: 2) {
            let pair = String(decoding: characters[offset..<offset + 2], as: UTF8.self)
            guard let byte = UInt8(pair, radix: 16) else { throw FixtureError.invalidHex }
            result.append(byte)
        }
        return result
    }

    private enum FixtureError: Error { case invalidHex }
}
