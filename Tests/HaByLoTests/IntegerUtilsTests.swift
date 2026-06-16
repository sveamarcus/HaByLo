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

@Suite struct IntegerUtilsTests {
    // MARK: Bitcoin compactSize (variableLengthCode)
    static let compactSize: [(value: UInt64, bytes: [UInt8])] = [
        (0, [0x00]),
        (1, [0x01]),
        (0xFC, [0xFC]),
        (0xFD, [0xFD, 0xFD, 0x00]),
        (0xFFFF, [0xFD, 0xFF, 0xFF]),
        (0x1_0000, [0xFE, 0x00, 0x00, 0x01, 0x00]),
        (0xFFFF_FFFF, [0xFE, 0xFF, 0xFF, 0xFF, 0xFF]),
        // Review fix: 2^32 must be the 9-byte form, not a single 0x00 byte.
        (0x1_0000_0000, [0xFF, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00]),
        (UInt64.max, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
    ]

    @Test(arguments: compactSize)
    func variableLengthCode(_ vector: (value: UInt64, bytes: [UInt8])) {
        #expect(vector.value.variableLengthCode.map { $0 } == vector.bytes)
    }

    @Test func variableLengthCodeBoundaryHasNoGap() {
        // No value around the 2^32 boundary collapses to a wrong/short encoding.
        #expect(UInt64(0xFFFF_FFFF).variableLengthCode.count == 5)
        #expect(UInt64(0x1_0000_0000).variableLengthCode.count == 9)
        #expect(UInt64(0x1_0000_0001).variableLengthCode.count == 9)
    }

    // MARK: cVarInt (offset varint) <-> Bitcoin reference bytes
    static let cVarIntVectors: [(value: UInt64, bytes: [UInt8])] = [
        (0, [0x00]),
        (127, [0x7F]),
        (128, [0x80, 0x00]),
        (255, [0x80, 0x7F]),
        (16383, [0xFE, 0x7F]),
        (16384, [0xFF, 0x00]),
        (4_294_967_296, [0x8E, 0xFE, 0xFE, 0xFF, 0x00]),
    ]

    @Test(arguments: cVarIntVectors)
    func cVarIntEncoding(_ vector: (value: UInt64, bytes: [UInt8])) {
        #expect(vector.value.cVarInt == vector.bytes)
    }

    // MARK: fixed-width endian byte decomposition
    @Test func bigAndLittleEndianBytes() {
        #expect(UInt8(0xAB).bigEndianBytes == [0xAB])
        #expect(UInt8(0xAB).littleEndianBytes == [0xAB])
        #expect(UInt16(0x0102).bigEndianBytes == [0x01, 0x02])
        #expect(UInt16(0x0102).littleEndianBytes == [0x02, 0x01])
        #expect(UInt32(0x0102_0304).bigEndianBytes == [0x01, 0x02, 0x03, 0x04])
        #expect(UInt32(0x0102_0304).littleEndianBytes == [0x04, 0x03, 0x02, 0x01])
        #expect(
            UInt64(0x0102_0304_0506_0708).bigEndianBytes
                == [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        #expect(
            UInt64(0x0102_0304_0506_0708).littleEndianBytes
                == [0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01])
    }

    @Test func endianBytesAreReversesOfEachOther() {
        for value: UInt32 in [0, 1, 0xDEAD_BEEF, 0xFFFF_FFFF, 0x1234_5678] {
            #expect(value.bigEndianBytes == value.littleEndianBytes.reversed())
        }
    }
}
