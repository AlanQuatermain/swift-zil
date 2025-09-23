import Testing
@testable import ZEngine

@Suite("ByteStream Tests")
struct ByteStreamTests {

    @Suite("Basic Read/Write Tests")
    struct BasicReadWriteTests {

        @Test("Byte read/write operations")
        func byteReadWrite() throws {
            let stream = ByteStream()

            // Write test data
            stream.writeByte(0x42)
            stream.writeSignedByte(-1)
            stream.writeByte(0xFF)

            // Reset position and read back
            stream.rewind()

            let byte1 = try stream.readByte()
            let byte2 = try stream.readSignedByte()
            let byte3 = try stream.readByte()

            #expect(byte1 == 0x42)
            #expect(byte2 == -1)
            #expect(byte3 == 0xFF)
        }

        @Test("Word read/write operations")
        func wordReadWrite() throws {
            let stream = ByteStream()

            // Write test data (big-endian)
            stream.writeWord(0x1234)
            stream.writeSignedWord(-1)
            stream.writeWord(0xFFFF)

            // Reset and read back
            stream.rewind()

            let word1 = try stream.readWord()
            let word2 = try stream.readSignedWord()
            let word3 = try stream.readWord()

            #expect(word1 == 0x1234)
            #expect(word2 == -1)
            #expect(word3 == 0xFFFF)
        }

        @Test("DWord read/write operations")
        func dwordReadWrite() throws {
            let stream = ByteStream()

            // Write test data
            stream.writeDWord(0x12345678)
            stream.writeDWord(0xFFFFFFFF)

            // Reset and read back
            stream.rewind()

            let dword1 = try stream.readDWord()
            let dword2 = try stream.readDWord()

            #expect(dword1 == 0x12345678)
            #expect(dword2 == 0xFFFFFFFF)
        }
    }

    @Suite("String Operations")
    struct StringOperations {

        @Test("Fixed-length string operations")
        func fixedLengthStrings() throws {
            let stream = ByteStream()
            let testString = "Hello"

            try stream.writeString(testString)
            stream.rewind()

            let readString = try stream.readString(length: 5)
            #expect(readString == testString)
        }

        @Test("Null-terminated string operations")
        func nullTerminatedStrings() throws {
            let stream = ByteStream()
            let testString = "Hello World"

            try stream.writeString(testString, nullTerminated: true)
            stream.rewind()

            let readString = try stream.readNullTerminatedString()
            #expect(readString == testString)
        }
    }

    @Suite("Position Management")
    struct PositionManagement {

        @Test("Position tracking and seeking")
        func positionTrackingAndSeeking() throws {
            let stream = ByteStream()

            // Write some data
            for i in 0..<10 {
                stream.writeByte(UInt8(i))
            }

            #expect(stream.currentPosition == 10)
            #expect(stream.length == 10)
            #expect(stream.isAtEnd)

            // Test seeking
            stream.seek(to: 5)
            #expect(stream.currentPosition == 5)

            let byte = try stream.readByte()
            #expect(byte == 5)
            #expect(stream.currentPosition == 6)

            // Test skip
            stream.skip(bytes: 2)
            #expect(stream.currentPosition == 8)

            // Test rewind
            stream.rewind()
            #expect(stream.currentPosition == 0)
        }

        @Test("End of stream detection")
        func endOfStreamDetection() throws {
            let stream = ByteStream()
            stream.writeByte(0x42)
            stream.rewind()

            #expect(!stream.isAtEnd)
            _ = try stream.readByte()
            #expect(stream.isAtEnd)

            // Should throw on reading past end
            do {
                _ = try stream.readByte()
                #expect(Bool(false), "Should have thrown end of stream error")
            } catch ByteStreamError.endOfStream {
                // Expected
            } catch {
                #expect(Bool(false), "Wrong error type thrown")
            }
        }
    }

    @Suite("Peek Operations")
    struct PeekOperations {

        @Test("Peek without advancing position")
        func peekWithoutAdvancing() throws {
            let stream = ByteStream()
            stream.writeWord(0x1234)
            stream.writeByte(0x56)
            stream.rewind()

            let initialPosition = stream.currentPosition

            // Peek operations shouldn't change position
            let peekedByte = try stream.peekByte()
            #expect(stream.currentPosition == initialPosition)
            #expect(peekedByte == 0x12)

            let peekedWord = try stream.peekWord()
            #expect(stream.currentPosition == initialPosition)
            #expect(peekedWord == 0x1234)

            // Peek with offset
            let peekedByteOffset = try stream.peekByte(at: 2)
            #expect(peekedByteOffset == 0x56)
            #expect(stream.currentPosition == initialPosition)
        }
    }

