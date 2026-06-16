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

@Suite struct ByteUtilsTests {
    // MARK: hex encode / decode
    @Test func hexEncodedString() {
        #expect([UInt8]().hexEncodedString == "")
        #expect([0x00].hexEncodedString == "00")
        #expect([0x0a].hexEncodedString == "0a")
        #expect([0xff].hexEncodedString == "ff")
        #expect([0xde, 0xad, 0xbe, 0xef].hexEncodedString == "deadbeef")
    }

    @Test func hex2Bytes() {
        #expect("".hex2Bytes == [])
        #expect("deadbeef".hex2Bytes == [0xde, 0xad, 0xbe, 0xef])
        // Case-insensitive.
        #expect("DEADBEEF".hex2Bytes == [0xde, 0xad, 0xbe, 0xef])
        #expect("00ff".hex2Bytes == [0x00, 0xff])
    }

    @Test func hex2BytesDropsTrailingNibbleAndInvalidPairs() {
        // Odd length: trailing nibble dropped, no trap (review hardening).
        #expect("abc".hex2Bytes == [0xab])
        // Invalid pair skipped (matches the original compactMap semantics).
        #expect("zzab".hex2Bytes == [0xab])
    }

    @Test func hexRoundTrip() {
        for length in 0..<48 {
            let bytes = (0..<length).map { UInt8(($0 &* 37 &+ 11) & 0xFF) }
            #expect(bytes.hexEncodedString.hex2Bytes == bytes, "round-trip failed len=\(length)")
        }
    }

    // MARK: isHex
    @Test func isHex() {
        #expect("".isHex())  // empty is even-length, vacuously hex
        #expect("deadbeef".isHex())
        #expect("DEADBEEF".isHex())
        #expect("0123456789abcdefABCDEF".isHex())
        #expect(!"abc".isHex())  // odd length
        #expect(!"xyz0".isHex())  // non-hex chars
        #expect(!"de ad".isHex())  // whitespace
    }

    // MARK: ascii
    @Test func ascii() {
        #expect("ABC".ascii == [65, 66, 67])
        #expect("".ascii == [])
        #expect("0123".ascii == [0x30, 0x31, 0x32, 0x33])
        // Non-ASCII scalars are dropped.
        #expect("a\u{00e9}b".ascii == [0x61, 0x62])
    }

    // MARK: hex2Hash <-> description round-trip
    @Test func hex2HashRoundTripsWithDescription() {
        let hex = "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
        let hash: BlockChain.Hash<BlockHeaderHash> = hex.hex2Hash()
        #expect(hash.description == hex)
        #expect(hash.count == 32)
    }

    // MARK: withUnsafeRandomAccess
    @Test func withUnsafeRandomAccessExposesBytes() {
        let bytes: [UInt8] = [0, 1, 2, 3, 4, 5]
        // Contiguous source (Array) and non-contiguous (AnySequence) yield identical bytes.
        let fromArray = bytes.withUnsafeRandomAccess { Array($0) }
        let fromSeq = AnySequence(bytes).withUnsafeRandomAccess { Array($0) }
        #expect(fromArray == bytes)
        #expect(fromSeq == bytes)
    }
}
