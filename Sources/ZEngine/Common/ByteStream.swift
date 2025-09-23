import Foundation

/// A versatile byte stream reader and writer for binary data processing.
///
/// `ByteStream` provides comprehensive functionality for reading from and writing to
/// binary data streams. It maintains a current position within the stream and supports
/// both sequential and random access operations.
///
/// ## Features
/// - Sequential reading and writing of various data types
/// - Position management with seeking and alignment
/// - Peek operations that don't advance the position
/// - In-place patching of previously written data
/// - Checksum calculation and validation
/// - Support for packed strings and variable-length integers
///
/// ## Usage Example
/// ```swift
/// let stream = ByteStream()
/// stream.writeWord(0x1234)
/// stream.writeByte(0x56)
///
/// stream.rewind()
/// let word = try stream.readWord()  // 0x1234
/// let byte = try stream.readByte()  // 0x56
/// ```
///
/// ## Thread Safety
/// This class is not thread-safe. Use appropriate synchronization if accessing
/// from multiple threads.
public class ByteStream {
    /// The underlying data storage
    private var data: Data
    /// Current read/write position within the stream
    private var position: Int

    /// Creates a new byte stream with optional initial data.
    ///
    /// - Parameter data: Initial data for the stream (default: empty)
    public init(_ data: Data = Data()) {
        self.data = data
        self.position = 0
    }

    /// Creates a new byte stream with a specified initial capacity.
    ///
    /// This can improve performance when the approximate final size is known.
    ///
    /// - Parameter capacity: Initial capacity for the underlying data storage
    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
        self.position = 0
    }

    // MARK: - Position Management

    /// The current read/write position within the stream
    public var currentPosition: Int {
        return position
    }

    /// The total length of data in the stream
    public var length: Int {
        return data.count
    }

    /// Indicates whether the current position is at or beyond the end of the stream
    public var isAtEnd: Bool {
        return position >= data.count
    }

    /// The number of bytes remaining from the current position to the end
    public var remainingBytes: Int {
        return max(0, data.count - position)
    }

    /// Moves the current position to the specified location.
    ///
    /// The position is clamped to the valid range [0, length].
    ///
    /// - Parameter position: The target position
    public func seek(to position: Int) {
        self.position = min(max(0, position), data.count)
    }

    /// Advances the current position by the specified number of bytes.
    ///
    /// The position is clamped to not exceed the stream length.
    ///
    /// - Parameter bytes: Number of bytes to advance
    public func skip(bytes: Int) {
        position = min(position + bytes, data.count)
    }

    /// Resets the current position to the beginning of the stream
    public func rewind() {
        position = 0
    }

    // MARK: - Reading Methods

    /// Reads a single unsigned byte from the stream.
    ///
    /// - Returns: The byte value (0-255)
    /// - Throws: `ByteStreamError.endOfStream` if at end of stream
    public func readByte() throws -> UInt8 {
        guard position < data.count else {
            throw ByteStreamError.endOfStream
        }
        let byte = data[position]
        position += 1
        return byte
    }

    /// Reads a single signed byte from the stream.
    ///
    /// - Returns: The signed byte value (-128 to 127)
    /// - Throws: `ByteStreamError.endOfStream` if at end of stream
    public func readSignedByte() throws -> Int8 {
        let byte = try readByte()
        return Int8(bitPattern: byte)
    }

    /// Reads a 16-bit unsigned word from the stream in big-endian format.
    ///
    /// - Returns: The word value (0-65535)
    /// - Throws: `ByteStreamError.endOfStream` if insufficient data
    public func readWord() throws -> UInt16 {
        let high = try readByte()
        let low = try readByte()
        return UInt16(high) << 8 | UInt16(low)
    }

    /// Reads a 16-bit signed word from the stream in big-endian format.
    ///
    /// - Returns: The signed word value (-32768 to 32767)
    /// - Throws: `ByteStreamError.endOfStream` if insufficient data
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

    /// Writes a single unsigned byte to the stream.
    ///
    /// If writing at the end of the stream, the data is appended.
    /// If writing within existing data, the byte is overwritten.
    ///
    /// - Parameter value: The byte value to write (0-255)
    public func writeByte(_ value: UInt8) {
        if position >= data.count {
            data.append(value)
        } else {
            data[position] = value
        }
        position += 1
    }

    /// Writes a single signed byte to the stream.
    ///
    /// - Parameter value: The signed byte value to write (-128 to 127)
    public func writeSignedByte(_ value: Int8) {
        writeByte(UInt8(bitPattern: value))
    }

    /// Writes a 16-bit unsigned word to the stream in big-endian format.
    ///
    /// - Parameter value: The word value to write (0-65535)
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