    @Suite("Patch Operations")
    struct PatchOperations {

        @Test("Patching without changing position")
        func patchingWithoutChangingPosition() throws {
            let stream = ByteStream()

            // Write initial data
            stream.writeWord(0x0000)
            stream.writeWord(0x0000)
            let finalPosition = stream.currentPosition

            // Patch values
            try stream.patchByte(at: 0, value: 0x12)
            try stream.patchWord(at: 1, value: 0x3456)

            #expect(stream.currentPosition == finalPosition)

            // Verify patches
            stream.rewind()
            let byte1 = try stream.readByte()
            let word1 = try stream.readWord()
            let byte2 = try stream.readByte()

            #expect(byte1 == 0x12)
            #expect(word1 == 0x3456)
            #expect(byte2 == 0x00)
        }
    }

    @Suite("Checksum Operations")
    struct ChecksumOperations {

        @Test("Simple checksum calculation")
        func simpleChecksumCalculation() {
            let stream = ByteStream()

            // Write test data: 1, 2, 3, 4
            for i in 1...4 {
                stream.writeByte(UInt8(i))
            }

            let checksum = stream.checksum()
            #expect(checksum == 10) // 1 + 2 + 3 + 4 = 10

            let xorChecksum = stream.xorChecksum()
            #expect(xorChecksum == 4) // 1 ^ 2 ^ 3 ^ 4 = 4
        }

        @Test("Partial checksum calculation")
        func partialChecksumCalculation() {
            let stream = ByteStream()

            // Write test data: 10, 20, 30, 40
            for i in 1...4 {
                stream.writeByte(UInt8(i * 10))
            }

            // Checksum of bytes 1-2 (20 + 30 = 50)
            let partialChecksum = stream.checksum(from: 1, to: 3)
            #expect(partialChecksum == 50)
        }
    }

    @Suite("Variable Integer Operations")
    struct VariableIntegerOperations {

        @Test("Variable integer encoding/decoding", arguments: [
            0, 127, 128, 255, 256, 16383, 16384, 65535, 65536
        ])
        func variableIntegerEncodingDecoding(value: UInt32) throws {
            let stream = ByteStream()

            stream.writeVarInt(value)
            stream.rewind()

            let decoded = try stream.readVarInt()
            #expect(decoded == value)
        }
    }

    @Suite("Alignment and Padding")
    struct AlignmentAndPadding {

        @Test("Alignment operations")
        func alignmentOperations() {
            let stream = ByteStream()

            // Write 5 bytes
            for i in 0..<5 {
                stream.writeByte(UInt8(i))
            }

            #expect(stream.currentPosition == 5)

            // Align to 4-byte boundary (should skip 3 bytes to position 8)
            stream.alignTo(4)
            #expect(stream.currentPosition == 8)

            // Already aligned, should not move
            stream.alignTo(4)
            #expect(stream.currentPosition == 8)
        }

        @Test("Padding operations")
        func paddingOperations() throws {
            let stream = ByteStream()

            // Write 3 bytes
            for i in 0..<3 {
                stream.writeByte(UInt8(i))
            }

            // Pad to 8-byte boundary with 0xFF
            stream.padTo(8, with: 0xFF)

            // Should now be at position 8
            #expect(stream.currentPosition == 8)

            // Check that padding bytes were written
            stream.seek(to: 3)
            for i in 3..<8 {
                let byte = try stream.readByte()
                #expect(byte == 0xFF, "Padding byte at position \(i) should be 0xFF")
            }
        }
    }

    @Suite("Data Range Operations")
    struct DataRangeOperations {

        @Test("Getting data ranges")
        func gettingDataRanges() throws {
            let stream = ByteStream()

            // Write test pattern
            for i in 0..<10 {
                stream.writeByte(UInt8(i))
            }

            // Get a subrange
            let subdata = try stream.getData(from: 2, length: 4)
            #expect(subdata.count == 4)
            #expect(subdata[0] == 2)
            #expect(subdata[1] == 3)
            #expect(subdata[2] == 4)
            #expect(subdata[3] == 5)
        }

        @Test("Invalid range handling")
        func invalidRangeHandling() throws {
            let stream = ByteStream()
            stream.writeByte(0x42)

            // Should throw on invalid range
            do {
                _ = try stream.getData(from: 0, length: 5)
                #expect(Bool(false), "Should have thrown invalid range error")
            } catch ByteStreamError.invalidRange {
                // Expected
            } catch {
                #expect(Bool(false), "Wrong error type thrown")
            }
        }
    }
}