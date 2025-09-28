import Foundation

/// A lexical analyzer for ZIL (Zork Implementation Language) source code.
///
/// `ZILLexer` converts ZIL source text into a stream of tokens, handling all aspects
/// of ZIL's S-expression syntax including angle brackets, parentheses, string literals,
/// numeric values, atoms, and variable references. The lexer provides robust error
/// recovery and precise source location tracking for superior error reporting.
///
/// ## Features
/// - Complete ZIL syntax support including all literal types
/// - S-expression delimiter matching with nested bracket tracking
/// - Comprehensive error recovery with resynchronization
/// - Precise source location tracking for every token
/// - Comment handling (both `;` and `"` styles)
/// - Variable reference parsing (global `,VAR` and local `.VAR`)
/// - Multiple numeric formats (decimal, hex, octal, binary)
///
/// ## Usage Example
/// ```swift
/// let source = """
/// <ROUTINE HELLO-WORLD ()
///     <TELL "Hello, World!" CR>
///     <RTRUE>>
/// """
///
/// let lexer = ZILLexer(source: source, filename: "hello.zil")
/// while let token = try lexer.nextToken() {
///     if case .endOfFile = token.type { break }
///     print("\\(token.type) at \\(token.location)")
/// }
/// ```
///
/// ## Thread Safety
/// This class is not thread-safe. Create separate lexer instances for
/// concurrent processing of different source files.
public class ZILLexer {

    // MARK: - Private Properties

    /// The source code being tokenized
    private let source: String

    /// Current position in the source string
    private var currentIndex: String.Index

    /// Current line number (1-based)
    private var currentLine: Int = 1

    /// Current column number (1-based)
    private var currentColumn: Int = 1

    /// The filename being processed
    private let filename: String

    /// Stack for tracking nested bracket depth
    private var bracketStack: [Character] = []

    /// Whether we've reached the end of the source
    private var isAtEnd: Bool {
        return currentIndex >= source.endIndex
    }

    /// The current character at the cursor position
    private var currentChar: Character? {
        guard !isAtEnd else { return nil }
        return source[currentIndex]
    }

    // MARK: - Initialization

    /// Creates a new ZIL lexer for the given source code.
    ///
    /// - Parameters:
    ///   - source: The ZIL source code to tokenize
    ///   - filename: The name of the source file (for error reporting)
    public init(source: String, filename: String = "<unknown>") {
        self.source = source
        self.filename = filename
        self.currentIndex = source.startIndex
    }

    // MARK: - Public Interface

    /// Advances the lexer and returns the next token from the source.
    ///
    /// This method performs the core tokenization work, analyzing the character
    /// stream and producing appropriate token types with precise source locations.
    /// It handles all ZIL syntax elements and provides error recovery for
    /// malformed input.
    ///
    /// - Returns: The next token in the source stream
    /// - Throws: `ParseError` for unrecoverable lexical errors
    public func nextToken() throws -> ZILToken {
        // Skip whitespace but track position
        skipWhitespace()

        // Mark the start of this token
        let tokenStart = currentLocation()

        guard let char = currentChar else {
            return ZILToken(.endOfFile, value: "", location: tokenStart)
        }

        // Handle single-character tokens
        switch char {
        case "<":
            advance()
            bracketStack.append("<")
            return ZILToken(.leftAngle, value: "<", location: tokenStart)

        case ">":
            advance()
            // Check bracket matching
            if let last = bracketStack.last, last == "<" {
                bracketStack.removeLast()
            }
            return ZILToken(.rightAngle, value: ">", location: tokenStart)

        case "(":
            advance()
            bracketStack.append("(")
            return ZILToken(.leftParen, value: "(", location: tokenStart)

        case ")":
            advance()
            // Check bracket matching
            if let last = bracketStack.last, last == "(" {
                bracketStack.removeLast()
            }
            return ZILToken(.rightParen, value: ")", location: tokenStart)

        case "\"":
            return try tokenizeString()

        case ";":
            return tokenizeLineComment()

        case ",":
            return try tokenizeGlobalVariable()

        case ".":
            return try tokenizeLocalVariableOrNumber()

        case "$", "%", "#":
            return try tokenizeNumber()

        case "\\":
            return try tokenizeEscapedAtom()

        case "!":
            return tokenizeIndirection()

        default:
            if char.isNumber || (char == "-" && peekNext()?.isNumber == true) {
                return try tokenizeNumber()
            } else if char == "-" && isNumberStart(peekNext()) {
                return try tokenizeNumber()
            } else if isAtomStartChar(char) {
                return try tokenizeAtom()
            } else {
                // Invalid character - advance and return error token
                let invalidChar = char
                advance()
                return ZILToken(.invalid(invalidChar), value: String(invalidChar), location: tokenStart)
            }
        }
    }

    /// Returns all tokens from the source as an array.
    ///
    /// This convenience method tokenizes the entire source file and returns
    /// all tokens including the final end-of-file token. Useful for parsers
    /// that need to examine the complete token stream.
    ///
    /// - Returns: An array containing all tokens from the source
    /// - Throws: `ParseError` for lexical errors in the source
    public func tokenizeAll() throws -> [ZILToken] {
        var tokens: [ZILToken] = []

        while true {
            let token = try nextToken()
            tokens.append(token)

            if case .endOfFile = token.type {
                break
            }
        }

        return tokens
    }

