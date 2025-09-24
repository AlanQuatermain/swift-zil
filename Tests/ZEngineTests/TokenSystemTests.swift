import Testing
@testable import ZEngine

@Suite("Token System Tests")
struct TokenSystemTests {

    // MARK: - ZILToken Tests

    @Test("ZILToken creation and properties")
    func zilTokenCreationAndProperties() throws {
        let location = SourceLocation(file: "token.zil", line: 10, column: 15)
        let token = ZILToken(.atom("HELLO"), value: "HELLO", location: location)

        #expect(token.value == "HELLO")
        #expect(token.location == location)
        if case .atom(let name) = token.type {
            #expect(name == "HELLO")
        } else {
            #expect(Bool(false), "Token type should be atom")
        }
    }

    @Test("ZILToken with different token types")
    func zilTokenWithDifferentTypes() throws {
        let location = SourceLocation(file: "types.zil", line: 5, column: 8)

        // Test number token
        let numberToken = ZILToken(.number(42), value: "42", location: location)
        #expect(numberToken.value == "42")
        if case .number(let value) = numberToken.type {
            #expect(value == 42)
        } else {
            #expect(Bool(false), "Should be number token")
        }

        // Test string token
        let stringToken = ZILToken(.string("Hello World"), value: "\"Hello World\"", location: location)
        #expect(stringToken.value == "\"Hello World\"")
        if case .string(let content) = stringToken.type {
            #expect(content == "Hello World")
        } else {
            #expect(Bool(false), "Should be string token")
        }

        // Test global variable token
        let globalToken = ZILToken(.globalVariable("SCORE"), value: ",SCORE", location: location)
        #expect(globalToken.value == ",SCORE")
        if case .globalVariable(let name) = globalToken.type {
            #expect(name == "SCORE")
        } else {
            #expect(Bool(false), "Should be global variable token")
        }

        // Test local variable token
        let localToken = ZILToken(.localVariable("TEMP"), value: ".TEMP", location: location)
        #expect(localToken.value == ".TEMP")
        if case .localVariable(let name) = localToken.type {
            #expect(name == "TEMP")
        } else {
            #expect(Bool(false), "Should be local variable token")
        }
    }

    // MARK: - TokenType Tests

    @Test("TokenType delimiter detection")
    func tokenTypeDelimiterDetection() throws {
        #expect(TokenType.leftAngle.isDelimiter == true)
        #expect(TokenType.rightAngle.isDelimiter == true)
        #expect(TokenType.leftParen.isDelimiter == true)
        #expect(TokenType.rightParen.isDelimiter == true)

        // Non-delimiters
        #expect(TokenType.atom("TEST").isDelimiter == false)
        #expect(TokenType.number(42).isDelimiter == false)
        #expect(TokenType.string("test").isDelimiter == false)
        #expect(TokenType.globalVariable("VAR").isDelimiter == false)
        #expect(TokenType.localVariable("VAR").isDelimiter == false)
        #expect(TokenType.endOfFile.isDelimiter == false)
    }

    @Test("TokenType literal detection")
    func tokenTypeLiteralDetection() throws {
        #expect(TokenType.number(123).isLiteral == true)
        #expect(TokenType.string("test").isLiteral == true)
        #expect(TokenType.atom("ATOM").isLiteral == true)

        // Non-literals
        #expect(TokenType.leftAngle.isLiteral == false)
        #expect(TokenType.rightAngle.isLiteral == false)
        #expect(TokenType.leftParen.isLiteral == false)
        #expect(TokenType.rightParen.isLiteral == false)
        #expect(TokenType.globalVariable("VAR").isLiteral == false)
        #expect(TokenType.localVariable("VAR").isLiteral == false)
        #expect(TokenType.propertyReference("PROP").isLiteral == false)
        #expect(TokenType.flagReference("FLAG").isLiteral == false)
        #expect(TokenType.lineComment("comment").isLiteral == false)
        #expect(TokenType.stringComment("comment").isLiteral == false)
        #expect(TokenType.endOfFile.isLiteral == false)
        #expect(TokenType.invalid("x").isLiteral == false)
    }

