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

import struct Crypto.SHA256

public protocol TaggedHash {
    static var tag: [UInt8] { get }
}

public extension BlockChain.Hash where HashType: TaggedHash {
    // Tagged hash = SHA256(tag ‖ tag ‖ message)
    @usableFromInline
    internal static func _taggedHash(message: UnsafeRawBufferPointer) -> BlockChain.Hash<HashType> {
        var hasher = SHA256()
        HashType.tag.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        HashType.tag.withUnsafeBytes { hasher.update(bufferPointer: $0) }
        hasher.update(bufferPointer: message)
        return Self(.little(Array(hasher.finalize())))
    }

    @inlinable
    static func makeHash<Stream: Collection>(from stream: Stream) -> BlockChain.Hash<HashType>
    where Stream.Element == UInt8 {
        stream.withUnsafeRandomAccess { Self._taggedHash(message: $0) }
    }

    @inlinable
    static func makeHash<Stream: Sequence>(from stream: Stream) -> BlockChain.Hash<HashType>
    where Stream.Element == UInt8 {
        stream.withUnsafeRandomAccess { Self._taggedHash(message: $0) }
    }
}