    /// Returns the current nesting depth of brackets.
    ///
    /// Useful for syntax highlighting, error recovery, and debugging
    /// bracket matching issues in complex S-expressions.
    ///
    /// - Returns: The current bracket nesting depth
    public var bracketDepth: Int {
        return bracketStack.count
    }

    /// Checks if all brackets are properly matched.
    ///
    /// Should be called after tokenization to verify that all opened
    /// brackets have been properly closed.
    ///
    /// - Returns: `true` if brackets are balanced, `false` otherwise
    public var areBracketsBalanced: Bool {
        return bracketStack.isEmpty
    }

    // MARK: - Private Tokenization Methods

    /// Tokenizes a string literal enclosed in double quotes.
    private func tokenizeString() throws -> ZILToken {
        let start = currentLocation()
        let startValue = currentIndex

        advance() // Skip opening quote

        while !isAtEnd && currentChar != "\"" {
            if currentChar == "\\" {
                advance() // Skip escape character
                if !isAtEnd {
                    advance() // Skip escaped character
                }
            } else if currentChar == "\n" {
                // Newlines are allowed in ZIL string literals
                advance()
            } else {
                advance()
            }
        }

        guard currentChar == "\"" else {
            throw ParseError.unexpectedEndOfFile(location: currentLocation())
        }

        advance() // Skip closing quote

        let rawValue = String(source[startValue..<currentIndex])
        let stringContent = String(source[source.index(after: startValue)..<source.index(before: currentIndex)])
        let processedContent = TokenUtils.processStringEscapes(stringContent)

        return ZILToken(.string(processedContent), value: rawValue, location: start)
    }

    /// Tokenizes a line comment starting with semicolon.
    private func tokenizeLineComment() -> ZILToken {
        let start = currentLocation()
        let startValue = currentIndex

        advance() // Skip semicolon

        // Read until end of line
        while !isAtEnd && currentChar != "\n" {
            advance()
        }

        let rawValue = String(source[startValue..<currentIndex])
        let commentText = String(rawValue.dropFirst()) // Remove semicolon

        return ZILToken(.lineComment(commentText), value: rawValue, location: start)
    }

    /// Tokenizes a global variable reference starting with comma.
    private func tokenizeGlobalVariable() throws -> ZILToken {
        let start = currentLocation()
        let startValue = currentIndex

        advance() // Skip comma

        guard let char = currentChar, isAtomStartChar(char) else {
            throw ParseError.invalidSyntax("Expected variable name after ','", location: currentLocation())
        }

        let varName = readAtomName()
        let rawValue = String(source[startValue..<currentIndex])

        return ZILToken(.globalVariable(varName), value: rawValue, location: start)
    }

    /// Tokenizes either a local variable reference or a decimal number starting with dot.
    private func tokenizeLocalVariableOrNumber() throws -> ZILToken {
        let start = currentLocation()

        // Peek ahead to see if this is a number (.123) or variable (.VAR)
        if let next = peekNext(), next.isNumber {
            return try tokenizeNumber()
        }

        let startValue = currentIndex
        advance() // Skip dot

        guard let char = currentChar, isAtomStartChar(char) else {
            throw ParseError.invalidSyntax("Expected variable name after '.'", location: currentLocation())
        }

        let varName = readAtomName()
        let rawValue = String(source[startValue..<currentIndex])

        return ZILToken(.localVariable(varName), value: rawValue, location: start)
    }

    /// Tokenizes a numeric literal in various formats.
    private func tokenizeNumber() throws -> ZILToken {
        let start = currentLocation()
        let startValue = currentIndex

        // Handle negative numbers
        if currentChar == "-" {
            advance()
        }

        // Handle different number formats
        if currentChar == "$" {
            advance() // Skip $
            // Check for negative sign after $
            if currentChar == "-" {
                advance() // Skip -
            }
            readHexDigits()
        } else if currentChar == "%" {
            advance() // Skip %
            // Check for negative sign after %
            if currentChar == "-" {
                advance() // Skip -
            }
            readOctalDigits()
        } else if currentChar == "#" {
            advance() // Skip #
            // Check for negative sign after #
            if currentChar == "-" {
                advance() // Skip -
            }
            readBinaryDigits()
        } else if currentChar == "." {
            advance() // Skip .
            readDecimalDigits()
        } else {
            readDecimalDigits()
        }

        let rawValue = String(source[startValue..<currentIndex])

        guard let number = TokenUtils.parseNumber(rawValue) else {
            throw ParseError.invalidSyntax("Invalid number format: '\(rawValue)'", location: start)
        }

        return ZILToken(.number(number), value: rawValue, location: start)
    }

