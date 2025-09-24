import Foundation

/// A parser for ZIL (Zork Implementation Language) source code.
///
/// `ZILParser` converts a stream of tokens from the lexer into an Abstract Syntax Tree (AST)
/// representing the structure and semantics of ZIL programs. The parser handles all ZIL
/// language constructs including S-expressions, routine definitions, object declarations,
/// and various top-level directives.
///
/// ## Features
/// - Recursive descent parsing for S-expressions
/// - Complete ZIL language construct support
/// - Robust error handling with recovery
/// - Precise source location tracking
/// - Support for all ZIL declaration types
///
/// ## Usage Example
/// ```swift
/// let lexer = ZILLexer(source: source, filename: "game.zil")
/// let parser = ZILParser(lexer: lexer)
/// let declarations = try parser.parseProgram()
/// ```
///
/// ## Thread Safety
/// This class is not thread-safe. Create separate parser instances for
/// concurrent processing of different source files.
public class ZILParser {

    // MARK: - Private Properties

    /// The lexer providing tokens
    private let lexer: ZILLexer

    /// Current token being examined
    private var currentToken: ZILToken

    /// Whether we've reached the end of the token stream
    private var isAtEnd: Bool {
        if case .endOfFile = currentToken.type {
            return true
        }
        return false
    }

    // MARK: - Initialization

    /// Creates a new ZIL parser with the given lexer.
    ///
    /// - Parameter lexer: The lexer to provide tokens from ZIL source code
    /// - Throws: `ParseError` if the lexer cannot provide the first token
    public init(lexer: ZILLexer) throws {
        self.lexer = lexer
        self.currentToken = try lexer.nextToken()
    }

    // MARK: - Public Interface

    /// Parses a complete ZIL program into a list of declarations.
    ///
    /// This method processes the entire token stream and produces an AST
    /// representing all top-level declarations in the ZIL program.
    ///
    /// - Returns: An array of parsed ZIL declarations
    /// - Throws: `ParseError` for syntax errors or malformed input
    public func parseProgram() throws -> [ZILDeclaration] {
        var declarations: [ZILDeclaration] = []

        while !isAtEnd {
            if let declaration = try parseDeclaration() {
                declarations.append(declaration)
            }
        }

        return declarations
    }

    /// Parses a single expression from the token stream.
    ///
    /// Useful for parsing individual ZIL expressions outside of a full program context.
    ///
    /// - Returns: The parsed ZIL expression
    /// - Throws: `ParseError` for syntax errors
    public func parseExpression() throws -> ZILExpression {
        return try parseExpressionInternal()
    }

    // MARK: - Private Parsing Methods

    /// Parses a top-level declaration.
    private func parseDeclaration() throws -> ZILDeclaration? {
        // Skip comments and whitespace at top level
        if case .lineComment = currentToken.type {
            try advance()
            return nil
        }

        // Handle string literals as comments at top level
        if case .string = currentToken.type {
            try advance()
            return nil
        }

        // Parse S-expressions as declarations
        if case .leftAngle = currentToken.type {
            return try parseAngleBracketDeclaration()
        }

        // Handle other top-level constructs
        throw ParseError.unexpectedToken(expected: "declaration", found: currentToken.type, location: currentToken.location)
    }

    /// Parses declarations starting with angle brackets.
    private func parseAngleBracketDeclaration() throws -> ZILDeclaration {
        let startLocation = currentToken.location
        try consume(.leftAngle, "Expected '<'")

        guard case .atom(let keyword) = currentToken.type else {
            throw ParseError.expectedAtom(location: currentToken.location)
        }

        switch keyword.uppercased() {
        case "ROUTINE":
            return .routine(try parseRoutineDeclaration(startLocation: startLocation))
        case "OBJECT":
            return .object(try parseObjectDeclaration(startLocation: startLocation))
        case "SETG":
            return .global(try parseGlobalDeclaration(startLocation: startLocation))
        case "GLOBAL":
            return .global(try parseGlobalDeclaration(startLocation: startLocation))
        case "PROPDEF":
            return .property(try parsePropertyDeclaration(startLocation: startLocation))
        case "CONSTANT":
            return .constant(try parseConstantDeclaration(startLocation: startLocation))
        case "INSERT-FILE":
            return .insertFile(try parseInsertFileDeclaration(startLocation: startLocation))
        case "VERSION":
            return .version(try parseVersionDeclaration(startLocation: startLocation))
        default:
            // Parse the full expression to catch any syntax errors
            var elements: [ZILExpression] = [.atom(keyword, startLocation)]

            while !check(.rightAngle) && !isAtEnd {
                elements.append(try parseExpressionInternal())
            }

            try consume(.rightAngle, "Expected '>' to close expression")

            // Now we know the expression is syntactically valid but not a known declaration
            throw ParseError.unknownDeclaration(keyword, location: startLocation)
        }
    }