    @Test("TokenType variable reference detection")
    func tokenTypeVariableReferenceDetection() throws {
        #expect(TokenType.globalVariable("GLOBAL").isVariableReference == true)
        #expect(TokenType.localVariable("LOCAL").isVariableReference == true)

        // Non-variable references
        #expect(TokenType.leftAngle.isVariableReference == false)
        #expect(TokenType.rightAngle.isVariableReference == false)
        #expect(TokenType.leftParen.isVariableReference == false)
        #expect(TokenType.rightParen.isVariableReference == false)
        #expect(TokenType.number(42).isVariableReference == false)
        #expect(TokenType.string("test").isVariableReference == false)
        #expect(TokenType.atom("ATOM").isVariableReference == false)
        #expect(TokenType.propertyReference("PROP").isVariableReference == false)
        #expect(TokenType.flagReference("FLAG").isVariableReference == false)
        #expect(TokenType.lineComment("comment").isVariableReference == false)
        #expect(TokenType.stringComment("comment").isVariableReference == false)
        #expect(TokenType.endOfFile.isVariableReference == false)
        #expect(TokenType.invalid("x").isVariableReference == false)
    }

    @Test("TokenType comment detection")
    func tokenTypeCommentDetection() throws {
        #expect(TokenType.lineComment("This is a line comment").isComment == true)
        #expect(TokenType.stringComment("This is a string comment").isComment == true)

        // Non-comments
        #expect(TokenType.leftAngle.isComment == false)
        #expect(TokenType.rightAngle.isComment == false)
        #expect(TokenType.leftParen.isComment == false)
        #expect(TokenType.rightParen.isComment == false)
        #expect(TokenType.number(42).isComment == false)
        #expect(TokenType.string("test").isComment == false)
        #expect(TokenType.atom("ATOM").isComment == false)
        #expect(TokenType.globalVariable("VAR").isComment == false)
        #expect(TokenType.localVariable("VAR").isComment == false)
        #expect(TokenType.propertyReference("PROP").isComment == false)
        #expect(TokenType.flagReference("FLAG").isComment == false)
        #expect(TokenType.endOfFile.isComment == false)
        #expect(TokenType.invalid("x").isComment == false)
    }

    @Test("TokenType display names")
    func tokenTypeDisplayNames() throws {
        #expect(TokenType.leftAngle.displayName == "opening angle bracket '<'")
        #expect(TokenType.rightAngle.displayName == "closing angle bracket '>'")
        #expect(TokenType.leftParen.displayName == "opening parenthesis '('")
        #expect(TokenType.rightParen.displayName == "closing parenthesis ')'")
        #expect(TokenType.number(42).displayName == "number literal")
        #expect(TokenType.string("test").displayName == "string literal")
        #expect(TokenType.atom("ATOM").displayName == "atom")
        #expect(TokenType.globalVariable("VAR").displayName == "global variable reference")
        #expect(TokenType.localVariable("VAR").displayName == "local variable reference")
        #expect(TokenType.propertyReference("PROP").displayName == "property reference")
        #expect(TokenType.flagReference("FLAG").displayName == "flag reference")
        #expect(TokenType.lineComment("comment").displayName == "line comment")
        #expect(TokenType.stringComment("comment").displayName == "string comment")
        #expect(TokenType.endOfFile.displayName == "end of file")
        #expect(TokenType.invalid("x").displayName == "invalid token")
    }

