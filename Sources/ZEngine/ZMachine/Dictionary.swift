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
    public private(set) var entryLength: UInt8 = 0

    /// Number of entries
    public private(set) var entryCount: UInt16 = 0

    /// Z-Machine version (affects word encoding length)
    private var version: ZMachineVersion = .v3

    /// Number of separators
    public var separatorCount: Int {
        return separators.count
    }

    public init() {}

    /// Load dictionary from Z-Machine memory
    ///
    /// - Parameters:
    ///   - data: Static memory data containing dictionary
    ///   - dictionaryAddress: Byte offset of dictionary within the provided data (not absolute story file address)
    ///   - absoluteDictionaryAddress: Absolute address of dictionary in story file
    ///   - version: Z-Machine version (affects word encoding length)
    /// - Throws: RuntimeError for corrupted dictionary
    public func load(from data: Data, dictionaryAddress: UInt32, absoluteDictionaryAddress: UInt32, version: ZMachineVersion) throws {
        entries.removeAll()
        separators.removeAll()

        // Store version for proper word encoding length
        self.version = version

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

        // Calculate the size of the dictionary header (separator count + separators + entry length + entry count)
        let dictionaryHeaderSize = 1 + Int(separatorCount) + 1 + 2

        for i in 0..<Int(entryCount) {
            let entryOffset = offset + i * Int(entryLength)
            let entryData = data.subdata(in: entryOffset..<entryOffset + Int(entryLength))

            // Encoded word length depends on Z-Machine version
            // v1-3: 4 bytes, v4+: 6 bytes (the rest is metadata/flags)
            let wordLength = version.rawValue >= 4 ? 6 : 4
            let encodedWord = entryData.subdata(in: 0..<wordLength)

            // Extract metadata bytes (everything after the encoded word)
            let metadataLength = Int(entryLength) - wordLength
            let metadata = metadataLength > 0 ? entryData.subdata(in: wordLength..<Int(entryLength)) : Data()

            // Calculate the correct absolute address of this dictionary entry
            // This is: dictionary base address + header size + (entry index * entry length)
            let entryAddress = absoluteDictionaryAddress + UInt32(dictionaryHeaderSize) + UInt32(i * Int(entryLength))

            let entry = DictionaryEntry(
                encodedWord: encodedWord,
                address: UInt32(entryAddress),
                metadata: metadata
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

        if let entry = entries[encodedWord] {
            return entry
        } else {
            // Look for entries that decode to this word
            for (_, entry) in entries {
                let decoded = entry.decodeWord()
                if decoded == word.lowercased() {
                    return entry
                }
            }
        }

        return nil
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
        return Array(entries.values).sorted { $0.address < $1.address }
    }

    /// Get dictionary entry at specific index
    ///
    /// - Parameter index: Index in sorted order
    /// - Returns: Dictionary entry or nil if index out of bounds
    public func getEntry(at index: Int) -> DictionaryEntry? {
        let allEntries = getAllEntries()
        guard index >= 0 && index < allEntries.count else { return nil }
        return allEntries[index]
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
        let targetLength = version.rawValue >= 4 ? 6 : 4
        let totalWords = targetLength / 2  // Number of words we need to generate

        for i in stride(from: 0, to: totalWords * 3, by: 3) {
            let char1 = i < zchars.count ? zchars[i] : 5
            let char2 = i + 1 < zchars.count ? zchars[i + 1] : 5
            let char3 = i + 2 < zchars.count ? zchars[i + 2] : 5

            let word = (UInt16(char1) << 10) | (UInt16(char2) << 5) | UInt16(char3)

            // Set end bit on the LAST word of the generated bytes
            let isLastWord = (i / 3) == (totalWords - 1)
            let finalWord = isLastWord ? word | 0x8000 : word

            result.append(UInt8((finalWord >> 8) & 0xFF))
            result.append(UInt8(finalWord & 0xFF))
        }

        return result
    }
}

/// Dictionary entry representing a single word
public struct DictionaryEntry {
    /// Encoded word data (4 or 6 bytes)
    public let encodedWord: Data

    /// Address of this entry in the dictionary
    public let address: UInt32

    /// Metadata bytes (grammar flags, part of speech, etc.)
    public let metadata: Data

    public init(encodedWord: Data, address: UInt32, metadata: Data = Data()) {
        self.encodedWord = encodedWord
        self.address = address
        self.metadata = metadata
    }

    /// Decode the word back to text (for debugging)
    ///
    /// - Returns: Decoded text from Z-Machine encoded dictionary entry
    public func decodeWord() -> String {
        var result = ""
        var currentAlphabet = 0

        // Character sets for Z-Machine text
        let alphabet0 = "abcdefghijklmnopqrstuvwxyz"
        let alphabet1 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let alphabet2 = "\n0123456789.,!?_#'\"/\\<-:()"  // Z-char 7 starts at index 0

        // Extract Z-characters from encoded word
        var zchars: [UInt8] = []
        for i in stride(from: 0, to: encodedWord.count, by: 2) {
            guard i + 1 < encodedWord.count else { break }

            let word = (UInt16(encodedWord[i]) << 8) | UInt16(encodedWord[i + 1])
            let char1 = UInt8((word >> 10) & 0x1F)
            let char2 = UInt8((word >> 5) & 0x1F)
            let char3 = UInt8(word & 0x1F)

            zchars.append(char1)
            zchars.append(char2)
            zchars.append(char3)

            // Stop at end bit
            if (word & 0x8000) != 0 {
                break
            }
        }

        // Decode Z-characters to text
        var i = 0
        while i < zchars.count {
            let zchar = zchars[i]

            if zchar == 0 {
                // Null character - space
                result += " "
            } else if zchar <= 3 {
                // Abbreviations - skip for dictionary words (they shouldn't contain them)
                result += "?"
                if i + 1 < zchars.count {
                    i += 1  // Skip abbreviation number
                }
            } else if zchar == 4 {
                // Shift to alphabet 1
                currentAlphabet = 1
            } else if zchar == 5 {
                // Shift to alphabet 2, or ZSCII escape
                if i + 1 < zchars.count && zchars[i + 1] == 6 {
                    // ZSCII escape sequence
                    if i + 2 < zchars.count {
                        let high = zchars[i + 2]
                        let low = i + 3 < zchars.count ? zchars[i + 3] : 0
                        let zsciiValue = (high << 5) | low

                        // Convert ZSCII to character
                        if let scalar = UnicodeScalar(Int(zsciiValue)) {
                            result += String(Character(scalar))
                        }

                        i += 3 // Skip escape sequence
                        continue
                    }
                } else {
                    currentAlphabet = 2
                }
            } else if zchar >= 6 && zchar <= 31 {
                // Regular character (6-31)
                let charIndex = Int(zchar - 6)

                switch currentAlphabet {
                case 0:
                    if charIndex < alphabet0.count {
                        let alphabetIndex = alphabet0.index(alphabet0.startIndex, offsetBy: charIndex)
                        result += String(alphabet0[alphabetIndex])
                    }
                case 1:
                    if charIndex < alphabet1.count {
                        let alphabetIndex = alphabet1.index(alphabet1.startIndex, offsetBy: charIndex)
                        result += String(alphabet1[alphabetIndex])
                    }
                case 2:
                    let charIndex = Int(zchar - 7)  // A2 starts at Z-char 7
                    if charIndex >= 0 && charIndex < alphabet2.count {
                        let alphabetIndex = alphabet2.index(alphabet2.startIndex, offsetBy: charIndex)
                        result += String(alphabet2[alphabetIndex])
                    }
                default:
                    break
                }

                // Reset to alphabet 0 after one character (except for shift 4)
                if currentAlphabet == 2 {
                    currentAlphabet = 0
                }
            }

            i += 1
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
