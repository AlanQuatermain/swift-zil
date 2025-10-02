import Foundation
import Synchronization

/// String processing and optimization system for ZIL compilation
///
/// This system handles string literal optimization, manipulation functions,
/// text compression, and encoding for Z-Machine story files.
public final class StringProcessor: Sendable {

    /// String pool for deduplication and optimization
    private struct StringPool: ~Copyable {
        /// All unique strings in the program
        var strings: [String: StringInfo] = [:]

        /// String compression dictionary
        var compressionDictionary: [String: UInt8] = [:]

        /// Next available string ID
        var nextId: Int = 0

        /// Statistics for optimization analysis
        var stats: StringStatistics = StringStatistics()
    }

    /// Information about a string literal
    public struct StringInfo: Sendable, Equatable {
        /// Unique identifier for this string
        public let id: Int

        /// The actual string content
        public let content: String

        /// Number of times this string is referenced
        public var referenceCount: Int

        /// Compressed representation (if applicable)
        public var compressed: Data?

        /// Source locations where this string appears
        public var locations: [SourceLocation]

        /// Estimated memory savings from compression
        public var savings: Int

        public init(id: Int, content: String, location: SourceLocation) {
            self.id = id
            self.content = content
            self.referenceCount = 1
            self.compressed = nil
            self.locations = [location]
            self.savings = 0
        }
    }

    /// Statistics about string usage and optimization
    public struct StringStatistics: Sendable, Equatable {
        /// Total number of unique strings
        public var uniqueStrings: Int = 0

        /// Total string content length (uncompressed)
        public var totalLength: Int = 0

        /// Total compressed length
        public var compressedLength: Int = 0

        /// Number of strings that benefit from compression
        public var compressibleStrings: Int = 0

        /// Total memory saved through optimization
        public var totalSavings: Int = 0

        /// Most frequently used strings
        public var topStrings: [(String, Int)] = []

        public static func == (lhs: StringStatistics, rhs: StringStatistics) -> Bool {
            return lhs.uniqueStrings == rhs.uniqueStrings &&
                   lhs.totalLength == rhs.totalLength &&
                   lhs.compressedLength == rhs.compressedLength &&
                   lhs.compressibleStrings == rhs.compressibleStrings &&
                   lhs.totalSavings == rhs.totalSavings &&
                   lhs.topStrings.count == rhs.topStrings.count &&
                   zip(lhs.topStrings, rhs.topStrings).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        }
    }

    private let pool: Mutex<StringPool>

    public init() {
        self.pool = Mutex(StringPool())
    }

    /// Add a string literal to the pool and get its information
    ///
    /// - Parameters:
    ///   - content: The string content
    ///   - location: Source location where the string appears
    /// - Returns: StringInfo for the string (existing or newly created)
    public func addString(_ content: String, at location: SourceLocation) -> StringInfo {
        return pool.withLock { pool in
            if var existing = pool.strings[content] {
                // String already exists, increment reference count
                existing.referenceCount += 1
                existing.locations.append(location)
                pool.strings[content] = existing
                return existing
            } else {
                // New string, add to pool
                let info = StringInfo(id: pool.nextId, content: content, location: location)
                pool.strings[content] = info
                pool.nextId += 1

                // Update statistics
                pool.stats.uniqueStrings += 1
                pool.stats.totalLength += content.count

                return info
            }
        }
    }

    /// Get information about a specific string
    ///
    /// - Parameter content: The string content to look up
    /// - Returns: StringInfo if the string exists in the pool
    public func getStringInfo(_ content: String) -> StringInfo? {
        return pool.withLock { pool in
            pool.strings[content]
        }
    }

    /// Get all strings in the pool
    ///
    /// - Returns: Array of all StringInfo objects
    public func getAllStrings() -> [StringInfo] {
        return pool.withLock { pool in
            Array(pool.strings.values).sorted { $0.id < $1.id }
        }
    }

    /// Get strings sorted by reference count (most used first)
    ///
    /// - Returns: Array of StringInfo sorted by usage frequency
    public func getStringsByUsage() -> [StringInfo] {
        return pool.withLock { pool in
            Array(pool.strings.values).sorted { $0.referenceCount > $1.referenceCount }
        }
    }

    /// Optimize string storage through compression and deduplication
    ///
    /// This method analyzes all strings in the pool and applies various
    /// optimization techniques to reduce memory usage.
    public func optimize() {
        pool.withLock { poolState in
            // Build compression dictionary from frequent substrings
            buildCompressionDictionary(&poolState)

            // Compress individual strings
            compressStrings(&poolState)

            // Update statistics
            updateStatistics(&poolState)
        }
    }

    /// Get current string processing statistics
    ///
    /// - Returns: StringStatistics with current optimization data
    public func getStatistics() -> StringStatistics {
        return pool.withLock { pool in
            pool.stats
        }
    }

