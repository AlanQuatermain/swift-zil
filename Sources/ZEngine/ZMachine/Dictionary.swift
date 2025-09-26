/// Z-Machine Dictionary - Manages the parser dictionary for word recognition
import Foundation

/// Manages the Z-Machine dictionary for parser word recognition
///
/// The dictionary contains all words that the parser can recognize,
/// encoded in a compressed format. It's used by the parser to convert
/// player input into tokens that the game logic can process.
public class Dictionary {

    /// Dictionary entries mapped by encoded word
    private var entries: [Data: DictionaryEntry] = [:]

    /// Word separators (characters that end words)
    private var separators: Set<UInt8> = []

    /// Entry length in bytes
    private var entryLength: UInt8 = 0

    /// Number of entries
    private var entryCount: UInt16 = 0

    public init() {}

    /// Load dictionary from Z-Machine memory
    ///
    /// - Parameters:
    ///   - data: Static memory data containing dictionary
    ///   - dictionaryAddress: Byte offset of dictionary within the provided data (not absolute story file address)
    /// - Throws: RuntimeError for corrupted dictionary
    public func load(from data: Data, dictionaryAddress: UInt32) throws {
        entries.removeAll()
        separators.removeAll()

        var offset = Int(dictionaryAddress)

        guard offset < data.count else {
            throw RuntimeError.corruptedStoryFile("Dictionary address out of range", location: SourceLocation.unknown)
        }

        // Load word separators
        let separatorCount = data[offset]
        offset += 1

        guard offset + Int(separatorCount) < data.count else {
            throw RuntimeError.corruptedStoryFile("Dictionary separators truncated", location: SourceLocation.unknown)
        }

        for i in 0..<Int(separatorCount) {
            separators.insert(data[offset + i])
        }
        offset += Int(separatorCount)

        // Load entry length and count
        guard offset + 3 < data.count else {
            throw RuntimeError.corruptedStoryFile("Dictionary header truncated", location: SourceLocation.unknown)
        }

        entryLength = data[offset]
        offset += 1

        entryCount = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
        offset += 2

        // Load dictionary entries
        let totalEntrySize = Int(entryCount) * Int(entryLength)
        guard offset + totalEntrySize <= data.count else {
            throw RuntimeError.corruptedStoryFile("Dictionary entries truncated", location: SourceLocation.unknown)
        }

        for i in 0..<Int(entryCount) {
            let entryOffset = offset + i * Int(entryLength)
            let entryData = data.subdata(in: entryOffset..<entryOffset + Int(entryLength))

            // First part is the encoded word (usually 4 or 6 bytes)
            let wordLength = min(Int(entryLength), 6) // Z-Machine words are at most 6 bytes
            let encodedWord = entryData.subdata(in: 0..<wordLength)

            let entry = DictionaryEntry(
                encodedWord: encodedWord,
                address: UInt16(entryOffset)
            )

            entries[encodedWord] = entry
        }
    }

    /// Look up a word in the dictionary
    ///
    /// - Parameter word: Word to look up (plain text)
    /// - Returns: Dictionary entry if found, nil otherwise
    public func lookup(_ word: String) -> DictionaryEntry? {
        let encodedWord = encodeWord(word)
        return entries[encodedWord]
    }

    /// Check if a character is a word separator
    ///
    /// - Parameter char: Character to check (as ASCII byte)
    /// - Returns: True if character is a separator
    public func isSeparator(_ char: UInt8) -> Bool {
        return separators.contains(char)
    }

    /// Get all dictionary entries (for debugging)
    ///
    /// - Returns: Array of all dictionary entries
    public func getAllEntries() -> [DictionaryEntry] {
        return Array(entries.values)
    }

    // MARK: - Word Encoding