    @Test("TokenType equality")
    func tokenTypeEquality() throws {
        // Test that token types with same associated values are equal
        #expect(TokenType.atom("TEST") == TokenType.atom("TEST"))
        #expect(TokenType.number(42) == TokenType.number(42))
        #expect(TokenType.string("hello") == TokenType.string("hello"))
        #expect(TokenType.globalVariable("VAR") == TokenType.globalVariable("VAR"))
        #expect(TokenType.localVariable("VAR") == TokenType.localVariable("VAR"))
        #expect(TokenType.propertyReference("PROP") == TokenType.propertyReference("PROP"))
        #expect(TokenType.flagReference("FLAG") == TokenType.flagReference("FLAG"))
        #expect(TokenType.lineComment("comment") == TokenType.lineComment("comment"))
        #expect(TokenType.stringComment("comment") == TokenType.stringComment("comment"))
        #expect(TokenType.invalid("x") == TokenType.invalid("x"))

        // Test that token types with different associated values are not equal
        #expect(TokenType.atom("TEST1") != TokenType.atom("TEST2"))
        #expect(TokenType.number(42) != TokenType.number(43))
        #expect(TokenType.string("hello") != TokenType.string("world"))
        #expect(TokenType.globalVariable("VAR1") != TokenType.globalVariable("VAR2"))

        // Test that different token types are not equal
        #expect(TokenType.leftAngle != TokenType.rightAngle)
        #expect(TokenType.leftParen != TokenType.rightParen)
        #expect(TokenType.atom("TEST") != TokenType.string("TEST"))
        #expect(TokenType.number(42) != TokenType.atom("42"))
    }

    // MARK: - TokenUtils Tests

    @Test("TokenUtils valid atom name validation")
    func tokenUtilsValidAtomNameValidation() throws {
        // Valid atom names
        #expect(TokenUtils.isValidAtomName("HELLO") == true)
        #expect(TokenUtils.isValidAtomName("TEST-ROUTINE") == true)
        #expect(TokenUtils.isValidAtomName("IS-PLAYER?") == true)
        #expect(TokenUtils.isValidAtomName("PLAYER123") == true)
        #expect(TokenUtils.isValidAtomName("?PLAYER") == true)
        #expect(TokenUtils.isValidAtomName("-HELPER") == true)
        #expect(TokenUtils.isValidAtomName("A") == true)
        #expect(TokenUtils.isValidAtomName("ABC-123-XYZ?") == true)

        // Invalid atom names
        #expect(TokenUtils.isValidAtomName("") == false) // Empty
        #expect(TokenUtils.isValidAtomName("123ABC") == false) // Starts with number
        #expect(TokenUtils.isValidAtomName("@INVALID") == false) // Invalid starting character
        #expect(TokenUtils.isValidAtomName("TEST@INVALID") == false) // Invalid character in middle
        #expect(TokenUtils.isValidAtomName("TEST SPACE") == false) // Contains space

        // Reserved words should be invalid
        #expect(TokenUtils.isValidAtomName("ROUTINE") == false)
        #expect(TokenUtils.isValidAtomName("OBJECT") == false)
        #expect(TokenUtils.isValidAtomName("GLOBAL") == false)
        #expect(TokenUtils.isValidAtomName("IF") == false)
        #expect(TokenUtils.isValidAtomName("COND") == false)
        #expect(TokenUtils.isValidAtomName("routine") == false) // Case insensitive
        #expect(TokenUtils.isValidAtomName("Routine") == false) // Case insensitive
    }

    @Test("TokenUtils atom name length limits")
    func tokenUtilsAtomNameLengthLimits() throws {
        // Test maximum length (255 characters)
        let maxLengthName = String(repeating: "A", count: ZConstants.maxSymbolLength)
        #expect(TokenUtils.isValidAtomName(maxLengthName) == true)

        // Test exceeding maximum length
        let tooLongName = String(repeating: "A", count: ZConstants.maxSymbolLength + 1)
        #expect(TokenUtils.isValidAtomName(tooLongName) == false)

        // Test edge cases around the limit
        let justUnderLimit = String(repeating: "B", count: ZConstants.maxSymbolLength - 1)
        #expect(TokenUtils.isValidAtomName(justUnderLimit) == true)
    }