    /// Clear all strings from the pool (for testing/reset)
    public func clearPool() {
        pool.withLock { pool in
            pool.strings.removeAll()
            pool.compressionDictionary.removeAll()
            pool.nextId = 0
            pool.stats = StringStatistics()
        }
    }

    // MARK: - String Manipulation Functions

    /// Extract substring from a string expression
    ///
    /// - Parameters:
    ///   - string: The source string
    ///   - start: Starting index (1-based, ZIL convention)
    ///   - length: Number of characters to extract
    /// - Returns: Substring or nil if invalid parameters
    public static func substring(_ string: String, start: Int, length: Int) -> String? {
        guard start > 0, length >= 0 else { return nil }

        let startIndex = string.index(string.startIndex, offsetBy: start - 1, limitedBy: string.endIndex)
        guard let validStart = startIndex else { return nil }

        let endIndex = string.index(validStart, offsetBy: length, limitedBy: string.endIndex)
        guard let validEnd = endIndex else {
            // Take to end of string if length exceeds remaining characters
            return String(string[validStart...])
        }

        return String(string[validStart..<validEnd])
    }

    /// Concatenate multiple strings
    ///
    /// - Parameter strings: Array of strings to concatenate
    /// - Returns: Concatenated string
    public static func concatenate(_ strings: [String]) -> String {
        return strings.joined()
    }

    /// Get the length of a string in characters
    ///
    /// - Parameter string: The string to measure
    /// - Returns: Character count
    public static func length(_ string: String) -> Int {
        return string.count
    }

    /// Convert string to uppercase
    ///
    /// - Parameter string: The string to convert
    /// - Returns: Uppercase version of the string
    public static func uppercase(_ string: String) -> String {
        return string.uppercased()
    }

    /// Convert string to lowercase
    ///
    /// - Parameter string: The string to convert
    /// - Returns: Lowercase version of the string
    public static func lowercase(_ string: String) -> String {
        return string.lowercased()
    }

    /// Find the position of a substring within a string
    ///
    /// - Parameters:
    ///   - string: The string to search in
    ///   - substring: The substring to find
    /// - Returns: 1-based position of first occurrence, or 0 if not found
    public static func indexOf(_ string: String, substring: String) -> Int {
        guard let range = string.range(of: substring) else { return 0 }
        return string.distance(from: string.startIndex, to: range.lowerBound) + 1
    }

    /// Replace all occurrences of a substring with another string
    ///
    /// - Parameters:
    ///   - string: The source string
    ///   - target: The substring to replace
    ///   - replacement: The replacement string
    /// - Returns: String with replacements made
    public static func replace(_ string: String, target: String, replacement: String) -> String {
        return string.replacingOccurrences(of: target, with: replacement)
    }

    // MARK: - Private Implementation

    /// Build a compression dictionary from frequent substrings
    private func buildCompressionDictionary(_ pool: inout StringPool) {
        // Analyze all strings to find common substrings
        var substringCounts: [String: Int] = [:]

        for (content, info) in pool.strings {
            // Extract substrings of length 2-8 (good compression candidates)
            for length in 2...min(8, content.count) {
                for i in 0...(content.count - length) {
                    let start = content.index(content.startIndex, offsetBy: i)
                    let end = content.index(start, offsetBy: length)
                    let substring = String(content[start..<end])

                    // Weight by reference count (more used strings are more valuable)
                    substringCounts[substring, default: 0] += info.referenceCount
                }
            }
        }

        // Select the most valuable substrings for the compression dictionary
        let sortedSubstrings = substringCounts.sorted { $0.value > $1.value }
        let maxDictionarySize = 96 // Typical Z-Machine compression dictionary size

        pool.compressionDictionary.removeAll()
        var compressionCode: UInt8 = 32 // Start after control characters

        for (substring, count) in sortedSubstrings.prefix(maxDictionarySize) {
            // Only include substrings that appear frequently enough to be worth it
            if count >= 3 && substring.count >= 2 {
                pool.compressionDictionary[substring] = compressionCode
                compressionCode += 1
            }
        }
    }

    /// Compress individual strings using the compression dictionary
    private func compressStrings(_ pool: inout StringPool) {
        for (content, var info) in pool.strings {
            info.compressed = compressString(content, dictionary: pool.compressionDictionary)

            if let compressed = info.compressed {
                info.savings = content.utf8.count - compressed.count
                if info.savings > 0 {
                    pool.stats.compressibleStrings += 1
                }
            }

            pool.strings[content] = info
        }
    }

