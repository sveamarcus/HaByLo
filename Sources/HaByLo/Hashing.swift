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
import protocol Foundation.ContiguousBytes
import struct NIOCore.ByteBuffer

// Double SHA-256. Bytes are fed through the incremental HashFunction API
// (`update(bufferPointer:)`), which is available on every swift-crypto platform
// (Apple, Linux, Android, Windows, WASI) and avoids relying on a `DataProtocol`
// conformance for raw buffer pointers that may not exist off-Apple.
@inlinable
public func hash256(_ rbp: UnsafeRawBufferPointer) -> [UInt8] {
    var first = SHA256()
    first.update(bufferPointer: rbp)
    var second = SHA256()
    first.finalize().withUnsafeBytes { second.update(bufferPointer: $0) }
    return Array(second.finalize())
}

@inlinable
public func sha256(_ rbp: UnsafeRawBufferPointer) -> [UInt8] {
    var hasher = SHA256()
    hasher.update(bufferPointer: rbp)
    return Array(hasher.finalize())
}

public extension Array where Element == UInt8 {
    @inlinable
    var hash256: [UInt8] {
        self.withUnsafeBytes(hash256(_:))
    }

    @inlinable
    var sha256: [UInt8] {
        self.withUnsafeBytes(sha256(_:))
    }

    @inlinable
    var checksum: UInt32 {
        self.hash256.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

public extension ArraySlice where Element == UInt8 {
    @inlinable
    var hash256: [UInt8] {
        self.withUnsafeBytes(hash256(_:))
    }

    @inlinable
    var sha256: [UInt8] {
        self.withUnsafeBytes(sha256(_:))
    }

    @inlinable
    var checksum: UInt32 {
        self.hash256.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

public extension ByteBuffer {
    @inlinable
    var hash256: [UInt8] {
        self.withUnsafeReadableBytes(hash256(_:))
    }

    @inlinable
    var sha256: [UInt8] {
        self.withUnsafeReadableBytes(sha256(_:))
    }

    @inlinable
    var checksum: UInt32 {
        self.hash256.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

public extension ContiguousBytes {
    @inlinable
    var hash256: [UInt8] {
        self.withUnsafeBytes(hash256(_:))
    }

    @inlinable
    var sha256: [UInt8] {
        self.withUnsafeBytes(sha256(_:))
    }

    @inlinable
    var checksum: UInt32 {
        self.hash256.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

public extension Sequence where Element == UInt8 {
    @inlinable
    var hash256: [UInt8] {
        self.withUnsafeRandomAccess(hash256(_:))
    }

    @inlinable
    var sha256: [UInt8] {
        self.withUnsafeRandomAccess(sha256(_:))
    }

    @inlinable
    var checksum: UInt32 {
        self.hash256.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }
}

public extension ByteBuffer {
    @inlinable
    mutating func readCVarInt<T: UnsignedInteger>(as: T.Type = T.self) -> T? {
        let save = self

        let width = MemoryLayout<T>.size * 8
        let highBit: T = 1 << (width - 1)
        let maxValue: T = highBit | (highBit - 1)
        let shiftLimit = width - 7

        var result: T = 0
        while let nextByte = self.readInteger(as: UInt8.self) {
            // Reject inputs whose next 7-bit shift would discard high bits.
            guard result >> shiftLimit == 0 else {
                self = save
                return nil
            }

            result = (result << 7) | T(nextByte & 0x7F)
            if (nextByte & 0x80) > 0 {
                // Continuation byte adds one; reject if that would exceed T.max.
                guard result < maxValue else {
                    self = save
                    return nil
                }
                result += 1
            } else {
                return result
            }
        }

        self = save
        return nil
    }
}

public extension ByteBuffer {
    @inlinable
    mutating func readVarInt() -> UInt64? {
        let save = self

        let byte = self.readInteger(endianness: .little, as: UInt8.self).map { UInt64($0) }

        let readVarInt: UInt64?

        switch byte {
        case 0xfd?:
            readVarInt = self.readInteger(endianness: .little, as: UInt16.self).map { UInt64($0) }
        case 0xfe?:
            readVarInt = self.readInteger(endianness: .little, as: UInt32.self).map { UInt64($0) }
        case 0xff?: readVarInt = self.readInteger(endianness: .little, as: UInt64.self)
        default: readVarInt = byte
        }

        guard let result = readVarInt else {
            self = save
            return nil
        }

        return result
    }
}

// MARK: RipeMD160
public extension Array where Element == UInt8 {
    @inlinable
    var hash160: [UInt8] {
        self.sha256.ripeMd160()
    }

    @inlinable
    func ripeMd160() -> [UInt8] {
        var ripeMD160 = RipeMD160()
        ripeMD160.update(data: self[...])
        return ripeMD160.finalize()
    }
}

public extension ArraySlice where Element == UInt8 {
    @inlinable
    var hash160: [UInt8] {
        self.sha256.ripeMd160()
    }

    @inlinable
    func ripeMd160() -> [UInt8] {
        var ripeMD160 = RipeMD160()
        ripeMD160.update(data: self)
        return ripeMD160.finalize()
    }
}

public extension Sequence where Element == UInt8 {
    @inlinable
    var hash160: [UInt8] {
        self.sha256.ripeMd160()
    }

    @inlinable
    func ripeMd160() -> [UInt8] {
        var ripeMD160 = RipeMD160()
        ripeMD160.update(data: ArraySlice(self))
        return ripeMD160.finalize()
    }
}
