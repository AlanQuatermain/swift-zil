/// Tests for ZStringEncoder - Complete ZSCII text compression
///
/// These tests verify:
/// - Basic lowercase encoding (alphabet A0)
/// - Uppercase encoding with shift codes (alphabet A1)
/// - Punctuation encoding with shift codes (alphabet A2)
/// - 10-bit ZSCII encoding for arbitrary characters
/// - Word packing (3 Z-chars per 16-bit word)
/// - End-bit marking on final word
/// - Length prefix encoding
/// - Dictionary word encoding
/// - Round-trip encode/decode

import XCTest
@testable import ZEngine

final class ZStringEncoderTests: XCTestCase {

    // MARK: - Basic Encoding Tests

    func testEncodeLowercaseString() throws {
        let encoder = ZStringEncoder(version: 3)

        // "hello" = h(13) e(10) l(17) l(17) o(20)
        let words = encoder.encode("hello")

        // First word: h(13) e(10) l(17) - packed as 0b0 01101 01010 10001
        // Second word: l(17) o(20) pad(5) - packed as 0b1 10001 10100 00101 (end bit set)
        XCTAssertEqual(words.count, 2, "Should produce 2 words for 5 characters")

        // Verify first word packing (no end bit)
        let word1 = words[0]
        let z1_1 = UInt8((word1 >> 10) & 0x1F)
        let z1_2 = UInt8((word1 >> 5) & 0x1F)
        let z1_3 = UInt8(word1 & 0x1F)
        XCTAssertEqual(z1_1, 13, "First Z-char should be 'h' (13)")
        XCTAssertEqual(z1_2, 10, "Second Z-char should be 'e' (10)")
        XCTAssertEqual(z1_3, 17, "Third Z-char should be 'l' (17)")
        XCTAssertEqual((word1 & 0x8000), 0, "First word should not have end bit")

        // Verify second word packing (with end bit)
        let word2 = words[1]
        let z2_1 = UInt8((word2 >> 10) & 0x1F)
        let z2_2 = UInt8((word2 >> 5) & 0x1F)
        let z2_3 = UInt8(word2 & 0x1F)
        XCTAssertEqual(z2_1, 17, "First Z-char should be 'l' (17)")
        XCTAssertEqual(z2_2, 20, "Second Z-char should be 'o' (20)")
        XCTAssertEqual(z2_3, 5, "Third Z-char should be padding (5)")
        XCTAssertNotEqual((word2 & 0x8000), 0, "Second word should have end bit set")
    }

    func testEncodeEmptyString() throws {
        let encoder = ZStringEncoder(version: 3)
        let words = encoder.encode("")

        XCTAssertEqual(words.count, 1, "Empty string should produce 1 word")

        // Should be padding (5,5,5) with end bit
        let word = words[0]
        XCTAssertNotEqual((word & 0x8000), 0, "Should have end bit set")

        let z1 = UInt8((word >> 10) & 0x1F)
        let z2 = UInt8((word >> 5) & 0x1F)
        let z3 = UInt8(word & 0x1F)
        XCTAssertEqual(z1, 5, "Should be padding")
        XCTAssertEqual(z2, 5, "Should be padding")
        XCTAssertEqual(z3, 5, "Should be padding")
    }

    func testEncodeSpace() throws {
        let encoder = ZStringEncoder(version: 3)
        let words = encoder.encode(" ")

        XCTAssertEqual(words.count, 1, "Single space should produce 1 word")

        let word = words[0]
        let z1 = UInt8((word >> 10) & 0x1F)
        let z2 = UInt8((word >> 5) & 0x1F)
        let z3 = UInt8(word & 0x1F)
        XCTAssertEqual(z1, 0, "Space should be Z-char 0")
        XCTAssertEqual(z2, 5, "Padding should be Z-char 5")
        XCTAssertEqual(z3, 5, "Padding should be Z-char 5")
        XCTAssertNotEqual((word & 0x8000), 0, "Should have end bit")
    }