    /// Encode a text word into Z-Machine dictionary format
    ///
    /// This implements the Z-Machine text encoding algorithm which
    /// converts ASCII text into a compressed 4 or 6-byte format.
    ///
    /// - Parameter word: Plain text word to encode
    /// - Returns: Encoded word data
    private func encodeWord(_ word: String) -> Data {
        // Convert to lowercase for dictionary lookup
        let lowercaseWord = word.lowercased()

        // Z-Machine character encoding tables
        let alphabet0 = "abcdefghijklmnopqrstuvwxyz"
        let alphabet1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let alphabet2 = " \n0123456789.,!?_#'\"/\\-:()"

        var zchars: [UInt8] = []
        var currentAlphabet = 0

        for char in lowercaseWord {
            var found = false

            // Try alphabet 0 (lowercase letters)
            if let index = alphabet0.firstIndex(of: char) {
                let charIndex = alphabet0.distance(from: alphabet0.startIndex, to: index)
                if currentAlphabet != 0 {
                    zchars.append(4) // Shift to alphabet 0
                    currentAlphabet = 0
                }
                zchars.append(UInt8(charIndex + 6))
                found = true
            }
            // Try alphabet 1 (uppercase letters)
            else if let index = alphabet1.firstIndex(of: char) {
                let charIndex = alphabet1.distance(from: alphabet1.startIndex, to: index)
                if currentAlphabet != 1 {
                    zchars.append(5) // Shift to alphabet 1
                    currentAlphabet = 1
                }
                zchars.append(UInt8(charIndex + 6))
                found = true
            }
            // Try alphabet 2 (punctuation and numbers)
            else if let index = alphabet2.firstIndex(of: char) {
                let charIndex = alphabet2.distance(from: alphabet2.startIndex, to: index)
                if currentAlphabet != 2 {
                    zchars.append(5) // Temporary shift to alphabet 2
                    zchars.append(6) // Then alphabet 2 marker
                }
                zchars.append(UInt8(charIndex + 7))
                found = true
            }

            if !found {
                // Unknown character - use ZSCII escape sequence
                if let ascii = char.asciiValue {
                    zchars.append(5) // Escape sequence
                    zchars.append(6)
                    zchars.append(3) // ZSCII marker
                    zchars.append(ascii >> 5) // High 3 bits
                    zchars.append(ascii & 0x1F) // Low 5 bits
                }
            }

            // Maximum word length in Z-characters
            if zchars.count >= 9 {
                break
            }
        }

        // Pad to word boundary
        while zchars.count < 9 {
            zchars.append(5) // Padding character
        }

        // Pack into bytes (3 Z-chars per 2 bytes)
        var result = Data()
        for i in stride(from: 0, to: 9, by: 3) {
            let char1 = i < zchars.count ? zchars[i] : 5
            let char2 = i + 1 < zchars.count ? zchars[i + 1] : 5
            let char3 = i + 2 < zchars.count ? zchars[i + 2] : 5

            let word = (UInt16(char1) << 10) | (UInt16(char2) << 5) | UInt16(char3)

            // Set end bit on final word
            let finalWord = (i >= 6) ? word | 0x8000 : word

            result.append(UInt8((finalWord >> 8) & 0xFF))
            result.append(UInt8(finalWord & 0xFF))
        }

        // Return first 4 or 6 bytes depending on entry length
        let targetLength = min(Int(entryLength), 6)
        return result.prefix(targetLength)
    }
}

/// Dictionary entry representing a single word
public struct DictionaryEntry {
    /// Encoded word data (4 or 6 bytes)
    public let encodedWord: Data

    /// Address of this entry in the dictionary
    public let address: UInt16

    public init(encodedWord: Data, address: UInt16) {
        self.encodedWord = encodedWord
        self.address = address
    }

    /// Decode the word back to text (for debugging)
    ///
    /// - Returns: Approximate decoded text
    public func decodeWord() -> String {
        // This is a simplified decoder for debugging purposes
        // A complete implementation would fully reverse the encoding process
        var result = ""

        for i in stride(from: 0, to: encodedWord.count, by: 2) {
            guard i + 1 < encodedWord.count else { break }

            let word = (UInt16(encodedWord[i]) << 8) | UInt16(encodedWord[i + 1])
            let char1 = (word >> 10) & 0x1F
            let char2 = (word >> 5) & 0x1F
            let char3 = word & 0x1F

            // Simple alphabet 0 decoding
            let alphabet = "abcdefghijklmnopqrstuvwxyz"
            for char in [char1, char2, char3] {
                if char >= 6 && char <= 31 {
                    let index = Int(char - 6)
                    if index < alphabet.count {
                        let alphabetIndex = alphabet.index(alphabet.startIndex, offsetBy: index)
                        result.append(alphabet[alphabetIndex])
                    }
                }
            }

            // Stop at end bit
            if (word & 0x8000) != 0 {
                break
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}