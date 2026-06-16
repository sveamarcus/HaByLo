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

@Suite struct CVarIntExtensionTests {
    let allocator = ByteBufferAllocator()

    static let testCVarIntBytes: [UInt64: [UInt8]] = [
        0: [0x00],
        1: [0x01],
        127: [0x7F],
        128: [0x80, 0x00],
        255: [0x80, 0x7F],
        256: [0x81, 0x00],
        2288: [0x90, 0x70],
        16383: [0xFE, 0x7F],
        16384: [0xFF, 0x00],
        16511: [0xFF, 0x7F],
        65535: [0x82, 0xFE, 0x7F],
        4_294_967_296: [0x8E, 0xFE, 0xFE, 0xFF, 0x00],
        1_152_921_508_901_814_399: [0x8E, 0xFE, 0xFE, 0xFF, 0x8E, 0xFE, 0xFE, 0xFF, 0x7F],
    ]

    @Test func reads() {
        var buffer = self.allocator.buffer(capacity: 32)
        for bytes in Self.testCVarIntBytes.values {
            buffer.writeBytes(bytes)
        }

        while let value: UInt64 = buffer.readCVarInt() {
            #expect(Self.testCVarIntBytes[value] != nil)
        }
        #expect(buffer.readableBytes == 0)
    }

    @Test func writes() {
        for (value, bytes) in Self.testCVarIntBytes {
            #expect(value.cVarInt == bytes)
        }
    }

    @Test func writeReadBack() {
        for value in Self.testCVarIntBytes.keys {
            var buffer = self.allocator.buffer(capacity: 10)
            buffer.writeBytes(value.cVarInt)
            #expect(buffer.readCVarInt() == value)
        }
    }

    @Test func overflow() throws {
        var singleByteBuffer = self.allocator.buffer(capacity: 1)
        singleByteBuffer.writeBytes([0x01])
        #expect(singleByteBuffer.readCVarInt(as: UInt8.self) == 1)

        let overflowBytes = try #require(Self.testCVarIntBytes[4_294_967_296])
        var overflowBuffer = self.allocator.buffer(capacity: 8)
        overflowBuffer.writeBytes(overflowBytes)
        let save = overflowBuffer
        #expect(overflowBuffer.readCVarInt(as: UInt8.self) == nil)
        overflowBuffer = save
        #expect(overflowBuffer.readCVarInt(as: UInt16.self) == nil)
        overflowBuffer = save
        #expect(overflowBuffer.readCVarInt(as: UInt32.self) == nil)
        overflowBuffer = save
        #expect(overflowBuffer.readCVarInt(as: UInt64.self) == 4_294_967_296)

        let overflow2Bytes = try #require(Self.testCVarIntBytes[1_152_921_508_901_814_399])
        var overflow2Buffer = self.allocator.buffer(capacity: 10)
        overflow2Buffer.writeBytes(overflow2Bytes)
        let save2 = overflow2Buffer
        #expect(overflow2Buffer.readCVarInt(as: UInt8.self) == nil)
        overflow2Buffer = save2
        #expect(overflow2Buffer.readCVarInt(as: UInt16.self) == nil)
        overflow2Buffer = save2
        #expect(overflow2Buffer.readCVarInt(as: UInt32.self) == nil)
        overflow2Buffer = save2
        #expect(overflow2Buffer.readCVarInt(as: UInt64.self) == 1_152_921_508_901_814_399)
    }
}
