/// Manages vocabulary and dictionary generation for Z-Machine parser
import Foundation

/// Word type classification for dictionary entries
public struct WordType: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Direction word (NORTH, SOUTH, etc.)
    public static let direction = WordType(rawValue: 1 << 0)
    /// Verb word
    public static let verb = WordType(rawValue: 1 << 1)
    /// Preposition (IN, ON, WITH, etc.)
    public static let preposition = WordType(rawValue: 1 << 2)
    /// Adjective
    public static let adjective = WordType(rawValue: 1 << 3)
    /// Noun/object word
    public static let noun = WordType(rawValue: 1 << 4)
    /// Buzzword (ignored by parser)
    public static let buzzword = WordType(rawValue: 1 << 5)
}

/// Vocabulary entry for a single word (for code generation)
public struct VocabularyEntry: Sendable, Equatable {
    /// The word in original form
    public let word: String
    /// Canonical form (after synonym resolution)
    public let canonical: String
    /// Word type flags
    public let type: WordType
    /// Verb number (if verb)
    public let verbNumber: UInt8?
    /// Z-character encoded form (6 bytes for v3, 9 for v4+)
    public let encoded: Data

    public init(word: String, canonical: String, type: WordType, verbNumber: UInt8? = nil, encoded: Data) {
        self.word = word
        self.canonical = canonical
        self.type = type
        self.verbNumber = verbNumber
        self.encoded = encoded
    }
}

/// Manages vocabulary collection and dictionary generation
public struct VocabularyManager: Sendable {

    // MARK: - Properties

    /// Z-Machine version (affects encoding)
    private let version: ZMachineVersion

    /// Synonym mappings: word -> canonical form
    private var synonyms: [String: String] = [:]

    /// Buzzwords (parser ignore list)
    private var buzzwords: Set<String> = []

    /// All words with their types
    private var wordTypes: [String: WordType] = [:]

    /// Verb number assignments: canonical verb -> number
    private var verbNumbers: [String: UInt8] = [:]

    /// Next available verb number
    private var nextVerbNumber: UInt8 = 1

    // MARK: - Initialization

    public init(version: ZMachineVersion = .v5) {
        self.version = version
    }

    // MARK: - Synonym Management

    /// Add synonym declaration
    public mutating func addSynonym(words: [String]) {
        guard let canonical = words.first else { return }

        for word in words {
            synonyms[word.uppercased()] = canonical.uppercased()
        }
    }

    /// Resolve word to canonical form
    public func resolveWord(_ word: String) -> String {
        let upper = word.uppercased()
        return synonyms[upper] ?? upper
    }

    // MARK: - Buzzword Management

    /// Add buzzword declaration
    public mutating func addBuzzwords(_ words: [String]) {
        for word in words {
            buzzwords.insert(word.uppercased())
            addWord(word, type: .buzzword)
        }
    }

    /// Check if word is a buzzword
    public func isBuzzword(_ word: String) -> Bool {
        return buzzwords.contains(word.uppercased())
    }

    // MARK: - Word Type Management

    /// Add a word with its type
    public mutating func addWord(_ word: String, type: WordType) {
        let canonical = resolveWord(word)

        if let existing = wordTypes[canonical] {
            // Merge types
            wordTypes[canonical] = WordType(rawValue: existing.rawValue | type.rawValue)
        } else {
            wordTypes[canonical] = type
        }
    }

    /// Add verb and assign verb number
    public mutating func addVerb(_ verb: String) -> UInt8 {
        let canonical = resolveWord(verb)

        // Check if already assigned
        if let existing = verbNumbers[canonical] {
            return existing
        }

        // Assign new verb number
        let verbNum = nextVerbNumber
        verbNumbers[canonical] = verbNum
        nextVerbNumber += 1

        // Add to word types
        addWord(canonical, type: .verb)

        return verbNum
    }

