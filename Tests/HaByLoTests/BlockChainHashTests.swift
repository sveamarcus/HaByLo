//===----------------------------------------------------------------------===//
//
// This source file is part of the fltrECC open source project
//
// Copyright (c) 2022-2026 fltrWallet AG and the fltrECC project authors
// Licensed under Apache License v2.0
//
// See LICENSE.md for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import HaByLo
import Testing

@Suite struct BlockChainHashTests {
    static let bytes32: [UInt8] = (0..<32).map { UInt8($0) }

    // MARK: endianness of big/little construction
    @Test func bigLittleEndianness() {
        let little = BlockChain.Hash<BlockHeaderHash>.little(Self.bytes32)
        #expect(Array(little.littleEndian) == Self.bytes32)
        #expect(Array(little.bigEndian) == Self.bytes32.reversed())
        #expect(little.count == 32)

        let big = BlockChain.Hash<BlockHeaderHash>.big(Self.bytes32)
        #expect(Array(big.littleEndian) == Self.bytes32.reversed())
        #expect(Array(big.bigEndian) == Self.bytes32)

        // big(x) and little(reversed(x)) describe the same value.
        #expect(
            BlockChain.Hash<BlockHeaderHash>.big(Self.bytes32) == .little(Self.bytes32.reversed()))
    }

    // MARK: literals
    @Test func zeroLiteral() {
        let zero: BlockChain.Hash<BlockHeaderHash> = .zero
        #expect(zero == 0)
        #expect(zero.count == 32)
        #expect(zero.description == String(repeating: "0", count: 64))
    }

    @Test func integerLiteralIsLittleEndian() {
        // 0x...01 in little-endian places 0x01 first; description (big-endian) ends in 01.
        let one: BlockChain.Hash<BlockHeaderHash> = 1
        #expect(Array(one.littleEndian).first == 1)
        #expect(one.description.hasSuffix("01"))
        #expect(one.description.hasPrefix("000000"))
    }

    @Test func stringLiteralRoundTripsWithDescription() {
        let hex = "00000000000000000007878ec04bb2b2e12317804810f4c26033585b3f81ffaa"
        let hash: BlockChain.Hash<BlockHeaderHash> = .init(stringLiteral: hex)
        #expect(hash.description == hex)
    }

    // MARK: Equatable / Hashable / Comparable contracts
    @Test func equalHashesHashEqually() {
        let a: BlockChain.Hash<BlockHeaderHash> =
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78"
        let b: BlockChain.Hash<BlockHeaderHash> =
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78"
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        var set = Set<BlockChain.Hash<BlockHeaderHash>>()
        set.insert(a)
        #expect(set.contains(b))
    }

    @Test func comparableIsAStrictTotalOrder() {
        let hashes: [BlockChain.Hash<BlockHeaderHash>] = [
            "000000000000012ecc7c92ab495125bf2539607b836830a47a3a5d145304d14a",
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78",
            "000000001b3e04061a9baec74f84fff9177833b3df5d0ded65dc331782af1c5b",
        ]
        for a in hashes {
            #expect(!(a < a))  // irreflexive
            for b in hashes where a != b {
                #expect((a < b) != (b < a))  // antisymmetric / total
            }
        }
        let sorted = hashes.sorted()
        #expect(sorted[0] < sorted[1])
        #expect(sorted[1] < sorted[2])
    }

    // MARK: Codable round-trip
    @Test func codableRoundTrip() throws {
        let original: BlockChain.Hash<BlockHeaderHash> =
            "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([BlockChain.Hash<BlockHeaderHash>].self, from: data)
        #expect(decoded == [original])
        // Encodes as the big-endian hex string.
        #expect(String(decoding: data, as: UTF8.self).contains(original.description))
    }

    @Test func decodeRejectsNon64CharHex() {
        let badJSON = Data(#"["abcd"]"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([BlockChain.Hash<BlockHeaderHash>].self, from: badJSON)
        }
    }

    // MARK: phantom-type conversions preserve bytes
    @Test func typedConversionsPreserveBytes() {
        let tx = BlockChain.Hash<TransactionLegacyHash>.little(Self.bytes32)
        #expect(Array(tx.asWtxId.littleEndian) == Self.bytes32)
        #expect(Array(tx.asMerkleHash.littleEndian) == Self.bytes32)
    }

    @Test func compactFilterAppendProducesHeaderHash() {
        let filterHash = BlockChain.Hash<CompactFilterHash>.little(Self.bytes32)
        let previousHeader = BlockChain.Hash<CompactFilterHeaderHash>.little(
            Self.bytes32.reversed())
        let header: BlockChain.Hash<CompactFilterHeaderHash> = filterHash.appendHash(previousHeader)
        #expect(header.count == 32)
    }
}