    @Test("TokenUtils decimal number parsing")
    func tokenUtilsDecimalNumberParsing() throws {
        #expect(TokenUtils.parseNumber("0") == 0)
        #expect(TokenUtils.parseNumber("42") == 42)
        #expect(TokenUtils.parseNumber("-42") == -42)
        #expect(TokenUtils.parseNumber("32767") == 32767) // Max Int16
        #expect(TokenUtils.parseNumber("-32768") == -32768) // Min Int16
        #expect(TokenUtils.parseNumber("123") == 123)
        #expect(TokenUtils.parseNumber("-999") == -999)

        // Invalid decimal numbers
        #expect(TokenUtils.parseNumber("") == nil)
        #expect(TokenUtils.parseNumber("   ") == nil) // Whitespace only
        #expect(TokenUtils.parseNumber("abc") == nil)
        #expect(TokenUtils.parseNumber("12.34") == nil) // Float
        #expect(TokenUtils.parseNumber("99999") == nil) // Out of range
        #expect(TokenUtils.parseNumber("-99999") == nil) // Out of range
    }

    @Test("TokenUtils hexadecimal number parsing")
    func tokenUtilsHexadecimalNumberParsing() throws {
        #expect(TokenUtils.parseNumber("$0") == 0)
        #expect(TokenUtils.parseNumber("$1A") == 26)
        #expect(TokenUtils.parseNumber("$FF") == 255)
        #expect(TokenUtils.parseNumber("$FFFF") == -1) // 16-bit signed overflow
        #expect(TokenUtils.parseNumber("$7FFF") == 32767) // Max positive
        #expect(TokenUtils.parseNumber("$8000") == -32768) // Min negative (two's complement)
        #expect(TokenUtils.parseNumber("$-1A") == -26)
        #expect(TokenUtils.parseNumber("$-FF") == -255)

        // Case insensitive
        #expect(TokenUtils.parseNumber("$ff") == 255)
        #expect(TokenUtils.parseNumber("$AbCd") == -21555)

        // Invalid hex numbers
        #expect(TokenUtils.parseNumber("$") == nil)
        #expect(TokenUtils.parseNumber("$G") == nil) // Invalid hex digit
        #expect(TokenUtils.parseNumber("$XYZ") == nil) // Invalid hex digits
    }

    @Test("TokenUtils octal number parsing")
    func tokenUtilsOctalNumberParsing() throws {
        #expect(TokenUtils.parseNumber("%0") == 0)
        #expect(TokenUtils.parseNumber("%7") == 7)
        #expect(TokenUtils.parseNumber("%10") == 8)
        #expect(TokenUtils.parseNumber("%77") == 63) // 7*8 + 7
        #expect(TokenUtils.parseNumber("%777") == 511) // 7*64 + 7*8 + 7
        #expect(TokenUtils.parseNumber("%177777") == -1) // 16-bit signed overflow
        #expect(TokenUtils.parseNumber("%77777") == 32767) // Max positive
        #expect(TokenUtils.parseNumber("%100000") == -32768) // Min negative
        #expect(TokenUtils.parseNumber("%-10") == -8)
        #expect(TokenUtils.parseNumber("%-77") == -63)

        // Invalid octal numbers
        #expect(TokenUtils.parseNumber("%") == nil)
        #expect(TokenUtils.parseNumber("%8") == nil) // Invalid octal digit
        #expect(TokenUtils.parseNumber("%9") == nil) // Invalid octal digit
        #expect(TokenUtils.parseNumber("%ABC") == nil) // Invalid octal digits
    }

    @Test("TokenUtils binary number parsing")
    func tokenUtilsBinaryNumberParsing() throws {
        #expect(TokenUtils.parseNumber("#0") == 0)
        #expect(TokenUtils.parseNumber("#1") == 1)
        #expect(TokenUtils.parseNumber("#10") == 2)
        #expect(TokenUtils.parseNumber("#11") == 3)
        #expect(TokenUtils.parseNumber("#101") == 5)
        #expect(TokenUtils.parseNumber("#1111111111111111") == -1) // 16-bit signed overflow
        #expect(TokenUtils.parseNumber("#111111111111111") == 32767) // Max positive
        #expect(TokenUtils.parseNumber("#1000000000000000") == -32768) // Min negative
        #expect(TokenUtils.parseNumber("#-10") == -2)
        #expect(TokenUtils.parseNumber("#-101") == -5)

        // Invalid binary numbers
        #expect(TokenUtils.parseNumber("#") == nil)
        #expect(TokenUtils.parseNumber("#2") == nil) // Invalid binary digit
        #expect(TokenUtils.parseNumber("#ABC") == nil) // Invalid binary digits
    }

