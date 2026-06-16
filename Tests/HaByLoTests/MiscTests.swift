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

@Suite struct UnixTimeTests {
    @Test func unixTimeIsPlausibleEpoch() {
        let t = unixTime()
        #expect(t > 1_600_000_000)  // after 2020-09
        #expect(t < 4_102_444_800)  // before year 2100
    }

    @Test func unixTimeInSecondsAgreesWithUnixTime() {
        let seconds = unixTimeInSeconds()
        let fractional = unixTime()
        #expect(seconds > 1_600_000_000)
        // Different clocks/syscalls, so allow a small skew.
        #expect(abs(Int(seconds) - Int(fractional)) <= 2)
    }

    @Test func unixTimeIsNonDecreasing() {
        let t1 = unixTime()
        let t2 = unixTime()
        #expect(t2 >= t1)
    }
}

@Suite struct OptionalZipTests {
    @Test func combinesWhenBothPresent() {
        let result = zip(Int?.some(1), Int?.some(2))
        #expect(result?.0 == 1)
        #expect(result?.1 == 2)
    }

    @Test func nilWhenEitherMissing() {
        #expect(zip(Int?.none, Int?.some(2)) == nil)
        #expect(zip(Int?.some(1), Int?.none) == nil)
        #expect(zip(Int?.none, Int?.none) == nil)
    }
}