    /// Compress a single string using the compression dictionary
    private func compressString(_ string: String, dictionary: [String: UInt8]) -> Data? {
        guard !dictionary.isEmpty else { return nil }

        var compressed = Data()
        var remaining = string

        while !remaining.isEmpty {
            var matched = false

            // Try to match the longest possible substring
            for length in stride(from: min(8, remaining.count), through: 2, by: -1) {
                let end = remaining.index(remaining.startIndex, offsetBy: length, limitedBy: remaining.endIndex)
                guard let validEnd = end else { continue }

                let substring = String(remaining[..<validEnd])

                if let compressionCode = dictionary[substring] {
                    compressed.append(compressionCode)
                    remaining = String(remaining[validEnd...])
                    matched = true
                    break
                }
            }

            if !matched {
                // No compression match, add the character directly
                let char = remaining.removeFirst()
                if let asciiValue = char.asciiValue {
                    compressed.append(asciiValue)
                } else {
                    // Handle non-ASCII characters (convert to UTF-8)
                    compressed.append(contentsOf: String(char).utf8)
                }
            }
        }

        return compressed
    }

    /// Update statistics after optimization
    private func updateStatistics(_ pool: inout StringPool) {
        pool.stats.uniqueStrings = pool.strings.count
        pool.stats.totalLength = pool.strings.values.reduce(0) { $0 + $1.content.count }
        pool.stats.compressedLength = pool.strings.values.reduce(0) { total, info in
            total + (info.compressed?.count ?? info.content.utf8.count)
        }
        pool.stats.totalSavings = pool.strings.values.reduce(0) { $0 + $1.savings }

        // Top 10 most used strings
        pool.stats.topStrings = pool.strings.values
            .sorted { $0.referenceCount > $1.referenceCount }
            .prefix(10)
            .map { ($0.content, $0.referenceCount) }
    }
}

/// ZSCII (Z-Machine Standard Character Input/Output) encoding support
public struct ZSCIIEncoder: Sendable {

    /// Convert a string to ZSCII bytes for Z-Machine storage
    ///
    /// - Parameters:
    ///   - string: The string to encode
    ///   - version: Z-Machine version (affects character set)
    /// - Returns: ZSCII encoded bytes
    public static func encode(_ string: String, version: Int = 5) -> [UInt8] {
        var result: [UInt8] = []

        for char in string {
            if let zsciiCode = charToZSCII(char, version: version) {
                result.append(zsciiCode)
            } else {
                // Handle Unicode characters in later Z-Machine versions
                if version >= 5 {
                    // Use Unicode escape sequence for unsupported characters
                    let unicode = char.unicodeScalars.first?.value ?? 63 // '?' as fallback
                    result.append(contentsOf: encodeUnicode(unicode))
                } else {
                    // Replace with '?' in earlier versions
                    result.append(63)
                }
            }
        }

        return result
    }

    /// Convert ZSCII bytes back to a string
    ///
    /// - Parameters:
    ///   - bytes: ZSCII encoded bytes
    ///   - version: Z-Machine version
    /// - Returns: Decoded string
    public static func decode(_ bytes: [UInt8], version: Int = 5) -> String {
        var result = ""
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            if let char = zsciiToChar(byte, version: version) {
                result.append(char)
                i += 1
            } else if version >= 5 && byte >= 155 && byte <= 251 {
                // Unicode escape sequence in Z-Machine v5+
                if i + 2 < bytes.count {
                    let unicode = (UInt32(bytes[i + 1]) << 8) | UInt32(bytes[i + 2])
                    if let scalar = UnicodeScalar(unicode) {
                        result.append(Character(scalar))
                    }
                    i += 3
                } else {
                    result.append("?")
                    i += 1
                }
            } else {
                result.append("?")
                i += 1
            }
        }

        return result
    }

    // MARK: - Private Implementation

    /// Convert a character to ZSCII code
    private static func charToZSCII(_ char: Character, version: Int) -> UInt8? {
        guard let ascii = char.asciiValue else { return nil }

        // Basic ASCII mapping (ZSCII codes 32-126 map directly to ASCII)
        if ascii >= 32 && ascii <= 126 {
            return ascii
        }

        // Special ZSCII characters
        switch char {
        case "\n": return 13 // New line
        case "\t": return version >= 4 ? 9 : nil // Tab (v4+)
        default: return nil
        }
    }

    /// Convert ZSCII code to character
    private static func zsciiToChar(_ code: UInt8, version: Int) -> Character? {
        // Basic ASCII mapping
        if code >= 32 && code <= 126 {
            // We know UnicodeScalar for printable ASCII characters is always non-nil
            return Character(UnicodeScalar(UInt32(code)).unsafelyUnwrapped)
        }

        // Special ZSCII characters
        switch code {
        case 13: return "\n"
        case 9: return version >= 4 ? "\t" : nil
        default: return nil
        }
    }

    /// Encode a Unicode value as ZSCII escape sequence
    private static func encodeUnicode(_ unicode: UInt32) -> [UInt8] {
        let high = UInt8((unicode >> 8) & 0xFF)
        let low = UInt8(unicode & 0xFF)
        return [155, high, low] // ZSCII Unicode escape
    }
}