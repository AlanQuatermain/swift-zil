import Foundation

/// Represents a token in ZIL source code.
///
/// `ZILToken` encapsulates all types of lexical elements that can appear in ZIL source,
/// from basic punctuation and literals to complex language constructs. Each token
/// carries its type, value, and source location for precise error reporting.
///
/// ## Token Categories
/// - **Delimiters**: Angle brackets, parentheses for S-expression syntax
/// - **Literals**: Numbers, strings, atoms (identifiers)
/// - **References**: Global and local variable references
/// - **Special**: Comments, end-of-file marker
///
/// ## Usage Example
/// ```swift
/// let token = ZILToken(.atom("HELLO"), value: "HELLO", location: location)
/// if case .atom(let name) = token.type {
///     print("Found atom: \(name)")
/// }
/// ```
public struct ZILToken: Sendable {
    /// The type and associated data of this token
    public let type: TokenType

    /// The raw text value from the source code
    public let value: String

    /// The location in source code where this token appears
    public let location: SourceLocation

    /// Creates a new ZIL token.
    ///
    /// - Parameters:
    ///   - type: The token type with any associated data
    ///   - value: The raw source text that produced this token
    ///   - location: The source location where the token was found
    public init(_ type: TokenType, value: String, location: SourceLocation) {
        self.type = type
        self.value = value
        self.location = location
    }
}

/// Represents the different types of tokens that can appear in ZIL source code.
///
/// `TokenType` is a comprehensive enumeration of all lexical elements in the ZIL
/// language, organized by syntactic category. Each case may carry associated data
/// containing the parsed value or additional metadata.
///
/// ## S-Expression Structure
/// ZIL uses S-expression syntax with angle brackets for function calls and
/// parentheses for data structures and property lists.
///
/// ## Variable References
/// - Global variables: `,VARIABLE-NAME`
/// - Local variables: `.VARIABLE-NAME`
/// - Property references: `P?PROPERTY-NAME`
///
/// ## Numeric Literals
/// ZIL supports 16-bit signed integers in decimal, hexadecimal, and octal formats.
public enum TokenType: Sendable, Equatable {
    // MARK: - Delimiters and Punctuation

    /// Opening angle bracket `<` - starts function calls and expressions
    case leftAngle

    /// Closing angle bracket `>` - ends function calls and expressions
    case rightAngle

    /// Opening parenthesis `(` - starts lists and property definitions
    case leftParen

    /// Closing parenthesis `)` - ends lists and property definitions
    case rightParen

    // MARK: - Operators

    /// Indirection operator `!` - dereferences atoms and variables at runtime
    case indirection

    // MARK: - Literals

    /// A numeric literal value
    /// - Parameter value: The parsed integer value (-32768 to 32767)
    case number(Int16)

    /// A string literal enclosed in quotes
    /// - Parameter value: The parsed string content (without quotes)
    case string(String)

    /// An atomic symbol (identifier)
    /// - Parameter name: The symbol name in uppercase per ZIL conventions
    case atom(String)

    // MARK: - Variable References

    /// A global variable reference (`,VARIABLE-NAME`)
    /// - Parameter name: The variable name without the comma prefix
    case globalVariable(String)

    /// A local variable reference (`.VARIABLE-NAME`)
    /// - Parameter name: The variable name without the dot prefix
    case localVariable(String)

    // MARK: - Property and Flag References

    /// A property reference (`P?PROPERTY-NAME`)
    /// - Parameter name: The property name without the `P?` prefix
    case propertyReference(String)

    /// A flag reference (`F?FLAG-NAME`)
    /// - Parameter name: The flag name without the `F?` prefix
    case flagReference(String)

    // MARK: - Comments and Whitespace

    /// A line comment (`;comment text`)
    /// - Parameter text: The comment content without the semicolon
    case lineComment(String)

    /// A string comment (`"comment text"`)
    /// - Parameter text: The comment content without the quotes
    case stringComment(String)

    // MARK: - Special Tokens

    /// End of file marker
    case endOfFile

    /// A token that couldn't be properly parsed
    /// - Parameter character: The problematic character
    case invalid(Character)
}

// MARK: - TokenType Extensions

