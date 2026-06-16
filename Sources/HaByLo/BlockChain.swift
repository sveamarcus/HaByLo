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

public enum BlockChain {}

// MARK: Hash
public extension BlockChain {
    struct Hash<HashType> {
        // 00:s last, also what's produced from double hash
        public let littleEndian: AnyBidirectionalCollection<UInt8>

        // 00:s first
        @inlinable
        public var bigEndian: ReversedCollection<AnyBidirectionalCollection<UInt8>> {
            self.littleEndian.reversed()
        }

        @inlinable
        public var count: Int {
            self.littleEndian.count
        }

        @inlinable
        public static var zero: Hash<HashType> { 0 }
    }
}

// `BlockChain.Hash` is an immutable value: its only stored property is read-only
extension BlockChain.Hash: @unchecked Sendable {}

public protocol MerkleSourceHash {}

public enum BlockHeaderHash: Sendable {}
public enum CompactFilterHash: Sendable {}
public enum CompactFilterHeaderHash: Sendable {}
public enum MerkleHash: MerkleSourceHash, Sendable {}
public enum SignatureHash: Sendable {}
public enum TransactionLegacyHash: MerkleSourceHash, Sendable {}
public enum TransactionWitnessHash: MerkleSourceHash, Sendable {}

// MARK: Hash / Initializer
public extension BlockChain.Hash {
    enum Endian<C: BidirectionalCollection> where C.Element == UInt8 {
        case big(C)
        case little(C)
    }

    @usableFromInline
    internal init<C: BidirectionalCollection>(_ hash: Endian<C>) where C.Element == UInt8 {
        switch hash {
        case .big(let c):
            self.littleEndian = .init(Array(c.reversed()))
        case .little(let c):
            self.littleEndian = .init(Array(c))
        }
        precondition(self.littleEndian.count == 32, "BlockChain.Hash must be exactly 32 bytes")
    }

    @inlinable
    static func big<C: BidirectionalCollection>(_ hash: C) -> Self where C.Element == UInt8 {
        assert(hash.count == 32)
        return self.init(.big(hash))
    }

    @inlinable
    static func little<C: BidirectionalCollection>(_ hash: C) -> Self where C.Element == UInt8 {
        assert(hash.count == 32)
        return self.init(.little(hash))
    }
}

extension BlockChain.Hash: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: StringLiteralType) {
        self = value.hex2Hash()
    }
}

extension BlockChain.Hash: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: UInt8...) {
        precondition(elements.count == 32)
        self.init(.little(elements))
    }
}

extension BlockChain.Hash: ExpressibleByIntegerLiteral {
    @inlinable
    public init(integerLiteral value: UInt64) {
        self.init(
            .little(
                value.littleEndianBytes + Array(repeating: 0, count: 24)
            ))
    }
}

// MARK: Hash / Hashers
public extension BlockChain.Hash {
    @inlinable
    static func makeHash<Stream: Sequence>(from stream: Stream) -> BlockChain.Hash<HashType>
    where Stream.Element == UInt8 {
        Self(.little(stream.hash256))
    }

    @inlinable
    func appendHash<C: BidirectionalCollection>(_ suffix: Endian<C>) -> BlockChain.Hash<HashType>
    where C.Element == UInt8 {
        var parts: [AnyBidirectionalCollection<UInt8>] = [.init(self.littleEndian)]
        switch suffix {
        case .big(let next):
            parts.append(.init(next.reversed()))
        case .little(let next):
            parts.append(.init(next))
        }

        return .makeHash(from: parts.joined())
    }

    @inlinable
    func appendHash<T>(_ suffix: BlockChain.Hash<HashType>, as: T.Type = T.self)
        -> BlockChain.Hash<T>
    {
        .makeHash(
            from: [self.littleEndian, suffix.littleEndian].joined()
        )
    }
}