    @Test("TokenUtils string escape processing")
    func tokenUtilsStringEscapeProcessing() throws {
        // Basic string without escapes
        #expect(TokenUtils.processStringEscapes("hello") == "hello")
        #expect(TokenUtils.processStringEscapes("") == "")

        // Standard escape sequences
        #expect(TokenUtils.processStringEscapes("hello\\nworld") == "hello\nworld")
        #expect(TokenUtils.processStringEscapes("tab\\there") == "tab\there")
        #expect(TokenUtils.processStringEscapes("line\\rreturn") == "line\rreturn")
        #expect(TokenUtils.processStringEscapes("quote\\\"mark") == "quote\"mark")
        #expect(TokenUtils.processStringEscapes("back\\\\slash") == "back\\slash")

        // Multiple escapes
        #expect(TokenUtils.processStringEscapes("\\n\\t\\r") == "\n\t\r")
        #expect(TokenUtils.processStringEscapes("a\\nb\\tc") == "a\nb\tc")

        // Hexadecimal escapes
        #expect(TokenUtils.processStringEscapes("\\x41") == "A") // ASCII 65
        #expect(TokenUtils.processStringEscapes("\\x20") == " ") // ASCII 32 (space)
        #expect(TokenUtils.processStringEscapes("\\x00") == "\0") // ASCII 0 (null)

        // Invalid or incomplete escapes (should be left as-is)
        #expect(TokenUtils.processStringEscapes("\\z") == "\\z") // Invalid escape
        #expect(TokenUtils.processStringEscapes("\\") == "\\") // Incomplete escape at end
        #expect(TokenUtils.processStringEscapes("\\x") == "\\x") // Incomplete hex escape
        #expect(TokenUtils.processStringEscapes("\\xZZ") == "\\xZZ") // Invalid hex digits

        // Complex combinations
        #expect(TokenUtils.processStringEscapes("Hello\\nWorld\\x21") == "Hello\nWorld!")
        #expect(TokenUtils.processStringEscapes("Path\\\\File\\x2Eext") == "Path\\File.ext")
    }

    @Test("TokenUtils edge cases in string processing")
    func tokenUtilsEdgeCasesInStringProcessing() throws {
        // String ending with backslash
        #expect(TokenUtils.processStringEscapes("test\\") == "test\\")

        // Multiple consecutive backslashes
        #expect(TokenUtils.processStringEscapes("\\\\\\\\") == "\\\\")
        #expect(TokenUtils.processStringEscapes("\\\\\\n") == "\\\n")

        // Hex escape at end of string
        #expect(TokenUtils.processStringEscapes("end\\x41") == "endA")

        // Partial hex escapes (implementation creates Unicode scalar for single hex digit)
        let partialResult = TokenUtils.processStringEscapes("\\x4")
        // "4" is parsed as hex -> UnicodeScalar(4) -> control character
        #expect(partialResult == "\u{04}") // ASCII 4 control character
        #expect(TokenUtils.processStringEscapes("\\x4G") == "\\x4G") // Second character invalid

        // Unicode handling (should work with valid ASCII codes)
        #expect(TokenUtils.processStringEscapes("\\x7F") == "\u{7F}") // DEL character
    }

    // MARK: - TokenType All Cases Coverage

