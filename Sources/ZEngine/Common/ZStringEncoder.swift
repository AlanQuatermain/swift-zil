/// ZStringEncoder: Complete ZSCII text compression for Z-Machine
///
/// Implements full Z-Machine text encoding including:
/// - Three alphabet tables (A0: lowercase, A1: uppercase, A2: punctuation)
/// - Shift codes for alphabet switching
/// - 10-bit ZSCII encoding for arbitrary characters
/// - Word packing (3 Z-characters per 16-bit word)
/// - End-bit marking on final word
/// - Abbreviation support (placeholders for future)
///
/// Reference: Z-Machine Standards Document §3

import Foundation

/// Encodes strings to Z-Machine compressed text format
public struct ZStringEncoder {

    // MARK: - Properties

    /// Z-Machine version (affects alphabet and encoding rules)
    private let version: Int

    // MARK: - Alphabet Tables

    /// Alphabet A0 (default): lowercase letters + space
    /// Z-chars 0-5 are special, 6-31 are alphabet characters
    private static let alphabetA0: [Character] = Array(" \u{0000}\u{0000}\u{0000}\u{0000}\u{0000}abcdefghijklmnopqrstuvwxyz")

    /// Alphabet A1: uppercase letters
    /// Accessed via shift code 4
    private static let alphabetA1: [Character] = Array(" \u{0000}\u{0000}\u{0000}\u{0000}\u{0000}ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    /// Alphabet A2: punctuation and symbols
    /// Accessed via shift code 5
    /// Position 6 is RESERVED for 10-bit ZSCII escape marker
    /// Positions 7-31: newline, numbers 0-9, punctuation
    private static let alphabetA2: [Character] = Array(" \u{0000}\u{0000}\u{0000}\u{0000}\u{0000}\u{0000}\n0123456789.,!?_#'\"/\\-:()")

    // MARK: - Initialization

    /// Initialize encoder for a specific Z-Machine version
    /// - Parameter version: Z-Machine version (3, 4, 5, 6, or 8)
    public init(version: Int) {
        self.version = version
    }

    // MARK: - Public Encoding API

    /// Encode a string to Z-character words (packed format)
    /// - Parameter text: The string to encode
    /// - Returns: Array of 16-bit words with end-bit set on last word
    public func encode(_ text: String) -> [UInt16] {
        let zchars = convertToZCharacters(text)
        return packIntoWords(zchars)
    }

    /// Encode a string and return as bytes with length prefix
    /// - Parameter text: The string to encode
    /// - Returns: Byte array: [length_in_words, word1_hi, word1_lo, word2_hi, word2_lo, ...]
    /// - Note: Length byte is number of 16-bit words, not total bytes
    public func encodeWithLengthPrefix(_ text: String) -> [UInt8] {
        let words = encode(text)
        var bytes: [UInt8] = []

        // Length prefix: number of 16-bit words
        bytes.append(UInt8(words.count))

        // Encode each word as big-endian bytes
        for word in words {
            bytes.append(UInt8((word >> 8) & 0xFF))  // High byte
            bytes.append(UInt8(word & 0xFF))         // Low byte
        }

        return bytes
    }

    /// Encode a string and return as raw bytes (no length prefix)
    /// - Parameter text: The string to encode
    /// - Returns: Byte array of packed words
    public func encodeAsBytes(_ text: String) -> [UInt8] {
        let words = encode(text)
        var bytes: [UInt8] = []

        for word in words {
            bytes.append(UInt8((word >> 8) & 0xFF))
            bytes.append(UInt8(word & 0xFF))
        }

        return bytes
    }

    // MARK: - Character to Z-Character Conversion

    /// Convert a string to Z-characters (5-bit values)
    /// - Parameter text: The string to convert
    /// - Returns: Array of Z-characters (values 0-31)
    private func convertToZCharacters(_ text: String) -> [UInt8] {
        var zchars: [UInt8] = []

        for char in text {
            // CRITICAL: Space is ALWAYS Z-char 0 (never search alphabets)
            if char == " " {
                zchars.append(0)
                continue
            }

            // Try to find character in alphabet A0 (lowercase)
            if let index = Self.alphabetA0.firstIndex(of: char), index >= 6 {
                zchars.append(UInt8(index))
                continue
            }

            // Try alphabet A1 (uppercase) - requires shift code 4
            if let index = Self.alphabetA1.firstIndex(of: char), index >= 6 {
                zchars.append(4)  // Shift to A1
                zchars.append(UInt8(index))
                continue
            }

            // Try alphabet A2 (punctuation) - requires shift code 5
            // CRITICAL: Position 6 is reserved, so check index >= 7
            if let index = Self.alphabetA2.firstIndex(of: char), index >= 7 {
                zchars.append(5)  // Shift to A2
                zchars.append(UInt8(index))
                continue
            }

            // Character not in any alphabet - use 10-bit ZSCII encoding
            // Format: [shift code 5] [6] [high 5 bits] [low 5 bits]
            if let zsciiCode = char.asciiValue {
                zchars.append(5)  // Shift to A2
                zchars.append(6)  // Z-char 6 in A2 signals 10-bit ZSCII
                zchars.append(UInt8(zsciiCode >> 5))    // Top 5 bits
                zchars.append(UInt8(zsciiCode & 0x1F))  // Bottom 5 bits
            } else {
                // Non-ASCII character - encode as '?' (ZSCII 63)
                zchars.append(5)  // Shift to A2
                zchars.append(6)  // 10-bit ZSCII
                zchars.append(1)  // 63 >> 5 = 1
                zchars.append(31) // 63 & 0x1F = 31
            }
        }

        return zchars
    }

    /// Pack Z-characters into 16-bit words (3 Z-chars per word)
    /// - Parameter zchars: Array of Z-characters (5-bit values)
    /// - Returns: Array of 16-bit words with end-bit set on last word
    private func packIntoWords(_ zchars: [UInt8]) -> [UInt16] {
        var words: [UInt16] = []
        var i = 0

        while i < zchars.count {
            var word: UInt16 = 0

            // Pack 3 Z-characters into one word
            // Bit layout: [end_bit][z1:5][z2:5][z3:5]
            for shift in [10, 5, 0] {
                if i < zchars.count {
                    let zchar = zchars[i] & 0x1F  // Ensure 5-bit value
                    word |= UInt16(zchar) << shift
                    i += 1
                } else {
                    // Pad with Z-char 5 (padding character)
                    word |= UInt16(5) << shift
                }
            }

            words.append(word)
        }

        // Handle empty string
        if words.isEmpty {
            // Empty string: single word with padding and end-bit
            words.append(0x8000 | (5 << 10) | (5 << 5) | 5)
        } else {
            // Set end-bit (bit 15) on last word
            words[words.count - 1] |= 0x8000
        }

        return words
    }

    // MARK: - Decoding Support (for testing/debugging)

    /// Decode Z-character words back to a string
    /// - Parameter words: Array of packed 16-bit words
    /// - Returns: Decoded string
    /// - Note: This is primarily for testing and debugging
    public func decode(_ words: [UInt16]) -> String {
        var result = ""
        var currentAlphabet = 0  // 0=A0, 1=A1, 2=A2
        var shiftNext = false
        var zsciiMode = false
        var zsciiBits: UInt16 = 0

        for word in words {
            // Extract 3 Z-characters from word
            let z1 = UInt8((word >> 10) & 0x1F)
            let z2 = UInt8((word >> 5) & 0x1F)
            let z3 = UInt8(word & 0x1F)

            for zchar in [z1, z2, z3] {
                // Handle 10-bit ZSCII mode
                if zsciiMode {
                    if zsciiBits == 0 {
                        // First Z-char: top 5 bits
                        zsciiBits = UInt16(zchar) << 5
                    } else {
                        // Second Z-char: bottom 5 bits
                        let fullCode = zsciiBits | UInt16(zchar)
                        if fullCode >= 32 && fullCode <= 126 {
                            result.append(Character(UnicodeScalar(UInt8(fullCode))))
                        } else {
                            result.append("?")
                        }
                        zsciiMode = false
                        zsciiBits = 0
                        // Reset alphabet after 10-bit ZSCII
                        currentAlphabet = 0
                        shiftNext = false
                    }
                    continue
                }

                // Handle shift codes and special Z-characters
                switch zchar {
                case 0:
                    result.append(" ")
                    // Don't reset shift state for space
                case 1:
                    // Abbreviation (not implemented - placeholder)
                    result.append("?")
                    // Don't reset shift state
                case 2, 3:
                    // Abbreviations (not implemented)
                    result.append("?")
                    // Don't reset shift state
                case 4:
                    // Shift to A1 (uppercase) for next character only
                    shiftNext = true
                    currentAlphabet = 1
                    continue  // Don't output anything, don't reset
                case 5:
                    // Shift to A2 (punctuation) for next character only
                    shiftNext = true
                    currentAlphabet = 2
                    continue  // Don't output anything, don't reset
                case 6:
                    // In A2, Z-char 6 signals 10-bit ZSCII
                    if currentAlphabet == 2 {
                        zsciiMode = true
                        zsciiBits = 0
                        // Keep shift state for ZSCII processing
                        continue
                    } else {
                        result.append(getCharFromAlphabet(currentAlphabet, Int(zchar)))
                    }
                default:
                    result.append(getCharFromAlphabet(currentAlphabet, Int(zchar)))
                }

                // Reset alphabet after shift (only if we actually output a character)
                if shiftNext {
                    currentAlphabet = 0
                    shiftNext = false
                }
            }

            // Check for end-bit
            if (word & 0x8000) != 0 {
                break
            }
        }

        return result
    }

    /// Get character from alphabet table
    private func getCharFromAlphabet(_ alphabet: Int, _ index: Int) -> Character {
        guard index >= 0 && index < 32 else { return "?" }

        switch alphabet {
        case 0:
            return Self.alphabetA0[index]
        case 1:
            return Self.alphabetA1[index]
        case 2:
            return Self.alphabetA2[index]
        default:
            return "?"
        }
    }

    // MARK: - Dictionary Encoding

    /// Encode a word for dictionary storage
    /// Dictionary words have fixed length and truncation rules
    /// - Parameters:
    ///   - word: The word to encode
    ///   - maxLength: Maximum number of Z-characters (4 for v3, 6 for v4+, 9 for v5+)
    /// - Returns: Fixed-length array of 16-bit words
    public func encodeDictionaryWord(_ word: String, maxLength: Int) -> [UInt16] {
        // Convert to lowercase for dictionary matching
        let normalized = word.lowercased()
        let zchars = convertToZCharacters(normalized)

        // Truncate or pad to exact length
        var truncated = Array(zchars.prefix(maxLength))
        while truncated.count < maxLength {
            truncated.append(5)  // Pad with Z-char 5
        }

        // Pack into words
        let words = packIntoWords(truncated)

        // Set end-bit on last word
        var finalWords = words
        if !finalWords.isEmpty {
            let lastIndex = finalWords.count - 1
            finalWords[lastIndex] |= 0x8000
        }

        return finalWords
    }
}
