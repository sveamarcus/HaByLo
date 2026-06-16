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

@Suite struct Base58Tests {
    // Canonical Bitcoin Base58 test vectors (hex payload <-> base58 string).
    static let vectors: [(hex: String, base58: String)] = [
        ("", ""),
        ("61", "2g"),
        ("626262", "a3gV"),
        ("636363", "aPEr"),
        ("73696d706c792061206c6f6e6720737472696e67", "2cFupjhnEsSn59qHXstmK2ffpLv2"),
        (
            "00eb15231dfceb60925886b67d065299925915aeb172c06647",
            "1NS17iag9jJgTHD1VXjvLCEnZuQ3rJDE9L"
        ),
        ("516b6fcd0f", "ABnLTmg"),
        ("bf4f89001e670274dd", "3SEo3LWLoPntC"),
        ("572e4794", "3EFU7m"),
        ("ecac89cad93923c02321", "EJDM8drfXA6uyA"),
        ("10c8511e", "Rt5zm"),
        ("00000000000000000000", "1111111111"),
    ]

    @Test(arguments: vectors)
    func encode(_ vector: (hex: String, base58: String)) {
        #expect(vector.hex.hex2Bytes.base58Encode() == vector.base58)
    }

    @Test(arguments: vectors)
    func decode(_ vector: (hex: String, base58: String)) throws {
        #expect(try vector.base58.base58Decode() == vector.hex.hex2Bytes)
    }

    @Test func decodeRejectsInvalidCharacters() {
        // '0', 'O', 'I', 'l' are not in the Base58 alphabet.
        #expect(throws: DecodeBase58Error.self) { _ = try "0OIl".base58Decode() }
    }

    @Test func decodeRejectsInterleavedWhitespace() {
        #expect(throws: DecodeBase58Error.self) { _ = try "ab cd".base58Decode() }
    }

    @Test func decodeTrimsSurroundingWhitespace() throws {
        #expect(try "  a3gV  ".base58Decode() == "626262".hex2Bytes)
    }

    @Test func encodeDecodeRoundTrip() throws {
        // Deterministic pseudo-random payloads incl. leading zeros and full bytes.
        var seed: UInt64 = 0x1234_5678_9abc_def0
        for length in 0..<40 {
            var bytes: [UInt8] = []
            for _ in 0..<length {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                bytes.append(UInt8(truncatingIfNeeded: seed >> 33))
            }
            // Force some leading-zero cases.
            if length > 2 { bytes[0] = 0 }
            #expect(
                try bytes.base58Encode().base58Decode() == bytes, "round-trip failed len=\(length)")
        }
    }

    // MARK: base58Check
    @Test func base58CheckRoundTrip() throws {
        for length in [1, 4, 20, 21, 32, 33] {
            let bytes = (0..<length).map { UInt8($0 &* 7 &+ 1) }
            let encoded = bytes.base58CheckEncode()
            #expect(try Array(bytes.base58CheckEncode().base58CheckDecode()) == bytes)
            // A check-encoded payload is also valid plain Base58.
            #expect(throws: Never.self) { _ = try encoded.base58Decode() }
        }
    }

    @Test func base58CheckDetectsCorruptedChecksum() throws {
        let bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04]
        var encoded = Array(bytes.base58CheckEncode())
        // Flip the final character to a different valid Base58 symbol.
        encoded[encoded.count - 1] = encoded.last == "z" ? "y" : "z"
        #expect(throws: DecodeBase58Error.self) {
            _ = try String(encoded).base58CheckDecode()
        }
    }
}
