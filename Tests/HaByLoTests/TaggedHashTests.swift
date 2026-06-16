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

import HaByLo
import Testing

enum BIP340TestTag: TaggedHash {
    static let tag: [UInt8] = "testing".utf8.sha256
}

@Suite struct TaggedHashTests {
    @Test func knownVector() {
        let message = "message".utf8
        let hash: BlockChain.Hash<BIP340TestTag> = .makeHash(from: message)
        #expect(hash == "cc39a7d0713aa5f3942ac1e05e2a1e5241148cb0e5325afac4388bab2df7a25e")
    }

    @Test func equalsSha256OfTagTagMessage() {
        let message: [UInt8] = "message".ascii
        let hash: BlockChain.Hash<BIP340TestTag> = .makeHash(from: message)
        let expected = (BIP340TestTag.tag + BIP340TestTag.tag + message).sha256
        #expect(Array(hash.littleEndian) == expected)
    }

    @Test func collectionAndSequenceOverloadsAgree() {
        let message: [UInt8] = [1, 2, 3, 4, 5]
        let fromCollection: BlockChain.Hash<BIP340TestTag> = .makeHash(from: message)
        let fromSequence: BlockChain.Hash<BIP340TestTag> = .makeHash(from: AnySequence(message))
        #expect(fromCollection == fromSequence)
    }

    @Test func emptyMessage() {
        let empty: [UInt8] = []
        let hash: BlockChain.Hash<BIP340TestTag> = .makeHash(from: empty)
        let expected = (BIP340TestTag.tag + BIP340TestTag.tag + empty).sha256
        #expect(Array(hash.littleEndian) == expected)
    }
}