    /// Parses a routine declaration.
    private func parseRoutineDeclaration(startLocation: SourceLocation) throws -> ZILRoutineDeclaration {
        try advance() // Skip ROUTINE keyword

        guard case .atom(let name) = currentToken.type else {
            throw ParseError.expectedRoutineName(location: currentToken.location)
        }
        try advance()

        // Parse parameter list
        try consume(.leftParen, "Expected '(' for routine parameters")
        let (parameters, optionalParameters, auxiliaryVariables) = try parseParameterList()
        try consume(.rightParen, "Expected ')' after routine parameters")

        // Parse routine body
        var body: [ZILExpression] = []
        while !check(.rightAngle) && !isAtEnd {
            // Skip comments in routine body
            if case .lineComment = currentToken.type {
                try advance()
                continue
            }

            body.append(try parseExpressionInternal())
        }

        try consume(.rightAngle, "Expected '>' to close routine")

        return ZILRoutineDeclaration(
            name: name,
            parameters: parameters,
            optionalParameters: optionalParameters,
            auxiliaryVariables: auxiliaryVariables,
            body: body,
            location: startLocation
        )
    }

    /// Parses a parameter list with optional and auxiliary parameters.
    private func parseParameterList() throws -> (parameters: [String], optional: [String], auxiliary: [String]) {
        var parameters: [String] = []
        var optionalParameters: [String] = []
        var auxiliaryVariables: [String] = []
        var currentSection: ParameterSection = .required

        while !check(.rightParen) && !isAtEnd {
            if case .atom(let name) = currentToken.type {
                switch name.uppercased() {
                case "\"OPT\"", "OPT":
                    currentSection = .optional
                case "\"AUX\"", "AUX":
                    currentSection = .auxiliary
                default:
                    switch currentSection {
                    case .required:
                        parameters.append(name)
                    case .optional:
                        optionalParameters.append(name)
                    case .auxiliary:
                        auxiliaryVariables.append(name)
                    }
                }
                try advance()
            } else if case .string(let str) = currentToken.type {
                // Handle quoted parameter section markers
                switch str.uppercased() {
                case "OPT":
                    currentSection = .optional
                case "AUX":
                    currentSection = .auxiliary
                default:
                    throw ParseError.invalidParameterSection(str, location: currentToken.location)
                }
                try advance()
            } else {
                throw ParseError.expectedParameterName(location: currentToken.location)
            }
        }

        return (parameters, optionalParameters, auxiliaryVariables)
    }

    /// Parameter section types for routine declarations
    private enum ParameterSection {
        case required
        case optional
        case auxiliary
    }

    /// Parses an object declaration.
    private func parseObjectDeclaration(startLocation: SourceLocation) throws -> ZILObjectDeclaration {
        try advance() // Skip OBJECT keyword

        guard case .atom(let name) = currentToken.type else {
            throw ParseError.expectedObjectName(location: currentToken.location)
        }
        try advance()

        var properties: [ZILObjectProperty] = []

        while !check(.rightAngle) && !isAtEnd {
            // Skip comments in object body
            if case .lineComment = currentToken.type {
                try advance()
                continue
            }

            if case .leftParen = currentToken.type {
                properties.append(try parseObjectProperty())
            } else {
                throw ParseError.expectedObjectProperty(location: currentToken.location)
            }
        }

        try consume(.rightAngle, "Expected '>' to close object")

        return ZILObjectDeclaration(name: name, properties: properties, location: startLocation)
    }

    /// Parses an individual object property.
    private func parseObjectProperty() throws -> ZILObjectProperty {
        let startLocation = currentToken.location
        try consume(.leftParen, "Expected '(' for object property")

        guard case .atom(let propertyName) = currentToken.type else {
            throw ParseError.expectedPropertyName(location: currentToken.location)
        }
        try advance()

        // Parse all values until we hit the closing paren
        var values: [ZILExpression] = []
        while !check(.rightParen) && !isAtEnd {
            values.append(try parseExpressionInternal())
        }

        try consume(.rightParen, "Expected ')' to close object property")

        // If there's only one value, use it directly; otherwise create a list
        let value: ZILExpression
        if values.count == 1 {
            value = values[0]
        } else {
            value = .list(values, startLocation)
        }

        return ZILObjectProperty(name: propertyName, value: value, location: startLocation)
    }

    /// Parses a global variable declaration.
    private func parseGlobalDeclaration(startLocation: SourceLocation) throws -> ZILGlobalDeclaration {
        try advance() // Skip SETG/GLOBAL keyword

        guard case .atom(let name) = currentToken.type else {
            throw ParseError.expectedGlobalName(location: currentToken.location)
        }
        try advance()

        let value = try parseExpressionInternal()

        try consume(.rightAngle, "Expected '>' to close global declaration")

        return ZILGlobalDeclaration(name: name, value: value, location: startLocation)
    }