extension TokenType {
    /// Indicates whether this token type represents a delimiter.
    ///
    /// Delimiters are structural elements that define the boundaries of
    /// S-expressions, lists, and other syntactic constructs.
    ///
    /// - Returns: `true` for angle brackets and parentheses, `false` otherwise
    public var isDelimiter: Bool {
        switch self {
        case .leftAngle, .rightAngle, .leftParen, .rightParen:
            return true
        default:
            return false
        }
    }

    /// Indicates whether this token type represents a literal value.
    ///
    /// Literals are concrete values that can be used directly in expressions
    /// without further resolution or evaluation.
    ///
    /// - Returns: `true` for numbers, strings, and atoms, `false` otherwise
    public var isLiteral: Bool {
        switch self {
        case .number, .string, .atom:
            return true
        default:
            return false
        }
    }

    /// Indicates whether this token type represents a variable reference.
    ///
    /// Variable references require resolution during compilation to determine
    /// their storage location and access method.
    ///
    /// - Returns: `true` for global and local variable references, `false` otherwise
    public var isVariableReference: Bool {
        switch self {
        case .globalVariable, .localVariable:
            return true
        default:
            return false
        }
    }

    /// Indicates whether this token type represents a comment.
    ///
    /// Comments are typically ignored during parsing but may be preserved
    /// for documentation generation or debugging purposes.
    ///
    /// - Returns: `true` for line and string comments, `false` otherwise
    public var isComment: Bool {
        switch self {
        case .lineComment, .stringComment:
            return true
        default:
            return false
        }
    }

    /// Returns the display name for this token type.
    ///
    /// Provides human-readable names for token types, useful for error
    /// messages and debugging output.
    ///
    /// - Returns: A descriptive string for the token type
    public var displayName: String {
        switch self {
        case .leftAngle: return "opening angle bracket '<'"
        case .rightAngle: return "closing angle bracket '>'"
        case .leftParen: return "opening parenthesis '('"
        case .rightParen: return "closing parenthesis ')'"
        case .indirection: return "indirection operator '!'"
        case .number: return "number literal"
        case .string: return "string literal"
        case .atom: return "atom"
        case .globalVariable: return "global variable reference"
        case .localVariable: return "local variable reference"
        case .propertyReference: return "property reference"
        case .flagReference: return "flag reference"
        case .lineComment: return "line comment"
        case .stringComment: return "string comment"
        case .endOfFile: return "end of file"
        case .invalid: return "invalid token"
        }
    }
}

// MARK: - Token Utilities

/// Utility functions for working with ZIL tokens and token streams.
///
/// `TokenUtils` provides helper methods for common operations on tokens,
/// including validation, conversion, and formatting utilities used throughout
/// the compilation pipeline.
public enum TokenUtils {

    /// Validates whether a string is a valid ZIL atom name.
    ///
    /// ZIL atoms must follow specific naming conventions including allowed
    /// characters, length limits, and case sensitivity rules.
    ///
    /// - Parameter name: The string to validate as an atom name
    /// - Returns: `true` if the string is a valid atom name, `false` otherwise
    ///
    /// ## Validation Rules
    /// - Must start with a letter or allowed punctuation
    /// - Can contain letters, digits, hyphens, and question marks
    /// - Maximum length defined by `ZConstants.maxSymbolLength`
    /// - Cannot be a reserved word
    public static func isValidAtomName(_ name: String) -> Bool {
        guard !name.isEmpty && name.count <= ZConstants.maxSymbolLength else {
            return false
        }

        // Check if it's a reserved word
        if ZConstants.reservedWords.contains(name.uppercased()) {
            return false
        }

        // Must start with letter or certain punctuation
        guard let first = name.first,
              first.isLetter || "?-".contains(first) else {
            return false
        }

        // Rest must be alphanumeric, hyphen, or question mark
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-?"))
        return name.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }

