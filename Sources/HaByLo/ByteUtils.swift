//===----------------------------------------------------------------------===//
//
// This source file is part of the fltrECC open source project
//
// Copyright (c) 2022 fltrWallet AG and the fltrECC project authors
// Licensed under Apache License v2.0
//
// See LICENSE.md for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Lowercase hex digit table, indexed by nibble value (0...15). Computed once.
@usableFromInline
let _hexAlphabet: [UInt8] = Array("0123456789abcdef".utf8)

// Decodes one ASCII hex digit ('0'-'9', 'a'-'f', 'A'-'F') to its 0...15 value, or
// nil when the byte is not a hex digit.
@inlinable
func _hexNibble(_ ascii: UInt8) -> UInt8? {
    switch ascii {
    case 0x30...0x39: return ascii &- 0x30  // '0'...'9'
    case 0x61...0x66: return ascii &- 0x61 &+ 10  // 'a'...'f'
    case 0x41...0x46: return ascii &- 0x41 &+ 10  // 'A'...'F'
    default: return nil
    }
}

// MARK: withUnsafeRandomAccess
public extension Sequence where Element == UInt8 {
    // Zero-copy contiguous access when the sequence already has contiguous storage
    // (Array, ArraySlice, ByteBufferView, …); materializes into an Array only as a
    // last resort for non-contiguous sequences.
    @inlinable
    func withUnsafeRandomAccess<R>(_ closure: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try self.withContiguousStorageIfAvailable { buffer in
            try closure(UnsafeRawBufferPointer(buffer))
        }
            ?? Array(self).withUnsafeBufferPointer { buffer in
                try closure(UnsafeRawBufferPointer(buffer))
            }
    }
}

// MARK: hexEncodedString
public extension Sequence where Element == UInt8 {
    // Lowercase hex encoding built in a single UTF-8 byte buffer (two ASCII digits
    // per input byte) and wrapped once as a String — no per-byte String allocation,
    // no `String(format:)` (Foundation), and no `joined()`.
    @inlinable
    var hexEncodedString: String {
        var ascii: [UInt8] = []
        ascii.reserveCapacity(self.underestimatedCount * 2)
        for byte in self {
            ascii.append(_hexAlphabet[Int(byte >> 4)])
            ascii.append(_hexAlphabet[Int(byte & 0x0F)])
        }
        return String(decoding: ascii, as: UTF8.self)
    }
}

// MARK: String // ascii, hex2Bytes, hex2Hash, isHex
public extension StringProtocol {
    @inlinable
    var ascii: [UInt8] {
        compactMap {
            $0.asciiValue
        }
    }

    // Parses a hex string by scanning UTF-8 code units directly — no intermediate
    // `[Character]` and no per-pair `String`. A pair containing a non-hex digit is
    // skipped (matching the previous `compactMap` semantics); a dangling final
    // nibble on odd-length input is ignored rather than trapping.
    @inlinable
    var hex2Bytes: [UInt8] {
        let utf8 = self.utf8
        var bytes: [UInt8] = []
        bytes.reserveCapacity(utf8.underestimatedCount / 2)
        var iterator = utf8.makeIterator()
        while let high = iterator.next() {
            guard let low = iterator.next() else { break }
            guard let hi = _hexNibble(high), let lo = _hexNibble(low) else { continue }
            bytes.append(hi << 4 | lo)
        }
        return bytes
    }

    @inlinable
    func hex2Hash<To>(as: To.Type = To.self) -> BlockChain.Hash<To> {
        .init(.big(self.hex2Bytes))
    }

    // True iff the string has even length and every code unit is a hex digit
    // (case-insensitive). Single pass over UTF-8 with no `CharacterSet`
    // construction or `lowercased()` copy.
    @inlinable
    func isHex() -> Bool {
        var count = 0
        for byte in self.utf8 {
            guard _hexNibble(byte) != nil else { return false }
            count &+= 1
        }
        return count % 2 == 0
    }
}
