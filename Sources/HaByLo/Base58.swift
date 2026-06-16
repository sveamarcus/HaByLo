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
import struct Foundation.CharacterSet

public enum DecodeBase58Error: Swift.Error, Sendable {
    case checksumMismatch
    case interleavedWhitespace
    case illegalInput
    case invalidBase58Map
}

@usableFromInline
let mapBase58: [UInt8?] = {
    let original: [Int8] = [
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, -1, -1, -1, -1, -1, -1,
        -1, 9, 10, 11, 12, 13, 14, 15, 16, -1, 17, 18, 19, 20, 21, -1,
        22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, -1, -1, -1, -1, -1,
        -1, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, -1, 44, 45, 46,
        47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    ]
    assert(original.count == 256)
    return original.map {
        $0 < 0 ? nil : UInt8($0)
    }
}()

@usableFromInline
let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

public extension StringProtocol {
    @inlinable
    func base58Decode() throws -> [UInt8] {
        let trimmedString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingZeros = trimmedString.prefix { $0 == "1" }.count

        var result: [UInt8] = .init(repeating: 0, count: self.count * 733 / 1000 + 1)
        var workingLength = result.endIndex.advanced(by: -1)
        for c in trimmedString[
            trimmedString.index(trimmedString.startIndex, offsetBy: leadingZeros)...]
        {
            guard !c.isWhitespace else {
                throw DecodeBase58Error.interleavedWhitespace
            }

            guard let i = c.asciiValue.map(Int.init), mapBase58.indices.contains(i) else {
                throw DecodeBase58Error.invalidBase58Map
            }

            guard var carry = mapBase58[i].map(Int.init) else {
                throw DecodeBase58Error.illegalInput
            }

            var loopIndex = result.endIndex.advanced(by: -1)
            while loopIndex > workingLength || carry > 0 {
                carry += 58 * Int(result[loopIndex])
                let qr = carry.quotientAndRemainder(dividingBy: 256)
                result[loopIndex] = UInt8(qr.remainder)
                carry = qr.quotient

                guard loopIndex > result.startIndex else {
                    break
                }
                result.formIndex(before: &loopIndex)
            }
            workingLength = loopIndex
        }

        return Array(repeating: 0, count: leadingZeros) + result.drop { $0 == 0 }
    }

    @inlinable
    func base58CheckDecode() throws -> ArraySlice<UInt8> {
        let decode = try self.base58Decode()
        let data = decode.dropLast(4)
        let checksum = decode.suffix(4)

        guard data.hash256.prefix(4).elementsEqual(checksum) else {
            throw DecodeBase58Error.checksumMismatch
        }

        return data
    }
}

public extension Collection where Element == UInt8 {
    @inlinable
    func base58Encode() -> String {
        let leadingZeros = self.prefix { $0 == 0 }.count

        var result: [UInt8] = .init(repeating: 0, count: self.count * 137 / 100 + 1)
        var workingLength = result.endIndex.advanced(by: -1)
        for byte in self[self.index(self.startIndex, offsetBy: leadingZeros)...] {
            var carry = Int(byte)

            var loopIndex = result.endIndex.advanced(by: -1)
            while loopIndex > workingLength || carry > 0 {
                carry += 256 * Int(result[loopIndex])
                let qr = carry.quotientAndRemainder(dividingBy: 58)
                result[loopIndex] = UInt8(qr.remainder)
                carry = qr.quotient

                guard loopIndex > result.startIndex else {
                    break
                }
                result.formIndex(before: &loopIndex)
            }
            workingLength = loopIndex
        }

        return String(
            (Array(repeating: UInt8(0), count: leadingZeros) + result.drop { $0 == 0 })
                .map { alphabet[alphabet.index(alphabet.startIndex, offsetBy: Int($0))] }
        )
    }

    @inlinable
    func base58CheckEncode() -> String {
        let checksum = self.hash256.prefix(4)

        let copy = self[...]
        return (copy + checksum).base58Encode()
    }
}