    // MARK: - Uppercase/Shift Tests

    func testEncodeUppercaseString() throws {
        let encoder = ZStringEncoder(version: 3)

        // "HI" requires shift codes: shift(4) H(13) shift(4) I(14)
        let words = encoder.encode("HI")

        // Should produce: [4, 13, 4] in first word, [14, 5, 5] in second word
        XCTAssertEqual(words.count, 2, "Should produce 2 words for 4 Z-chars + padding")

        let word1 = words[0]
        let z1_1 = UInt8((word1 >> 10) & 0x1F)
        let z1_2 = UInt8((word1 >> 5) & 0x1F)
        let z1_3 = UInt8(word1 & 0x1F)
        XCTAssertEqual(z1_1, 4, "Should be shift code to A1")
        XCTAssertEqual(z1_2, 13, "Should be 'H' (13 in A1)")
        XCTAssertEqual(z1_3, 4, "Should be shift code to A1")

        let word2 = words[1]
        let z2_1 = UInt8((word2 >> 10) & 0x1F)
        XCTAssertEqual(z2_1, 14, "Should be 'I' (14 in A1)")
        XCTAssertNotEqual((word2 & 0x8000), 0, "Second word should have end bit")
    }

    func testEncodeMixedCase() throws {
        let encoder = ZStringEncoder(version: 3)
        let words = encoder.encode("Hi")

        // "H" requires shift: [4, 13, 14, 5, 5, 5]
        // First word: shift(4) H(13) i(14)
        XCTAssertGreaterThanOrEqual(words.count, 1)

        let word1 = words[0]
        let z1_1 = UInt8((word1 >> 10) & 0x1F)
        let z1_2 = UInt8((word1 >> 5) & 0x1F)
        let z1_3 = UInt8(word1 & 0x1F)
        XCTAssertEqual(z1_1, 4, "Should be shift code")
        XCTAssertEqual(z1_2, 13, "Should be 'H'")
        XCTAssertEqual(z1_3, 14, "Should be 'i'")
    }

    // MARK: - Punctuation Tests

    func testEncodePunctuation() throws {
        let encoder = ZStringEncoder(version: 3)

        // "!" is in alphabet A2 at position 20 (A2: position 7=\n, 8='0'...17='9', 18='.', 19=',', 20='!')
        let words = encoder.encode("!")

        // Should be: [5, 20, 5] → 1 word (shift(5) !(20) pad(5))
        XCTAssertGreaterThanOrEqual(words.count, 1)

        let word1 = words[0]
        let z1_1 = UInt8((word1 >> 10) & 0x1F)
        let z1_2 = UInt8((word1 >> 5) & 0x1F)
        XCTAssertEqual(z1_1, 5, "Should be shift code to A2")
        XCTAssertEqual(z1_2, 20, "Should be '!' at position 20 in A2")
    }

    func testEncodeCommonPunctuation() throws {
        let encoder = ZStringEncoder(version: 3)

        // Test period, comma, question mark
        let periodWords = encoder.encode(".")
        XCTAssertGreaterThanOrEqual(periodWords.count, 1)

        let commaWords = encoder.encode(",")
        XCTAssertGreaterThanOrEqual(commaWords.count, 1)

        let questionWords = encoder.encode("?")
        XCTAssertGreaterThanOrEqual(questionWords.count, 1)
    }

    // MARK: - 10-bit ZSCII Tests

