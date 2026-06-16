import HaByLo
import Testing

@Suite struct BlockChainTests {
    @Test func hashComparable() {
        let block1_722_094Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000000000012ecc7c92ab495125bf2539607b836830a47a3a5d145304d14a".hex2Hash()
        let block1_722_097Hash: BlockChain.Hash<BlockHeaderHash> =
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78".hex2Hash()
        let block1_722_224Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000001b3e04061a9baec74f84fff9177833b3df5d0ded65dc331782af1c5b".hex2Hash()
        #expect(!(block1_722_094Hash < block1_722_094Hash))
        #expect(block1_722_094Hash < block1_722_097Hash)
        #expect(block1_722_094Hash < block1_722_224Hash)
        #expect(!(block1_722_097Hash < block1_722_094Hash))
        #expect(!(block1_722_097Hash < block1_722_097Hash))
        #expect(block1_722_097Hash < block1_722_224Hash)
        #expect(!(block1_722_224Hash < block1_722_094Hash))
        #expect(!(block1_722_224Hash < block1_722_097Hash))
        #expect(!(block1_722_224Hash < block1_722_224Hash))
    }

    @Test func hashEquatable() {
        let block1_722_094Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000000000012ecc7c92ab495125bf2539607b836830a47a3a5d145304d14a".hex2Hash()
        let block1_722_097Hash: BlockChain.Hash<BlockHeaderHash> =
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78".hex2Hash()
        let block1_722_224Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000001b3e04061a9baec74f84fff9177833b3df5d0ded65dc331782af1c5b".hex2Hash()
        #expect(block1_722_094Hash == block1_722_094Hash)
        #expect(block1_722_094Hash != block1_722_097Hash)
        #expect(block1_722_094Hash != block1_722_224Hash)
        #expect(block1_722_097Hash != block1_722_094Hash)
        #expect(block1_722_097Hash == block1_722_097Hash)
        #expect(block1_722_097Hash != block1_722_224Hash)
        #expect(block1_722_224Hash != block1_722_094Hash)
        #expect(block1_722_224Hash == block1_722_224Hash)
    }

    @Test func hashHashable() {
        let block1_722_094Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000000000012ecc7c92ab495125bf2539607b836830a47a3a5d145304d14a"
        let block1_722_097Hash: BlockChain.Hash<BlockHeaderHash> =
            "00000000004d6370ab8d39f3e221354cb4940b042c700ab88e7ad20d72ca2d78"
        let block1_722_224Hash: BlockChain.Hash<BlockHeaderHash> =
            "000000001b3e04061a9baec74f84fff9177833b3df5d0ded65dc331782af1c5b"
        #expect(
            block1_722_094Hash.hashValue
                == Int(bitPattern: 0x7a3a_5d14_5304_d14a).byteSwapped.hashValue)
        #expect(
            block1_722_097Hash.hashValue
                == Int(bitPattern: 0x8e7a_d20d_72ca_2d78).byteSwapped.hashValue)
        #expect(
            block1_722_224Hash.hashValue
                == Int(bitPattern: 0x65dc_3317_82af_1c5b).byteSwapped.hashValue)
    }

    @Test func expressibleByIntegerArrayLiteral() {
        let zeroHash: BlockChain.Hash<BlockHeaderHash> = .zero
        #expect(zeroHash == 0)

        let bigEndian: BlockChain.Hash<BlockHeaderHash> =
            "0000000000000000000000000000000000000000000000007a3a5d145304d14a"
        #expect(bigEndian == 0x7a3a_5d14_5304_d14a)
    }

    enum TestTag: TaggedHash {
        static let tag: [UInt8] = "testing".utf8.sha256
    }

    @Test func tagged() {
        let message = "message".utf8
        let hash: BlockChain.Hash<TestTag> = .makeHash(from: message)

        #expect(hash == "cc39a7d0713aa5f3942ac1e05e2a1e5241148cb0e5325afac4388bab2df7a25e")
    }
}