    /// Parses a ZIL numeric literal from its string representation.
    ///
    /// ZIL supports multiple numeric formats including decimal, hexadecimal,
    /// octal, and binary. All numbers are 16-bit signed integers.
    ///
    /// - Parameter text: The string representation of the number
    /// - Returns: The parsed integer value, or `nil` if parsing fails
    ///
    /// ## Supported Formats
    /// - Decimal: `123`, `-456`
    /// - Hexadecimal: `$1A2B`, `$-FFFF`
    /// - Octal: `%777`, `%-123`
    /// - Binary: `#1101`, `#-1010`
    public static func parseNumber(_ text: String) -> Int16? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Handle different number formats
        if trimmed.hasPrefix("$") {
            // Hexadecimal
            let hex = String(trimmed.dropFirst())
            return parseSignedHex(hex)
        } else if trimmed.hasPrefix("%") {
            // Octal
            let octal = String(trimmed.dropFirst())
            return parseSignedOctal(octal)
        } else if trimmed.hasPrefix("#") {
            // Binary
            let binary = String(trimmed.dropFirst())
            return parseSignedBinary(binary)
        } else {
            // Decimal
            return Int16(trimmed)
        }
    }

    /// Parses a signed hexadecimal number string.
    private static func parseSignedHex(_ hex: String) -> Int16? {
        let negative = hex.hasPrefix("-")
        let digits = negative ? String(hex.dropFirst()) : hex

        guard let value = UInt16(digits, radix: 16) else { return nil }
        let result = Int16(bitPattern: value)

        return negative ? -result : result
    }

    /// Parses a signed octal number string.
    private static func parseSignedOctal(_ octal: String) -> Int16? {
        let negative = octal.hasPrefix("-")
        let digits = negative ? String(octal.dropFirst()) : octal

        guard let value = UInt16(digits, radix: 8) else { return nil }
        let result = Int16(bitPattern: value)

        return negative ? -result : result
    }

    /// Parses a signed binary number string.
    private static func parseSignedBinary(_ binary: String) -> Int16? {
        let negative = binary.hasPrefix("-")
        let digits = negative ? String(binary.dropFirst()) : binary

        guard let value = UInt16(digits, radix: 2) else { return nil }
        let result = Int16(bitPattern: value)

        return negative ? -result : result
    }

    /// Processes escape sequences in a ZIL string literal.
    ///
    /// ZIL strings support standard escape sequences for special characters
    /// including newlines, tabs, quotes, and Unicode characters.
    ///
    /// - Parameter raw: The raw string content (without surrounding quotes)
    /// - Returns: The processed string with escape sequences resolved
    ///
    /// ## Supported Escapes
    /// - `\n` - Newline
    /// - `\t` - Tab
    /// - `\r` - Carriage return
    /// - `\"` - Quote character
    /// - `\\` - Backslash
    /// - `\xNN` - Hexadecimal character code
    public static func processStringEscapes(_ raw: String) -> String {
        var result = ""
        var i = raw.startIndex

        while i < raw.endIndex {
            let char = raw[i]

            if char == "\\" && raw.index(after: i) < raw.endIndex {
                let next = raw[raw.index(after: i)]
                switch next {
                case "n":
                    result.append("\n")
                    i = raw.index(i, offsetBy: 2)
                case "t":
                    result.append("\t")
                    i = raw.index(i, offsetBy: 2)
                case "r":
                    result.append("\r")
                    i = raw.index(i, offsetBy: 2)
                case "\"":
                    result.append("\"")
                    i = raw.index(i, offsetBy: 2)
                case "\\":
                    result.append("\\")
                    i = raw.index(i, offsetBy: 2)
                case "x":
                    // Hexadecimal escape sequence
                    let hexStart = raw.index(i, offsetBy: 2)
                    if hexStart < raw.endIndex {
                        let hexEnd = raw.index(hexStart, offsetBy: min(2, raw.distance(from: hexStart, to: raw.endIndex)))
                        let hexString = String(raw[hexStart..<hexEnd])
                        if let value = UInt8(hexString, radix: 16) {
                            let scalar = UnicodeScalar(value)
                            result.append(Character(scalar))
                            i = hexEnd
                        } else {
                            result.append(char)
                            i = raw.index(after: i)
                        }
                    } else {
                        result.append(char)
                        i = raw.index(after: i)
                    }
                default:
                    result.append(char)
                    i = raw.index(after: i)
                }
            } else {
                result.append(char)
                i = raw.index(after: i)
            }
        }

        return result
    }
}