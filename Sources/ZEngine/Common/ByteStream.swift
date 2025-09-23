import Foundation

/// Byte stream reader/writer for binary data processing
public class ByteStream {
    private var data: Data
    private var position: Int

    public init(_ data: Data = Data()) {
        self.data = data
        self.position = 0
    }

    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
        self.position = 0
    }

    // MARK: - Position Management

    public var currentPosition: Int {
        return position
    }

    public var length: Int {
        return data.count
    }

    public var isAtEnd: Bool {
        return position >= data.count
    }

    public var remainingBytes: Int {
        return max(0, data.count - position)
    }

    public func seek(to position: Int) {
        self.position = min(max(0, position), data.count)
    }

    public func skip(bytes: Int) {
        position = min(position + bytes, data.count)
    }

    public func rewind() {
        position = 0
    }

    // MARK: - Reading Methods

    public func readByte() throws -> UInt8 {
        guard position < data.count else {
            throw ByteStreamError.endOfStream
        }
        let byte = data[position]
        position += 1
        return byte
    }

    public func readSignedByte() throws -> Int8 {
        let byte = try readByte()
        return Int8(bitPattern: byte)
    }

    public func readWord() throws -> UInt16 {
        let high = try readByte()
        let low = try readByte()
        return UInt16(high) << 8 | UInt16(low)
    }

    public func readSignedWord() throws -> Int16 {
        let word = try readWord()
        return Int16(bitPattern: word)
    }

    public func readDWord() throws -> UInt32 {
        let high = try readWord()
        let low = try readWord()
        return UInt32(high) << 16 | UInt32(low)
    }

    public func readBytes(_ count: Int) throws -> Data {
        guard position + count <= data.count else {
            throw ByteStreamError.endOfStream
        }
        let result = data.subdata(in: position..<position + count)
        position += count
        return result
    }

    public func readString(length: Int, encoding: String.Encoding = .ascii) throws -> String {
        let bytes = try readBytes(length)
        guard let string = String(data: bytes, encoding: encoding) else {
            throw ByteStreamError.invalidEncoding
        }
        return string
    }

    public func readNullTerminatedString(encoding: String.Encoding = .ascii) throws -> String {
        var bytes = Data()
        while !isAtEnd {
            let byte = try readByte()
            if byte == 0 {
                break
            }
            bytes.append(byte)
        }
        guard let string = String(data: bytes, encoding: encoding) else {
            throw ByteStreamError.invalidEncoding
        }
        return string
    }

    // MARK: - Peek Methods (read without advancing position)

    public func peekByte(at offset: Int = 0) throws -> UInt8 {
        let pos = position + offset
        guard pos < data.count else {
            throw ByteStreamError.endOfStream
        }
        return data[pos]
    }

    public func peekWord(at offset: Int = 0) throws -> UInt16 {
        let pos = position + offset
        guard pos + 1 < data.count else {
            throw ByteStreamError.endOfStream
        }
        let high = data[pos]
        let low = data[pos + 1]
        return UInt16(high) << 8 | UInt16(low)
    }

    // MARK: - Writing Methods

    public func writeByte(_ value: UInt8) {
        if position >= data.count {
            data.append(value)
        } else {
            data[position] = value
        }
        position += 1
    }

    public func writeSignedByte(_ value: Int8) {
        writeByte(UInt8(bitPattern: value))
    }

    public func writeWord(_ value: UInt16) {
        writeByte(UInt8((value >> 8) & 0xFF))
        writeByte(UInt8(value & 0xFF))
    }

    public func writeSignedWord(_ value: Int16) {
        writeWord(UInt16(bitPattern: value))
    }

    public func writeDWord(_ value: UInt32) {
        writeWord(UInt16((value >> 16) & 0xFFFF))
        writeWord(UInt16(value & 0xFFFF))
    }

    public func writeBytes(_ data: Data) {
        for byte in data {
            writeByte(byte)
        }
    }

    public func writeString(_ string: String, encoding: String.Encoding = .ascii, nullTerminated: Bool = false) throws {
        guard let data = string.data(using: encoding) else {
            throw ByteStreamError.invalidEncoding
        }
        writeBytes(data)
        if nullTerminated {
            writeByte(0)
        }
    }

    // MARK: - Patch Methods (write at specific position without changing current position)

    public func patchByte(at position: Int, value: UInt8) throws {
        guard position < data.count else {
            throw ByteStreamError.invalidPosition
        }
        data[position] = value
    }

    public func patchWord(at position: Int, value: UInt16) throws {
        guard position + 1 < data.count else {
            throw ByteStreamError.invalidPosition
        }
        data[position] = UInt8((value >> 8) & 0xFF)
        data[position + 1] = UInt8(value & 0xFF)
    }

    public func patchDWord(at position: Int, value: UInt32) throws {
        try patchWord(at: position, value: UInt16((value >> 16) & 0xFFFF))
        try patchWord(at: position + 2, value: UInt16(value & 0xFFFF))
    }

    // MARK: - Alignment and Padding

    public func alignTo(_ boundary: Int) {
        let remainder = position % boundary
        if remainder != 0 {
            let padding = boundary - remainder
            // If we're at the end, pad with zeros; otherwise just seek
            if position >= data.count {
                for _ in 0..<padding {
                    writeByte(0)
                }
            } else {
                skip(bytes: padding)
            }
        }
    }

    public func padTo(_ boundary: Int, with value: UInt8 = 0) {
        let remainder = position % boundary
        if remainder != 0 {
            let padding = boundary - remainder
            for _ in 0..<padding {
                writeByte(value)
            }
        }
    }

    // MARK: - Data Access

    public func toData() -> Data {
        return data
    }

    public func getData(from start: Int, length: Int) throws -> Data {
        guard start >= 0 && start + length <= data.count else {
            throw ByteStreamError.invalidRange
        }
        return data.subdata(in: start..<start + length)
    }

    // MARK: - Checksum and Validation

    public func checksum(from start: Int = 0, to end: Int? = nil) -> UInt16 {
        let endPos = end ?? data.count
        guard start < endPos && start >= 0 && endPos <= data.count else {
            return 0
        }

        var sum: UInt32 = 0
        for i in start..<endPos {
            sum += UInt32(data[i])
        }
        return UInt16(sum & 0xFFFF)
    }

    public func xorChecksum(from start: Int = 0, to end: Int? = nil) -> UInt8 {
        let endPos = end ?? data.count
        guard start < endPos && start >= 0 && endPos <= data.count else {
            return 0
        }

        var xor: UInt8 = 0
        for i in start..<endPos {
            xor ^= data[i]
        }
        return xor
    }
}