    func testEncode10BitZSCII() throws {
        let encoder = ZStringEncoder(version: 3)

        // '@' (ASCII 64) is not in any alphabet
        // Should encode as: shift(5) zscii(6) high(2) low(0)
        // Because 64 = 0b01000000 → high 5 bits = 2, low 5 bits = 0
        let words = encoder.encode("@")

        // Should produce 2 words: [5, 6, 2] [0, 5, 5]
        XCTAssertGreaterThanOrEqual(words.count, 1)

        let word1 = words[0]
        let z1_1 = UInt8((word1 >> 10) & 0x1F)
        let z1_2 = UInt8((word1 >> 5) & 0x1F)
        let z1_3 = UInt8(word1 & 0x1F)
        XCTAssertEqual(z1_1, 5, "Should be shift to A2")
        XCTAssertEqual(z1_2, 6, "Should be 10-bit ZSCII marker")
        XCTAssertEqual(z1_3, 2, "Should be high 5 bits of '@' (64)")

        if words.count > 1 {
            let word2 = words[1]
            let z2_1 = UInt8((word2 >> 10) & 0x1F)
            XCTAssertEqual(z2_1, 0, "Should be low 5 bits of '@' (64)")
        }
    }

    // MARK: - Length Prefix Tests

    func testEncodeWithLengthPrefix() throws {
        let encoder = ZStringEncoder(version: 3)
        let bytes = encoder.encodeWithLengthPrefix("hi")

        // "hi" = h(13) i(14) pad(5) → 1 word
        // Output: [length=1, word_hi, word_lo]
        XCTAssertEqual(bytes[0], 1, "Length should be 1 word")
        XCTAssertEqual(bytes.count, 3, "Should have 1 length byte + 2 word bytes")
    }

    func testEncodeWithLengthPrefixLongerString() throws {
        let encoder = ZStringEncoder(version: 3)
        let bytes = encoder.encodeWithLengthPrefix("hello world")

        // Should produce multiple words
        let wordCount = Int(bytes[0])
        XCTAssertGreaterThan(wordCount, 1, "Should produce multiple words")
        XCTAssertEqual(bytes.count, 1 + (wordCount * 2), "Should have correct byte count")
    }

    // MARK: - Raw Bytes Tests

    func testEncodeAsBytes() throws {
        let encoder = ZStringEncoder(version: 3)
        let bytes = encoder.encodeAsBytes("hi")

        // Should be 2 bytes (1 word)
        XCTAssertEqual(bytes.count, 2, "Should produce 2 bytes for 1 word")

        // Reconstruct word
        let word = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        XCTAssertNotEqual((word & 0x8000), 0, "Should have end bit set")
    }

    // MARK: - Round-Trip Tests