    /// Get verb number for a verb (if assigned)
    public func getVerbNumber(_ verb: String) -> UInt8? {
        let canonical = resolveWord(verb)
        return verbNumbers[canonical]
    }

    /// Get all verb constants for code generation
    public func getVerbConstants() -> [(String, UInt8)] {
        return verbNumbers.sorted { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - Dictionary Generation

    /// Generate complete dictionary for ZAP output
    public func generateDictionary() -> [VocabularyEntry] {
        var entries: [VocabularyEntry] = []

        // Create entry for each word
        for (canonical, type) in wordTypes {
            let encoded = encodeWord(canonical)
            let verbNum = type.contains(.verb) ? verbNumbers[canonical] : nil

            entries.append(VocabularyEntry(
                word: canonical,
                canonical: canonical,
                type: type,
                verbNumber: verbNum,
                encoded: encoded
            ))

            // Add all synonyms
            for (synonym, syn_canonical) in synonyms where syn_canonical == canonical {
                if synonym != canonical {
                    let synEncoded = encodeWord(synonym)
                    entries.append(VocabularyEntry(
                        word: synonym,
                        canonical: canonical,
                        type: type,
                        verbNumber: verbNum,
                        encoded: synEncoded
                    ))
                }
            }
        }

        // Sort alphabetically (required by Z-Machine)
        return entries.sorted { $0.word < $1.word }
    }

    // MARK: - Z-Character Encoding

    /// Encode word to Z-characters (5-bit packed format)
    private func encodeWord(_ word: String) -> Data {
        var zchars: [UInt8] = []
        let maxChars = version.rawValue >= 4 ? 9 : 6  // v4+ uses 9 chars, v3 uses 6

        // Convert to uppercase and process
        let upperWord = word.uppercased()

        for char in upperWord.prefix(maxChars) {
            if let zchar = charToZChar(char) {
                zchars.append(zchar)
            }
        }

        // Pad to required length
        while zchars.count < maxChars {
            zchars.append(5)  // Pad with shift character
        }

        // Pack into 16-bit words (3 z-chars per word)
        var data = Data()
        var index = 0
        while index < zchars.count {
            let z1 = index < zchars.count ? UInt16(zchars[index]) : 5
            let z2 = index + 1 < zchars.count ? UInt16(zchars[index + 1]) : 5
            let z3 = index + 2 < zchars.count ? UInt16(zchars[index + 2]) : 5

            // Pack: 5 bits each into 16-bit word, with end bit if last word
            let isLast = index + 3 >= zchars.count
            let word = (isLast ? 0x8000 : 0x0000) | (z1 << 10) | (z2 << 5) | z3

            data.append(UInt8((word >> 8) & 0xFF))
            data.append(UInt8(word & 0xFF))

            index += 3
        }

        return data
    }

    /// Convert character to Z-character value
    private func charToZChar(_ char: Character) -> UInt8? {
        let ascii = char.asciiValue ?? 0

        switch char {
        // Alphabet 0 (A0): lowercase a-z
        case "A"..."Z":
            return UInt8(ascii - 65 + 6)  // 'A' -> 6, 'B' -> 7, ..., 'Z' -> 31

        // Space
        case " ":
            return 0

        // Shift characters
        case "\n":
            return 7  // Newline (shift to A2)

        // Numbers and punctuation require shift to A2
        case "0"..."9":
            return UInt8(ascii - 48 + 8)  // In A2 alphabet

        default:
            // For now, map unknown to space
            return 0
        }
    }

    // MARK: - Statistics

    /// Get vocabulary statistics
    public func getStatistics() -> String {
        var stats = "Vocabulary Statistics:\n"
        stats += "  Total words: \(wordTypes.count)\n"
        stats += "  Verbs: \(verbNumbers.count)\n"
        stats += "  Buzzwords: \(buzzwords.count)\n"
        stats += "  Synonyms: \(synonyms.count)\n"
        return stats
    }
}