// MARK: - ByteStream Errors

public enum ByteStreamError: Error, LocalizedError {
    case endOfStream
    case invalidPosition
    case invalidRange
    case invalidEncoding

    public var errorDescription: String? {
        switch self {
        case .endOfStream:
            return "Unexpected end of stream"
        case .invalidPosition:
            return "Invalid stream position"
        case .invalidRange:
            return "Invalid data range"
        case .invalidEncoding:
            return "Invalid string encoding"
        }
    }
}

// MARK: - Convenience Extensions

extension ByteStream {
    /// Read a variable-length integer (used in some Z-Machine formats)
    public func readVarInt() throws -> UInt32 {
        var result: UInt32 = 0
        var shift: UInt32 = 0

        while !isAtEnd {
            let byte = try readByte()
            result |= UInt32(byte & 0x7F) << shift

            if (byte & 0x80) == 0 {
                break
            }

            shift += 7
            if shift >= 32 {
                throw ByteStreamError.invalidRange
            }
        }

        return result
    }

    /// Write a variable-length integer
    public func writeVarInt(_ value: UInt32) {
        var remaining = value

        while remaining > 0x7F {
            writeByte(UInt8((remaining & 0x7F) | 0x80))
            remaining >>= 7
        }

        writeByte(UInt8(remaining & 0x7F))
    }

    /// Read a packed string (3 Z-characters per 2 bytes)
    public func readPackedString() throws -> [UInt16] {
        var characters: [UInt16] = []

        while !isAtEnd {
            let word = try readWord()
            characters.append(word)

            // Check for end-of-string marker (bit 15 set)
            if (word & 0x8000) != 0 {
                break
            }
        }

        return characters
    }
}