    /// Tokenizes an atom (identifier) or special reference.
    private func tokenizeAtom() throws -> ZILToken {
        let start = currentLocation()
        let atomName = readAtomName()

        // Check for special references
        if atomName.hasPrefix("P?") && atomName.count > 2 {
            let propName = String(atomName.dropFirst(2))
            return ZILToken(.propertyReference(propName), value: atomName, location: start)
        } else if atomName.hasPrefix("F?") && atomName.count > 2 {
            let flagName = String(atomName.dropFirst(2))
            return ZILToken(.flagReference(flagName), value: atomName, location: start)
        }

        return ZILToken(.atom(atomName), value: atomName, location: start)
    }

    /// Tokenizes an escaped atom starting with backslash (e.g., \#RANDOM, \#COMMAND)
    private func tokenizeEscapedAtom() throws -> ZILToken {
        let start = currentLocation()

        // Consume the backslash
        guard currentChar == "\\" else {
            throw ParseError.invalidSyntax("Expected backslash in escaped atom", location: start)
        }
        advance()

        // The next character is escaped (made literal)
        guard let escapedChar = currentChar else {
            throw ParseError.unexpectedEndOfFile(location: currentLocation())
        }
        advance() // Consume the escaped character

        // Continue reading the rest of the atom normally
        let remainingAtom = readAtomName()
        let fullName = String(escapedChar) + remainingAtom

        return ZILToken(.atom(fullName.uppercased()), value: "\\" + fullName, location: start)
    }

    /// Tokenizes an indirection operator !
    private func tokenizeIndirection() -> ZILToken {
        let start = currentLocation()
        advance() // Consume the !
        return ZILToken(.indirection, value: "!", location: start)
    }

    // MARK: - Character Reading Utilities

    /// Reads characters that form a valid atom name.
    private func readAtomName() -> String {
        let start = currentIndex

        while let char = currentChar, isAtomChar(char) {
            advance()
        }

        let atomText = String(source[start..<currentIndex])
        return atomText.uppercased() // ZIL atoms are case-insensitive, stored as uppercase
    }

    /// Reads decimal digits for numeric literals.
    private func readDecimalDigits() {
        while let char = currentChar, char.isNumber {
            advance()
        }
    }

    /// Reads hexadecimal digits for hex numeric literals.
    private func readHexDigits() {
        while let char = currentChar, char.isHexDigit {
            advance()
        }
    }

    /// Reads octal digits for octal numeric literals.
    private func readOctalDigits() {
        while let char = currentChar, isOctalDigit(char) {
            advance()
        }
    }

    /// Reads binary digits for binary numeric literals.
    private func readBinaryDigits() {
        while let char = currentChar, (char == "0" || char == "1") {
            advance()
        }
    }

    // MARK: - Character Classification

    /// Checks if a character can start an atom name.
    /// Per spec-zap.fwf:67-98 and authentic Infocom ZIL patterns:
    /// - A-Z (uppercase letters)
    /// - -, ?, #, . (symbol constituents from spec)
    /// - =, +, *, /, !, &, |, %, \ (operand prefixes and operators from authentic ZIL)
    /// Note: 0-9 can appear within atoms but not start them
    /// Note: < and > are delimiters, not part of atom names
    private func isAtomStartChar(_ char: Character) -> Bool {
        return char.isUppercase || "-?#.=+*/!&|%\\".contains(char)
    }

    /// Checks if a character can appear in an atom name.
    /// Per spec-zap.fwf:67-98 and authentic Infocom ZIL patterns:
    /// - A-Z (uppercase letters only)
    /// - 0-9 (digits)
    /// - -, ?, #, . (symbol constituents from spec)
    /// - =, +, *, /, !, &, |, %, \ (operand prefixes and operators from authentic ZIL)
    /// Note: < and > are delimiters, not part of atom names
    private func isAtomChar(_ char: Character) -> Bool {
        return char.isUppercase || char.isNumber || "-?#.=+*/!&|%\\".contains(char)
    }

    /// Checks if a character is a valid octal digit.
    private func isOctalDigit(_ char: Character) -> Bool {
        return "01234567".contains(char)
    }

    /// Checks if a character indicates the start of a number.
    private func isNumberStart(_ char: Character?) -> Bool {
        guard let char = char else { return false }
        return char.isNumber || char == "$" || char == "%" || char == "#" || char == "."
    }

    // MARK: - Navigation and Position Tracking

    /// Advances to the next character and updates position tracking.
    @discardableResult
    private func advance() -> Character? {
        guard !isAtEnd else { return nil }

        let char = source[currentIndex]
        currentIndex = source.index(after: currentIndex)

        if char == "\n" {
            currentLine += 1
            currentColumn = 1
        } else {
            currentColumn += 1
        }

        return char
    }

    /// Returns the next character without advancing position.
    private func peekNext() -> Character? {
        guard !isAtEnd else { return nil }
        let nextIndex = source.index(after: currentIndex)
        guard nextIndex < source.endIndex else { return nil }
        return source[nextIndex]
    }

    /// Skips whitespace characters while maintaining position tracking.
    private func skipWhitespace() {
        while let char = currentChar, char.isWhitespace {
            advance()
        }
    }

    /// Returns the current source location.
    private func currentLocation() -> SourceLocation {
        return SourceLocation(file: filename, line: currentLine, column: currentColumn)
    }
}