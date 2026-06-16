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

@Suite struct MerkleTests {
    static func leaves(_ n: Int) -> [BlockChain.Hash<TransactionLegacyHash>] {
        (1...n).map {
            BlockChain.Hash<TransactionLegacyHash>.makeHash(from: [
                UInt8($0 & 0xFF), UInt8($0 >> 8),
            ])
        }
    }

    // MARK: proof <-> root round-trip (the review fix) over many tree shapes
    @Test func proofReproducesRootForEveryLeaf() throws {
        for n in 2...17 {
            let leaves = Self.leaves(n)
            let root = try BlockChain.merkleRoot(from: leaves)
            for index in leaves.indices {
                let proof = try BlockChain.merkleProof(from: leaves, index: index)
                #expect(proof.root == root, "n=\(n) index=\(index): proof root mismatch")
                let reconstructed = BlockChain.merkleVerifyProof(
                    leaves[index], neighbour: proof.neighbour, parents: proof.parents)
                #expect(reconstructed == root, "n=\(n) index=\(index): verify produced wrong root")
            }
        }
    }

    @Test func twoLeafProofHasNoParents() throws {
        let leaves = Self.leaves(2)
        let proof = try BlockChain.merkleProof(from: leaves, index: 0)
        #expect(proof.parents.isEmpty)
        #expect(
            BlockChain.merkleVerifyProof(
                leaves[0], neighbour: proof.neighbour, parents: proof.parents) == proof.root)
    }

    // MARK: merkleTree structure
    @Test func merkleTreeHasExpectedLevelCounts() throws {
        // 4 leaves -> levels [2 parents][1 root].
        let tree4 = try BlockChain.merkleTree(from: Self.leaves(4))
        #expect(tree4.map(\.count) == [2, 1])
        // 5 leaves -> [3][2][1] (odd levels duplicate the last node).
        let tree5 = try BlockChain.merkleTree(from: Self.leaves(5))
        #expect(tree5.map(\.count) == [3, 2, 1])
    }

    @Test func merkleRootOfSingleLeafIsThatLeaf() throws {
        let leaf = Self.leaves(1)[0]
        let root = try BlockChain.merkleRoot(from: [leaf])
        #expect(Array(root.littleEndian) == Array(leaf.littleEndian))
    }

    @Test func merkleRootOfEmptyThrows() {
        #expect(throws: BlockChain.Error.self) {
            _ = try BlockChain.merkleRoot(from: [BlockChain.Hash<TransactionLegacyHash>]())
        }
    }

    // MARK: merklePair (pairwise hashing + CVE-2012-2459 duplicate rejection)
    @Test func merklePairBehaviour() throws {
        let a = Self.leaves(2)[0]
        let b = Self.leaves(2)[1]

        let pair = try a.merklePair(b)
        #expect(pair.count == 32)
        // Order matters.
        #expect(try a.merklePair(b) != b.merklePair(a))

        // Explicit identical pair is rejected (malleability guard)...
        #expect(throws: BlockChain.Hash<TransactionLegacyHash>.IdenticalHashPairError.self) {
            _ = try a.merklePair(a)
        }
        // ...but implicit self-duplication via nil (odd-level padding) is allowed.
        let selfPair = try a.merklePair(nil)
        #expect(selfPair.count == 32)
    }
}