    func testRoundTripLowercase() throws {
        let encoder = ZStringEncoder(version: 3)
        let original = "hello"

        let words = encoder.encode(original)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, original, "Round-trip should preserve lowercase string")
    }

    func testRoundTripUppercase() throws {
        let encoder = ZStringEncoder(version: 3)
        let original = "HELLO"

        let words = encoder.encode(original)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, original, "Round-trip should preserve uppercase string")
    }

    func testRoundTripMixedCase() throws {
        let encoder = ZStringEncoder(version: 3)
        let original = "Hello World"

        let words = encoder.encode(original)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, original, "Round-trip should preserve mixed case")
    }

    func testRoundTripPunctuation() throws {
        let encoder = ZStringEncoder(version: 3)
        let original = "Hello, world!"

        let words = encoder.encode(original)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, original, "Round-trip should preserve punctuation")
    }

    func testRoundTripSpecialCharacters() throws {
        let encoder = ZStringEncoder(version: 3)
        let original = "test@example.com"

        let words = encoder.encode(original)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, original, "Round-trip should preserve special characters")
    }

    // MARK: - Dictionary Encoding Tests

    func testEncodeDictionaryWordV3() throws {
        let encoder = ZStringEncoder(version: 3)

        // v3 dictionary words are 4 Z-chars (truncated/padded)
        let words = encoder.encodeDictionaryWord("north", maxLength: 4)

        // 4 Z-chars pack into 2 words (3 chars first word, 1 char + padding second word)
        XCTAssertEqual(words.count, 2, "v3 dictionary word should produce 2 words")

        // Last word should have end bit
        let lastWord = words[words.count - 1]
        XCTAssertNotEqual((lastWord & 0x8000), 0, "Dictionary word should have end bit")
    }

    func testEncodeDictionaryWordV5() throws {
        let encoder = ZStringEncoder(version: 5)

        // v5 dictionary words are 6 Z-chars
        let words = encoder.encodeDictionaryWord("examine", maxLength: 6)

        // 6 Z-chars pack into 2 words exactly
        XCTAssertEqual(words.count, 2, "v5 dictionary word should produce 2 words")

        // Last word should have end bit
        let lastWord = words[words.count - 1]
        XCTAssertNotEqual((lastWord & 0x8000), 0, "Dictionary word should have end bit")
    }

    func testEncodeDictionaryWordTruncation() throws {
        let encoder = ZStringEncoder(version: 3)

        // v3 truncates to 4 Z-chars - "northwest" becomes "nort"
        let words1 = encoder.encodeDictionaryWord("northwest", maxLength: 4)
        let words2 = encoder.encodeDictionaryWord("north", maxLength: 4)

        // Should produce same encoding (both truncate/match to "nort")
        XCTAssertEqual(words1, words2, "Dictionary words should match when truncated identically")
    }

    func testEncodeDictionaryWordPadding() throws {
        let encoder = ZStringEncoder(version: 3)

        // Short word "go" should be padded to 4 Z-chars
        let words = encoder.encodeDictionaryWord("go", maxLength: 4)

        // Should produce valid encoding with padding
        XCTAssertEqual(words.count, 2)

        // Last word has end bit
        XCTAssertNotEqual((words[words.count - 1] & 0x8000), 0)
    }

    // MARK: - Version-Specific Tests

    func testEncoderVersion3() throws {
        let encoder = ZStringEncoder(version: 3)
        let words = encoder.encode("test")

        // Basic functionality check
        XCTAssertGreaterThanOrEqual(words.count, 1)
        XCTAssertNotEqual((words[words.count - 1] & 0x8000), 0, "Should have end bit")
    }

    func testEncoderVersion5() throws {
        let encoder = ZStringEncoder(version: 5)
        let words = encoder.encode("test")

        // Basic functionality check
        XCTAssertGreaterThanOrEqual(words.count, 1)
        XCTAssertNotEqual((words[words.count - 1] & 0x8000), 0, "Should have end bit")
    }

    // MARK: - Edge Cases

    func testEncodeLongString() throws {
        let encoder = ZStringEncoder(version: 3)
        let long = String(repeating: "a", count: 100)

        let words = encoder.encode(long)

        // Should produce many words (100 chars ÷ 3 per word ≈ 34 words)
        XCTAssertGreaterThan(words.count, 30)

        // Last word should have end bit
        XCTAssertNotEqual((words[words.count - 1] & 0x8000), 0)
    }

    func testEncodeAllLowercase() throws {
        let encoder = ZStringEncoder(version: 3)
        let alphabet = "abcdefghijklmnopqrstuvwxyz"

        let words = encoder.encode(alphabet)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, alphabet, "Should encode/decode full lowercase alphabet")
    }

    func testEncodeAllUppercase() throws {
        let encoder = ZStringEncoder(version: 3)
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        let words = encoder.encode(alphabet)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, alphabet, "Should encode/decode full uppercase alphabet")
    }

    func testEncodeNumbers() throws {
        let encoder = ZStringEncoder(version: 3)
        let numbers = "0123456789"

        let words = encoder.encode(numbers)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, numbers, "Should encode/decode numbers")
    }

    func testEncodeNewline() throws {
        let encoder = ZStringEncoder(version: 3)
        let text = "line1\nline2"

        let words = encoder.encode(text)
        let decoded = encoder.decode(words)

        XCTAssertEqual(decoded, text, "Should handle newline character")
    }
}