extension BlockChain.Hash where HashType == BlockHeaderHash {}
extension BlockChain.Hash where HashType == CompactFilterHash {
    @inlinable
    public func appendHash(_ suffix: BlockChain.Hash<CompactFilterHeaderHash>)
        -> BlockChain.Hash<CompactFilterHeaderHash>
    {
        let headerHash: BlockChain.Hash<CompactFilterHeaderHash> = .init(.little(self.littleEndian))
        return headerHash.appendHash(suffix)
    }
}
extension BlockChain.Hash where HashType == CompactFilterHeaderHash {}
extension BlockChain.Hash where HashType == MerkleHash {}
extension BlockChain.Hash where HashType == SignatureHash {}
extension BlockChain.Hash where HashType == TransactionLegacyHash {
    @inlinable
    public var asWtxId: BlockChain.Hash<TransactionWitnessHash> {
        .init(.little(self.littleEndian))
    }
}
extension BlockChain.Hash where HashType == TransactionWitnessHash {}

extension BlockChain.Hash where HashType: MerkleSourceHash {
    public struct IdenticalHashPairError: Swift.Error, Sendable {
        @inlinable
        public init() {}
    }

    @inlinable
    public func merklePair(_ rhs: BlockChain.Hash<HashType>?) throws -> BlockChain.Hash<MerkleHash>
    {
        assert(self.count == 32 && rhs?.count ?? 32 == 32)

        guard self != rhs else {
            throw IdenticalHashPairError()
        }

        return self.appendHash(rhs ?? self)
    }

    @inlinable
    public var asMerkleHash: BlockChain.Hash<MerkleHash> {
        .init(.little(self.littleEndian))
    }
}

// MARK: Hash / Equatable, Hashable, Comparable
extension BlockChain.Hash: Equatable {
    @inlinable
    public static func == (lhs: BlockChain.Hash<HashType>, rhs: BlockChain.Hash<HashType>) -> Bool {
        guard lhs.littleEndian.count == rhs.littleEndian.count else { return false }
        for (lhs, rhs) in zip(lhs.littleEndian, rhs.littleEndian) {
            guard lhs == rhs else {
                return false
            }
        }
        return true
    }
}

extension BlockChain.Hash: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        let prefix = self.littleEndian.prefix(MemoryLayout<Int>.size)
        var parseInt: Int = 0

        for byte in prefix {
            parseInt = parseInt &<< 8
            parseInt |= Int(byte)
        }

        hasher.combine(parseInt)
    }
}

extension BlockChain.Hash: Comparable {
    @inlinable
    public static func < (lhs: BlockChain.Hash<HashType>, rhs: BlockChain.Hash<HashType>) -> Bool {
        for (lhs, rhs) in zip(lhs.bigEndian, rhs.bigEndian) {
            if lhs < rhs {
                return true
            } else if lhs > rhs {
                return false
            }
        }
        return lhs.count < rhs.count
    }
}

extension BlockChain.Hash: Codable {
    @inlinable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.bigEndian.hexEncodedString)
    }

    @usableFromInline
    struct HexError: Swift.Error {
        @usableFromInline
        internal init() {}
    }

    @inlinable
    public init(from decoder: Decoder) throws {

        let decoder = try decoder.singleValueContainer()
        let string = try decoder.decode(String.self)

        func checkStringHex(_ string: String) throws {
            guard string.count == 64,
                string.isHex()
            else {
                throw HexError()
            }
        }

        try checkStringHex(string)
        let bytes = string.hex2Bytes

        self = .big(bytes)
    }
}

// MARK: Hash / CustomStringConvertible
extension BlockChain.Hash: CustomStringConvertible {
    @inlinable
    public var description: String {
        self.bigEndian.hexEncodedString
    }
}

// MARK: MerkleTree
public extension BlockChain {
    struct Error: Swift.Error, Sendable {
        @usableFromInline
        let description: String
        @usableFromInline
        let event: StaticString

        @inlinable
        public init(description: String, event: StaticString) {
            self.description = description
            self.event = event
        }
    }

