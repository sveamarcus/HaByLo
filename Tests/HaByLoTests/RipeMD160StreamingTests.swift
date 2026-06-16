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

@Suite struct RipeMD160StreamingTests {
    static func oneShot(_ data: [UInt8]) -> [UInt8] {
        var md = RipeMD160()
        md.update(data: data[...])
        return md.finalize()
    }

    static func chunked(_ data: [UInt8], chunk: Int) -> [UInt8] {
        var md = RipeMD160()
        var i = 0
        while i < data.count {
            let end = Swift.min(i + chunk, data.count)
            md.update(data: data[i..<end])
            i = end
        }
        return md.finalize()
    }

    @Test func classicSplitDigest() {
        // The case the streaming bug corrupted: "abc" fed as "a" + "bc".
        #expect(Self.chunked("abc".ascii, chunk: 1) == "abc".ascii.ripeMd160())
        #expect(
            Self.chunked("abc".ascii, chunk: 1)
                == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc".hex2Bytes)
    }

    @Test func streamingMatchesOneShotAcrossLengthsAndChunks() {
        for length in [0, 1, 31, 55, 56, 63, 64, 65, 100, 127, 128, 191, 200, 256, 260] {
            let data = (0..<length).map { UInt8($0 & 0xFF) }
            let reference = Self.oneShot(data)
            for chunk in [1, 3, 7, 10, 13, 16, 32, 60, 63, 64, 65, 100] {
                #expect(
                    Self.chunked(data, chunk: chunk) == reference, "len=\(length) chunk=\(chunk)")
            }
        }
    }

    @Test func finalizeResetsState() {
        var md = RipeMD160()
        md.update(data: "abc".ascii[...])
        let first = md.finalize()
        // After finalize the instance is reset, so it can hash a new message.
        md.update(data: "".ascii[...])
        let second = md.finalize()
        #expect(first == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc".hex2Bytes)
        #expect(second == "9c1185a5c5e9fc54612808977ee8f548b2258d31".hex2Bytes)
    }
}