/// Errors that can occur during byte stream operations.
///
/// `ByteStreamError` represents various error conditions that can arise when
/// reading from or writing to a byte stream, including boundary violations,
/// invalid positions, and encoding problems.
public enum ByteStreamError: Error, LocalizedError {
    /// Attempted to read beyond the end of the stream
    case endOfStream

    /// Attempted to access an invalid position in the stream
    case invalidPosition

    /// Specified data range is invalid or out of bounds
    case invalidRange

    /// String encoding or decoding operation failed
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
    /// Reads a variable-length integer from the stream.
    ///
    /// Variable-length integers are encoded using LEB128 (Little Endian Base 128)
    /// format, where each byte contains 7 data bits and 1 continuation bit.
    /// This encoding is used in some Z-Machine formats for space efficiency.
    ///
    /// - Returns: The decoded variable-length integer value
    /// - Throws: `ByteStreamError.endOfStream` if the stream ends unexpectedly,
    ///           or `ByteStreamError.invalidRange` if the value is too large
    ///
    /// ## Encoding Format
    /// Each byte has the format: `CXXXXXXX` where:
    /// - `C` is the continuation bit (1 = more bytes follow, 0 = last byte)
    /// - `XXXXXXX` are the 7 data bits
    ///
    /// Example: Value 300 (0x012C) is encoded as: `0xAC 0x02`
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

    /// Writes a variable-length integer to the stream.
    ///
    /// Encodes the given value using LEB128 (Little Endian Base 128) format,
    /// where each byte contains 7 data bits and 1 continuation bit. This provides
    /// space-efficient encoding for small integers while supporting larger values.
    ///
    /// - Parameter value: The 32-bit unsigned integer to encode and write
    ///
    /// ## Encoding Process
    /// 1. Extract the lowest 7 bits from the value
    /// 2. If more bits remain, set the continuation bit (0x80)
    /// 3. Write the byte and shift the value right by 7 bits
    /// 4. Repeat until all bits are written
    ///
    /// Example: Value 300 (0x012C) produces bytes: `0xAC 0x02`
    public func writeVarInt(_ value: UInt32) {
        var remaining = value

        while remaining > 0x7F {
            writeByte(UInt8((remaining & 0x7F) | 0x80))
            remaining >>= 7
        }

        writeByte(UInt8(remaining & 0x7F))
    }

    /// Reads a packed string from the stream.
    ///
    /// Packed strings in the Z-Machine format store 3 Z-characters per 2 bytes (16-bit word).
    /// This method reads consecutive 16-bit words until it encounters the end-of-string
    /// marker (bit 15 set in the final word).
    ///
    /// - Returns: An array of 16-bit words representing the packed string data
    /// - Throws: `ByteStreamError.endOfStream` if the stream ends before the string terminator
    ///
    /// ## Z-Machine Packed String Format
    /// - Each 16-bit word contains 3 Z-characters (5 bits each + 1 padding bit)
    /// - The final word has bit 15 set to indicate end of string
    /// - Characters are encoded using the Z-Machine alphabet tables
    /// - Used for efficient storage of game text and object names
    ///
    /// Example: Reading "HELLO" might return `[0x1A5C, 0x9B40]` where the second
    /// word has bit 15 set (0x8000) to mark the end.
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