    @inlinable
    static func _inner<S: Sequence, T: MerkleSourceHash>(
        _ hashList: S,
        count: Int,
        tree: [[BlockChain.Hash<MerkleHash>]] = .init()
    )
        throws -> (root: BlockChain.Hash<MerkleHash>, tree: [[BlockChain.Hash<MerkleHash>]])
    where S.Element == BlockChain.Hash<T> {

        var hashIterator = hashList.makeIterator()

        guard count > 1 else {
            guard let root = hashIterator.next()?.asMerkleHash else {
                throw Error(
                    description: "sequence input hashList cannot be empty",
                    event: #function)
            }
            return (root, tree)
        }

        var parentHashes: [BlockChain.Hash<MerkleHash>] = []
        while let left = hashIterator.next() {
            let right = hashIterator.next()
            try parentHashes.append(left.merklePair(right))
        }

        let halfCeiling = (count + 1) / 2
        return try Self._inner(parentHashes, count: halfCeiling, tree: tree + [parentHashes])
    }

    @inlinable
    static func merkleRoot<C: Collection, T: MerkleSourceHash>(from collection: C)
        throws -> BlockChain.Hash<MerkleHash>
    where C.Element == BlockChain.Hash<T> {

        return try Self._inner(collection, count: collection.count).root
    }

    @inlinable
    static func merkleTree<C: Collection, T: MerkleSourceHash>(from collection: C)
        throws -> [[BlockChain.Hash<MerkleHash>]]
    where C.Element == BlockChain.Hash<T> {

        return try Self._inner(collection, count: collection.count).tree
    }

    enum MerklePosition<T: MerkleSourceHash>: Sendable {
        case left(BlockChain.Hash<T>)
        case right(BlockChain.Hash<T>)

        @inlinable
        public init(index: Int, hash: BlockChain.Hash<T>) {
            self = index & 0b1 == 0 ? .left(hash) : .right(hash)
        }

        @inlinable
        public static prefix func ! (value: Self) -> Self {
            switch value {
            case .left(let hash):
                return .right(hash)
            case .right(let hash):
                return .left(hash)
            }
        }

        @inlinable
        public func merklePair(_ hash: BlockChain.Hash<T>) -> BlockChain.Hash<MerkleHash> {
            switch self {
            case .left(let left):
                return left.appendHash(hash)
            case .right(let right):
                return hash.appendHash(right)
            }
        }
    }

    @inlinable
    static func merkleProof<C: Collection, T: MerkleSourceHash>(from collection: C, index: Int)
        throws -> (
            neighbour: MerklePosition<T>, parents: [MerklePosition<MerkleHash>],
            root: BlockChain.Hash<MerkleHash>
        )
    where C.Element == BlockChain.Hash<T> {

        precondition(collection.count > 1)
        precondition(index >= 0 && index < collection.count, "leaf index out of range")

        let tree = try Self._inner(collection, count: collection.count)

        let leafSibling = (index ^ 0b1) < collection.count ? (index ^ 0b1) : index
        let neighbour = MerklePosition<T>(
            index: leafSibling,
            hash: collection[collection.index(collection.startIndex, offsetBy: leafSibling)]
        )

        var parents: [MerklePosition<MerkleHash>] = []
        parents.reserveCapacity(Swift.max(0, tree.tree.count - 1))
        for (level, nodes) in tree.tree.enumerated() where level < tree.tree.count - 1 {
            let node = index >> (level + 1)
            let sibling = (node ^ 0b1) < nodes.count ? (node ^ 0b1) : node
            parents.append(MerklePosition(index: sibling, hash: nodes[sibling]))
        }

        return (neighbour, parents, tree.root)
    }

    @inlinable
    static func merkleVerifyProof<T: MerkleSourceHash>(
        _ value: BlockChain.Hash<T>,
        neighbour: MerklePosition<T>,
        parents: [MerklePosition<MerkleHash>]
    ) -> BlockChain.Hash<MerkleHash> {

        let first = neighbour.merklePair(value)
        return parents.reduce(first) {
            $1.merklePair($0)
        }
    }
}
