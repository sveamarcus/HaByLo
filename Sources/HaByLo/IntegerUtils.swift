import struct Foundation.Data

public extension BinaryInteger {
    @inlinable
    var variableLengthCode: Data {
        assert(self.signum() >= 0)

        var data = Data()

        switch self {
        case 0xFD...0xFF_FF:
            data.append(0xFD)
            let swapped = UInt16(truncatingIfNeeded: self).littleEndian
            let bits = withUnsafeBytes(of: swapped) { Data($0) }
            data.append(bits)
        case 0x00_01_00_00...0xFF_FF_FF_FF:
            data.append(0xFE)
            let swapped = UInt32(truncatingIfNeeded: self).littleEndian
            let bits = withUnsafeBytes(of: swapped) { Data($0) }
            data.append(bits)
        case _ where self > 0x00_00_00_01_00_00_00_00:  // ...0xFF_FF_FF_FF_FF_FF_FF_FF
            data.append(0xFF)
            let swapped = UInt64(truncatingIfNeeded: self).littleEndian
            let bits = withUnsafeBytes(of: swapped) { Data($0) }
            data.append(bits)
        default: data.append(UInt8(truncatingIfNeeded: self))  // 0..<0xFD
        }

        return data
    }
}

public extension BinaryInteger {
    @inlinable
    var cVarInt: [UInt8] {
        assert(self.signum() >= 0)

        var bytes: [UInt8] = []
        bytes.reserveCapacity((self.bitWidth + 6) / 7)

        var nextByte: UInt8 = UInt8(self & 0x7F)
        bytes.append(nextByte)
        var me = self
        while me > 0x7F {
            me = (me >> 7) - 1
            nextByte = UInt8((me & 0x7F) | 0x80)
            bytes.append(nextByte)
        }

        return bytes.reversed()
    }
}

extension FixedWidthInteger where Self: UnsignedInteger {
    @inlinable
    public var bigEndianBytes: [UInt8] {
        stride(from: Self.bitWidth - UInt8.bitWidth, through: 0, by: -UInt8.bitWidth).map {
            UInt8(truncatingIfNeeded: self >> $0)
        }
    }

    @inlinable
    public var littleEndianBytes: [UInt8] {
        stride(from: 0, to: Self.bitWidth, by: UInt8.bitWidth).map {
            UInt8(truncatingIfNeeded: self >> $0)
        }
    }
}
