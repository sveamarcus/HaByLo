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

@inlinable
public func zip<W>(_ lhs: W?, _ rhs: W?) -> (W, W)? {
    lhs.flatMap { lhs in
        rhs.map { rhs in
            (lhs, rhs)
        }
    }
}