    /// Parses a property definition declaration.
    private func parsePropertyDeclaration(startLocation: SourceLocation) throws -> ZILPropertyDeclaration {
        try advance() // Skip PROPDEF keyword

        guard case .atom(let name) = currentToken.type else {
            throw ParseError.expectedPropertyName(location: currentToken.location)
        }
        try advance()

        let defaultValue = try parseExpressionInternal()

        try consume(.rightAngle, "Expected '>' to close property definition")

        return ZILPropertyDeclaration(name: name, defaultValue: defaultValue, location: startLocation)
    }

    /// Parses a constant declaration.
    private func parseConstantDeclaration(startLocation: SourceLocation) throws -> ZILConstantDeclaration {
        try advance() // Skip CONSTANT keyword

        guard case .atom(let name) = currentToken.type else {
            throw ParseError.expectedConstantName(location: currentToken.location)
        }
        try advance()

        let value = try parseExpressionInternal()

        try consume(.rightAngle, "Expected '>' to close constant declaration")

        return ZILConstantDeclaration(name: name, value: value, location: startLocation)
    }

    /// Parses an insert file declaration.
    private func parseInsertFileDeclaration(startLocation: SourceLocation) throws -> ZILInsertFileDeclaration {
        try advance() // Skip INSERT-FILE keyword

        guard case .string(let filename) = currentToken.type else {
            throw ParseError.expectedFilename(location: currentToken.location)
        }
        try advance()

        // Check for optional T flag
        var withTFlag = false
        if case .atom(let flag) = currentToken.type, flag.uppercased() == "T" {
            withTFlag = true
            try advance()
        }

        try consume(.rightAngle, "Expected '>' to close insert file declaration")

        return ZILInsertFileDeclaration(filename: filename, withTFlag: withTFlag, location: startLocation)
    }

    /// Parses a version declaration.
    private func parseVersionDeclaration(startLocation: SourceLocation) throws -> ZILVersionDeclaration {
        try advance() // Skip VERSION keyword

        guard case .atom(let version) = currentToken.type else {
            throw ParseError.expectedVersionType(location: currentToken.location)
        }
        try advance()

        try consume(.rightAngle, "Expected '>' to close version declaration")

        return ZILVersionDeclaration(version: version, location: startLocation)
    }

    /// Parses expressions (S-expressions, literals, variables).
    private func parseExpressionInternal() throws -> ZILExpression {
        let location = currentToken.location

        switch currentToken.type {
        case .atom(let name):
            try advance()
            return .atom(name, location)

        case .number(let value):
            try advance()
            return .number(value, location)

        case .string(let text):
            try advance()
            return .string(text, location)

        case .globalVariable(let name):
            try advance()
            return .globalVariable(name, location)

        case .localVariable(let name):
            try advance()
            return .localVariable(name, location)

        case .propertyReference(let name):
            try advance()
            return .propertyReference(name, location)

        case .flagReference(let name):
            try advance()
            return .flagReference(name, location)

        case .leftAngle:
            return try parseAngleBracketExpression()

        case .leftParen:
            return try parseParenthesesExpression()

        default:
            throw ParseError.unexpectedToken(expected: "expression", found: currentToken.type, location: location)
        }
    }

    /// Parses expressions enclosed in angle brackets.
    private func parseAngleBracketExpression() throws -> ZILExpression {
        let startLocation = currentToken.location
        try consume(.leftAngle, "Expected '<'")

        var elements: [ZILExpression] = []

        while !check(.rightAngle) && !isAtEnd {
            elements.append(try parseExpressionInternal())
        }

        try consume(.rightAngle, "Expected '>' to close expression")

        return .list(elements, startLocation)
    }

    /// Parses expressions enclosed in parentheses.
    private func parseParenthesesExpression() throws -> ZILExpression {
        let startLocation = currentToken.location
        try consume(.leftParen, "Expected '('")

        var elements: [ZILExpression] = []

        while !check(.rightParen) && !isAtEnd {
            elements.append(try parseExpressionInternal())
        }

        try consume(.rightParen, "Expected ')' to close expression")

        return .list(elements, startLocation)
    }

    // MARK: - Token Navigation Utilities

    /// Advances to the next token.
    @discardableResult
    private func advance() throws -> ZILToken {
        let previous = currentToken
        if !isAtEnd {
            currentToken = try lexer.nextToken()
        }
        return previous
    }

    /// Checks if the current token matches the given type.
    private func check(_ type: TokenType) -> Bool {
        return currentToken.type == type
    }

    /// Consumes a token of the expected type or throws an error.
    private func consume(_ type: TokenType, _ message: String) throws {
        if check(type) {
            try advance()
        } else {
            throw ParseError.unexpectedToken(expected: message, found: currentToken.type, location: currentToken.location)
        }
    }
}