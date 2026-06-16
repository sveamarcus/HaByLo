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
import NIOCore
import Testing

@Suite struct HashingTests {
    // MARK: SHA-256 known-answer vectors
    @Test func sha256KnownVectors() {
        #expect(
            [UInt8]().sha256
                == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".hex2Bytes)
        #expect(
            "abc".ascii.sha256
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad".hex2Bytes)
        #expect(
            "abc".ascii[...].sha256
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad".hex2Bytes)
    }

    // MARK: double-SHA-256 (hash256)
    @Test func hash256KnownVectors() {
        // hash256("") == SHA256(SHA256("")).
        #expect(
            [UInt8]().hash256
                == "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456".hex2Bytes)
        // hash256(x) == sha256(sha256(x)).
        let data = "the quick brown fox".ascii
        #expect(data.hash256 == data.sha256.sha256)
    }

    // MARK: HASH160 (RIPEMD160 of SHA256) — the Bitcoin definition
    @Test func hash160IsRipemdOfSha256AndConsistent() {
        let data = "hello world".ascii
        #expect(data.hash160 == data.sha256.ripeMd160())
        // All three overloads (Array / ArraySlice / Sequence) agree.
        #expect(data.hash160 == data[...].hash160)
        #expect(data.hash160 == AnySequence(data).hash160)
        #expect(data.hash160.count == 20)
    }

    // MARK: checksum is the little-endian first 4 bytes of hash256
    @Test func checksumIsLittleEndianFirst4OfHash256() {
        let data = "abc".ascii
        let h = data.hash256
        let expected =
            UInt32(h[0]) | UInt32(h[1]) << 8 | UInt32(h[2]) << 16 | UInt32(h[3]) << 24
        #expect(data.checksum == expected)
        #expect(data[...].checksum == expected)
        #expect(AnySequence(data).checksum == expected)
    }

    // MARK: readVarInt (Bitcoin compactSize) round-trips with variableLengthCode
    @Test func readVarIntMatchesCompactSize() {
        let allocator = ByteBufferAllocator()
        let values: [UInt64] = [
            0, 1, 0xFC, 0xFD, 0xFFFF, 0x1_0000, 0xFFFF_FFFF, 0x1_0000_0000, UInt64.max,
        ]
        for value in values {
            var buffer = allocator.buffer(capacity: 16)
            buffer.writeBytes(Array(value.variableLengthCode))
            #expect(buffer.readVarInt() == value, "readVarInt round-trip failed for \(value)")
            #expect(buffer.readableBytes == 0)
        }
    }

    @Test func readVarIntReturnsNilOnTruncatedInput() {
        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 4)
        buffer.writeBytes([0xFD, 0x01])  // promises 2 bytes, only 1 present
        let save = buffer
        #expect(buffer.readVarInt() == nil)
        // Non-destructive on failure.
        #expect(buffer.readableBytes == save.readableBytes)
    }

    // MARK: readCVarInt — full UInt64 range + transactional overflow (review fix)
    @Test func readCVarIntRoundTripsFullRange() {
        let allocator = ByteBufferAllocator()
        let values: [UInt64] = [
            0, 1, 0x7F, 0x80, 0xFF, 0xFFFF, 0x1_0000_0000,
            (UInt64(1) << 63) - 1, UInt64(1) << 63, (UInt64(1) << 63) + 1, UInt64.max,
        ]
        for value in values {
            var buffer = allocator.buffer(capacity: 16)
            buffer.writeBytes(value.cVarInt)
            #expect(
                buffer.readCVarInt(as: UInt64.self) == value, "cVarInt round-trip failed: \(value)")
        }
    }

    @Test func readCVarIntOverflowIsTransactional() {
        let allocator = ByteBufferAllocator()
        var buffer = allocator.buffer(capacity: 16)
        buffer.writeBytes(UInt64(0x1_0000_0000).cVarInt)
        let before = buffer.readerIndex
        #expect(buffer.readCVarInt(as: UInt8.self) == nil)
        #expect(buffer.readCVarInt(as: UInt16.self) == nil)
        #expect(buffer.readCVarInt(as: UInt32.self) == nil)
        #expect(buffer.readerIndex == before, "reader index must be restored after overflow")
        #expect(buffer.readCVarInt(as: UInt64.self) == 0x1_0000_0000)
    }
}
