import Foundation

/// 小端字节读写工具，用于解析/构造 PTP/PTP-IP 数据包。
struct ByteReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var remaining: Int { bytes.count - offset }

    var isAtEnd: Bool { offset >= bytes.count }

    private func require(_ n: Int) throws {
        if offset + n > bytes.count {
            throw PTPError.badData("数据不足: 需要 \(n) 字节，剩余 \(remaining)")
        }
    }

    mutating func readUInt8() throws -> UInt8 {
        try require(1)
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func readUInt16() throws -> UInt16 {
        try require(2)
        let v = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
        offset += 2
        return v
    }

    mutating func readUInt32() throws -> UInt32 {
        try require(4)
        let v = UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
        offset += 4
        return v
    }

    mutating func readUInt64() throws -> UInt64 {
        let lo = try readUInt32()
        let hi = try readUInt32()
        return UInt64(hi) << 32 | UInt64(lo)
    }

    mutating func readInt8() throws -> Int8 { Int8(bitPattern: try readUInt8()) }
    mutating func readInt16() throws -> Int16 { Int16(bitPattern: try readUInt16()) }
    mutating func readInt32() throws -> Int32 { Int32(bitPattern: try readUInt32()) }
    mutating func readInt64() throws -> Int64 { Int64(bitPattern: try readUInt64()) }

    /// 读取 PTP 字符串：一个 UTF-16 码元数量（含结尾 NUL）加 UTF-16LE 内容。
    mutating func readPTPString() throws -> String {
        let characterCount = Int(try readUInt8())
        guard characterCount > 0 else { return "" }

        var units: [UInt16] = []
        units.reserveCapacity(characterCount - 1)
        for index in 0..<characterCount {
            let unit = try readUInt16()
            if index < characterCount - 1 {
                units.append(unit)
            }
        }
        return String(decoding: units, as: UTF16.self)
    }

    mutating func readUInt16Array() throws -> [UInt16] {
        let count = Int(try readUInt32())
        var arr: [UInt16] = []
        arr.reserveCapacity(count)
        for _ in 0..<count {
            arr.append(try readUInt16())
        }
        return arr
    }

    mutating func readUInt32Array() throws -> [UInt32] {
        let count = Int(try readUInt32())
        var arr: [UInt32] = []
        arr.reserveCapacity(count)
        for _ in 0..<count {
            arr.append(try readUInt32())
        }
        return arr
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        try require(count)
        defer { offset += count }
        return Array(bytes[offset..<(offset + count)])
    }
}

enum ByteWriter {
    static func append(_ value: UInt8, to out: inout [UInt8]) {
        out.append(value)
    }

    static func append(_ value: UInt16, to out: inout [UInt8]) {
        out.append(UInt8(value & 0xFF))
        out.append(UInt8((value >> 8) & 0xFF))
    }

    static func append(_ value: UInt32, to out: inout [UInt8]) {
        out.append(UInt8(value & 0xFF))
        out.append(UInt8((value >> 8) & 0xFF))
        out.append(UInt8((value >> 16) & 0xFF))
        out.append(UInt8((value >> 24) & 0xFF))
    }

    static func append(_ value: UInt64, to out: inout [UInt8]) {
        append(UInt32(value & 0xFFFF_FFFF), to: &out)
        append(UInt32(value >> 32), to: &out)
    }

    static func append(_ value: Int8, to out: inout [UInt8]) {
        out.append(UInt8(bitPattern: value))
    }

    static func append(_ value: Int16, to out: inout [UInt8]) {
        append(UInt16(bitPattern: value), to: &out)
    }

    static func append(_ value: Int32, to out: inout [UInt8]) {
        append(UInt32(bitPattern: value), to: &out)
    }

    static func append(_ value: Int64, to out: inout [UInt8]) {
        append(UInt64(bitPattern: value), to: &out)
    }

    /// 写入以 0 结尾的 ASCII 字符串。
    static func append(_ string: String, to out: inout [UInt8]) {
        for byte in string.utf8 { out.append(byte) }
        out.append(0)
    }

    /// 写入 PTP 字符串：一个 UTF-16 码元数量（含结尾 NUL）加 UTF-16LE 内容。
    static func appendPTPString(_ string: String, to out: inout [UInt8]) {
        let units = Array(string.utf16)
        precondition(units.count < UInt8.max, "PTP 字符串最多支持 254 个 UTF-16 码元")
        append(UInt8(units.count + 1), to: &out)
        for unit in units {
            append(unit, to: &out)
        }
        append(UInt16(0), to: &out)
    }

    /// 写入 UTF-16LE 字符串（含结束 \0）。
    static func appendUTF16LE(_ string: String, to out: inout [UInt8]) {
        let units = Array(string.utf16)
        for unit in units {
            out.append(UInt8(unit & 0xFF))
            out.append(UInt8((unit >> 8) & 0xFF))
        }
        out.append(0)
        out.append(0)
    }
}