    @Test("TokenType comprehensive coverage")
    func tokenTypeComprehensiveCoverage() throws {
        // Test all TokenType cases to ensure complete coverage
        let testLocation = SourceLocation(file: "comprehensive.zil", line: 1, column: 1)

        let allTokenTypes: [TokenType] = [
            .leftAngle,
            .rightAngle,
            .leftParen,
            .rightParen,
            .number(42),
            .string("test"),
            .atom("ATOM"),
            .globalVariable("GLOBAL"),
            .localVariable("LOCAL"),
            .propertyReference("PROP"),
            .flagReference("FLAG"),
            .lineComment("line comment"),
            .stringComment("string comment"),
            .endOfFile,
            .invalid("x")
        ]

        // Test that all token types can be created and have proper display names
        for tokenType in allTokenTypes {
            let token = ZILToken(tokenType, value: "test", location: testLocation)

            // Verify token creation
            #expect(token.type == tokenType)
            #expect(token.location == testLocation)

            // Verify display name is not empty
            #expect(!tokenType.displayName.isEmpty)

            // Verify boolean properties are well-defined
            _ = tokenType.isDelimiter
            _ = tokenType.isLiteral
            _ = tokenType.isVariableReference
            _ = tokenType.isComment
        }
    }

    @Test("TokenType sendable conformance")
    func tokenTypeSendableConformance() throws {
        // Test that TokenType conforms to Sendable and can be used across actor boundaries
        let tokenType: TokenType = .atom("TEST")

        // This test verifies that TokenType is Sendable by compilation
        // If TokenType didn't conform to Sendable, this would be a compile error
        let sendableCheck: any Sendable = tokenType
        #expect(sendableCheck is TokenType)
    }

    // MARK: - Integration Tests

    @Test("Token system integration")
    func tokenSystemIntegration() throws {
        let location = SourceLocation(file: "integration.zil", line: 20, column: 5)

        // Test complete workflow: create token -> validate -> process
        let atomName = "VALID-ATOM?"
        #expect(TokenUtils.isValidAtomName(atomName) == true)

        let atomToken = ZILToken(.atom(atomName), value: atomName, location: location)
        #expect(atomToken.type.isLiteral == true)
        #expect(atomToken.type.displayName == "atom")

        // Test number workflow
        let numberText = "$FF"
        let parsedNumber = TokenUtils.parseNumber(numberText)
        #expect(parsedNumber == 255)

        if let number = parsedNumber {
            let numberToken = ZILToken(.number(number), value: numberText, location: location)
            #expect(numberToken.type.isLiteral == true)
            #expect(numberToken.type.displayName == "number literal")
        }

        // Test string workflow
        let rawString = "Hello\\nWorld"
        let processedString = TokenUtils.processStringEscapes(rawString)
        #expect(processedString == "Hello\nWorld")

        let stringToken = ZILToken(.string(processedString), value: "\"" + rawString + "\"", location: location)
        #expect(stringToken.type.isLiteral == true)
        #expect(stringToken.type.displayName == "string literal")
    }

    // MARK: - Performance and Edge Cases

    @Test("TokenUtils performance with large inputs")
    func tokenUtilsPerformanceWithLargeInputs() throws {
        // Test with large atom name (at the limit)
        let largeAtomName = "A" + String(repeating: "B", count: ZConstants.maxSymbolLength - 1)
        #expect(TokenUtils.isValidAtomName(largeAtomName) == true)

        // Test with large string for escape processing
        let largeString = String(repeating: "Hello\\nWorld ", count: 100)
        let processed = TokenUtils.processStringEscapes(largeString)
        #expect(processed.contains("\n")) // Should have expanded \n escapes
        // Each "Hello\\nWorld " (13 chars) becomes "Hello\nWorld " (12 chars)
        // So 1300 becomes 1200 (100 fewer characters)
        #expect(processed.count < largeString.count) // String should be shorter after escape processing
    }

    @Test("TokenType memory efficiency")
    func tokenTypeMemoryEfficiency() throws {
        // Test that associated values are handled efficiently
        let atomToken = TokenType.atom("VERY-LONG-ATOM-NAME-FOR-TESTING")
        let numberToken = TokenType.number(32767)
        let stringToken = TokenType.string("This is a relatively long string for testing memory usage")

        // Verify tokens maintain their values correctly
        if case .atom(let name) = atomToken {
            #expect(name == "VERY-LONG-ATOM-NAME-FOR-TESTING")
        }
        if case .number(let value) = numberToken {
            #expect(value == 32767)
        }
        if case .string(let content) = stringToken {
            #expect(content == "This is a relatively long string for testing memory usage")
        }
    }
}