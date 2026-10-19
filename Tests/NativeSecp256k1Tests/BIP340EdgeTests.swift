import Foundation
@testable import NativeSecp256k1
import Testing

@Suite("BIP340 encoding, message and mutation edges")
struct BIP340EdgeTests {
    // Public columns of official vector 0 at bitcoin/bips
    // 927b6de9915c9262615a6399de51b200f81e5aa4. No private values are copied.
    private let publicKey = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
    private let signature = "e907831f80848d1069a5371b402410364bdF1c5f8307b0084c55f1ce2dca8215"
        + "25f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
    private let message = Data(repeating: 0, count: 32)

    @Test("Signatures and keys require exact encoded lengths, without implicit sighash stripping")
    func wrongLengths() throws {
        let key = try hex(publicKey)
        let validSignature = try hex(signature)
        #expect(ExperimentalBIP340.verify(signature: validSignature, message: message, publicKey: key))
        for length in Array(0...66) + [128, 1024] where length != 64 {
            #expect(!ExperimentalBIP340.verify(
                signature: Data(repeating: 0, count: length), message: message, publicKey: key
            ))
        }
        for length in Array(0...34) + [64, 1024] where length != 32 {
            #expect(!ExperimentalBIP340.verify(
                signature: validSignature, message: message, publicKey: Data(repeating: 0, count: length)
            ))
        }
        #expect(!ExperimentalBIP340.verify(
            signature: validSignature + Data([0x01]), message: message, publicKey: key
        ))
        #expect(!ExperimentalBIP340.verify(
            signature: validSignature, message: message, publicKey: Data([0x02]) + key
        ))
    }

    @Test("Noncanonical signature components and invalid public keys fail")
    func encodingBoundaries() throws {
        let key = try hex(publicKey)
        let validSignature = try hex(signature)
        let prime = try hex("fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f")
        let order = try hex("fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141")
        #expect(!ExperimentalBIP340.verify(
            signature: prime + validSignature.suffix(32), message: message, publicKey: key
        ))
        #expect(!ExperimentalBIP340.verify(
            signature: validSignature.prefix(32) + order, message: message, publicKey: key
        ))
        for invalidKey in [prime, Data(repeating: 0xff, count: 32), Data(repeating: 0, count: 32)] {
            #expect(!ExperimentalBIP340.verify(
                signature: validSignature, message: message, publicKey: invalidKey
            ))
        }
        #expect(!ExperimentalBIP340.verify(
            signature: Data(repeating: 0, count: 64), message: message, publicKey: key
        ))
    }

    @Test("Signature halves, message content and message length are all authenticated")
    func mutations() throws {
        let key = try hex(publicKey)
        let validSignature = try hex(signature)
        for index in [0, 31, 32, 63] {
            var mutated = validSignature
            mutated[index] ^= 1
            #expect(!ExperimentalBIP340.verify(signature: mutated, message: message, publicKey: key))
        }
        for changedMessage in [Data(), Data([1]), Data(repeating: 0, count: 31),
                               Data(repeating: 0, count: 33), Data(repeating: 1, count: 32)] {
            #expect(!ExperimentalBIP340.verify(
                signature: validSignature, message: changedMessage, publicKey: key
            ))
        }
        let differentValidKey = try hex("79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        #expect(!ExperimentalBIP340.verify(
            signature: validSignature, message: message, publicKey: differentValidKey
        ))
    }

    @Test("Nonzero-index Data slices work for signatures, keys and messages")
    func offsetSlices() throws {
        let key = try hex(publicKey)
        let validSignature = try hex(signature)
        let keySlice = (Data([0xaa, 0xbb]) + key + Data([0xcc])).dropFirst(2).dropLast()
        let signatureSlice = (Data([0xaa]) + validSignature + Data([0xbb])).dropFirst().dropLast()
        let messageSlice = (Data([0xaa, 0xbb, 0xcc]) + message).dropFirst(3)
        #expect(keySlice.startIndex == 2)
        #expect(signatureSlice.startIndex == 1)
        #expect(messageSlice.startIndex == 3)
        #expect(ExperimentalBIP340.verify(
            signature: signatureSlice, message: messageSlice, publicKey: keySlice
        ))
    }

    @Test("Empty messages are supported and are not silently padded to 32 bytes")
    func emptyMessage() throws {
        // Official BIP340 vector 15, same pinned source as vector 0 above.
        let key = try hex("778caa53b4393ac467774d09497a87224bf9fab6f6e68b23086497324d6fd117")
        let signature = try hex(
            "71535db165ecd9fbbc046e5ffaea61186bb6ad436732fccc25291a55895464cf60"
                + "69ce26bf03466228f19a3a62db8a649f2d560fac652827d1af0574e427ab63"
        )
        #expect(ExperimentalBIP340.verify(signature: signature, message: Data(), publicKey: key))
        #expect(!ExperimentalBIP340.verify(signature: signature, message: message, publicKey: key))
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
