import Testing
@testable import ZEngine

@Suite("ZIL Lexer Tests")
struct LexerTests {

    @Suite("Basic Token Recognition")
    struct BasicTokenRecognition {

        @Test("Delimiter tokens")
        func delimiterTokens() throws {
            let source = "< > ( )"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            #expect(tokens.count == 5) // 4 delimiters + EOF

            #expect(tokens[0].type == .leftAngle)
            #expect(tokens[1].type == .rightAngle)
            #expect(tokens[2].type == .leftParen)
            #expect(tokens[3].type == .rightParen)

            if case .endOfFile = tokens[4].type {
                // Expected
            } else {
                #expect(Bool(false), "Expected EOF token")
            }
        }

        @Test("Numeric literals", arguments: [
            ("123", 123),
            ("-456", -456),
            ("0", 0),
            ("32767", 32767),
            ("-32768", -32768)
        ])
        func numericLiterals(input: String, expected: Int16) throws {
            let lexer = ZILLexer(source: input, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .number(let value) = token.type {
                #expect(value == expected)
            } else {
                #expect(Bool(false), "Expected number token, got \\(token.type)")
            }
        }

        @Test("Hexadecimal numbers", arguments: [
            ("$FF", 255),
            ("$1A2B", 6699),
            ("$-10", -16),
            ("$0", 0)
        ])
        func hexadecimalNumbers(input: String, expected: Int16) throws {
            let lexer = ZILLexer(source: input, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .number(let value) = token.type {
                #expect(value == expected)
            } else {
                #expect(Bool(false), "Expected number token, got \\(token.type)")
            }
        }

        @Test("Octal numbers", arguments: [
            ("%77", 63),
            ("%123", 83),
            ("%0", 0)
        ])
        func octalNumbers(input: String, expected: Int16) throws {
            let lexer = ZILLexer(source: input, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .number(let value) = token.type {
                #expect(value == expected)
            } else {
                #expect(Bool(false), "Expected number token, got \\(token.type)")
            }
        }

        @Test("Binary numbers", arguments: [
            ("#1010", 10),
            ("#11111111", 255),
            ("#0", 0)
        ])
        func binaryNumbers(input: String, expected: Int16) throws {
            let lexer = ZILLexer(source: input, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .number(let value) = token.type {
                #expect(value == expected)
            } else {
                #expect(Bool(false), "Expected number token, got \\(token.type)")
            }
        }

        @Test("String literals")
        func stringLiterals() throws {
            let testCases: [(String, String)] = [
                ("\"Hello\"", "Hello"),
                ("\"Hello, World!\"", "Hello, World!"),
                ("\"\"", ""),
                ("\"Line 1\\nLine 2\"", "Line 1\nLine 2"),  // \n should become actual newline
                ("\"Quote: \\\"text\\\"\"", "Quote: \"text\""),
                ("\"Tab\\tSeparated\"", "Tab\tSeparated")   // \t should become actual tab
            ]

            for (input, expected) in testCases {
                let lexer = ZILLexer(source: input, filename: "test.zil")
                let token = try lexer.nextToken()

                if case .string(let value) = token.type {
                    #expect(value == expected)
                } else {
                    #expect(Bool(false), "Expected string token for '\\(input)', got \\(token.type)")
                }
            }
        }

        @Test("Atom recognition", arguments: [
            "HELLO",
            "HELLO-WORLD",
            "TEST123",
            "?WINNER",
            "VERB?"
        ])
        func atomRecognition(input: String) throws {
            let lexer = ZILLexer(source: input, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .atom(let name) = token.type {
                #expect(name == input.uppercased())
            } else {
                #expect(Bool(false), "Expected atom token, got \\(token.type)")
            }
        }
    }

    @Suite("Variable References")
    struct VariableReferences {

        @Test("Global variable references")
        func globalVariableReferences() throws {
            let testCases = [",WINNER", ",SCORE", ",HERE"]

            for input in testCases {
                let lexer = ZILLexer(source: input, filename: "test.zil")
                let token = try lexer.nextToken()

                if case .globalVariable(let name) = token.type {
                    let expectedName = String(input.dropFirst()).uppercased()
                    #expect(name == expectedName)
                } else {
                    #expect(Bool(false), "Expected global variable token for '\\(input)', got \\(token.type)")
                }
            }
        }

        @Test("Local variable references")
        func localVariableReferences() throws {
            let testCases = [".VAL", ".TEMP", ".COUNT"]

            for input in testCases {
                let lexer = ZILLexer(source: input, filename: "test.zil")
                let token = try lexer.nextToken()

                if case .localVariable(let name) = token.type {
                    let expectedName = String(input.dropFirst()).uppercased()
                    #expect(name == expectedName)
                } else {
                    #expect(Bool(false), "Expected local variable token for '\\(input)', got \\(token.type)")
                }
            }
        }

        @Test("Property references")
        func propertyReferences() throws {
            let testCases = ["P?DESC", "P?ACTION", "P?STRENGTH"]

            for input in testCases {
                let lexer = ZILLexer(source: input, filename: "test.zil")
                let token = try lexer.nextToken()

                if case .propertyReference(let name) = token.type {
                    let expectedName = String(input.dropFirst(2)).uppercased()  // Remove P?, no trailing ?
                    #expect(name == expectedName)
                } else {
                    #expect(Bool(false), "Expected property reference token for '\\(input)', got \\(token.type)")
                }
            }
        }

        @Test("Flag references")
        func flagReferences() throws {
            let testCases = ["F?TAKEBIT", "F?LIGHTBIT", "F?OPENBIT"]

            for input in testCases {
                let lexer = ZILLexer(source: input, filename: "test.zil")
                let token = try lexer.nextToken()

                if case .flagReference(let name) = token.type {
                    let expectedName = String(input.dropFirst(2)).uppercased()  // Remove F?, keep full flag name
                    #expect(name == expectedName)
                } else {
                    #expect(Bool(false), "Expected flag reference token for '\\(input)', got \\(token.type)")
                }
            }
        }
    }

    @Suite("Comment Handling")
    struct CommentHandling {

        @Test("Line comments")
        func lineComments() throws {
            let source = "; This is a comment\nHELLO"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            #expect(tokens.count == 3) // comment + atom + EOF

            if case .lineComment(let text) = tokens[0].type {
                #expect(text == " This is a comment")
            } else {
                #expect(Bool(false), "Expected line comment token")
            }

            if case .atom(let name) = tokens[1].type {
                #expect(name == "HELLO")
            } else {
                #expect(Bool(false), "Expected atom token")
            }
        }

        @Test("Empty line comment")
        func emptyLineComment() throws {
            let source = ";"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .lineComment(let text) = token.type {
                #expect(text == "")
            } else {
                #expect(Bool(false), "Expected empty line comment token")
            }
        }
    }

    @Suite("Complex Expressions")
    struct ComplexExpressions {

        @Test("Simple S-expression")
        func simpleSExpression() throws {
            let source = "<TELL \"Hello, World!\">"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            #expect(tokens.count == 5) // < TELL string > EOF

            #expect(tokens[0].type == .leftAngle)

            if case .atom(let name) = tokens[1].type {
                #expect(name == "TELL")
            } else {
                #expect(Bool(false), "Expected TELL atom")
            }

            if case .string(let text) = tokens[2].type {
                #expect(text == "Hello, World!")
            } else {
                #expect(Bool(false), "Expected string literal")
            }

            #expect(tokens[3].type == .rightAngle)
        }

        @Test("Nested expressions")
        func nestedExpressions() throws {
            let source = "<COND (<EQUAL? ,SCORE 100> <TELL \"Perfect!\">)>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            // Verify bracket depth tracking during tokenization
            let bracketsOnly = tokens.filter { token in
                switch token.type {
                case .leftAngle, .rightAngle, .leftParen, .rightParen:
                    return true
                default:
                    return false
                }
            }

            let expectedBrackets: [TokenType] = [
                .leftAngle,      // <
                .leftParen,      // (
                .leftAngle,      // <
                .rightAngle,     // >
                .leftAngle,      // <
                .rightAngle,     // >
                .rightParen,     // )
                .rightAngle      // >
            ]

            #expect(bracketsOnly.count == expectedBrackets.count)

            for (i, expectedType) in expectedBrackets.enumerated() {
                #expect(bracketsOnly[i].type == expectedType)
            }

            // Verify lexer reports balanced brackets
            #expect(lexer.areBracketsBalanced)
        }

        @Test("Routine definition")
        func routineDefinition() throws {
            let source = """
            <ROUTINE HELLO-WORLD (VAL \"OPT\" COUNT)
                <TELL "Hello from " .VAL>
                <RTRUE>>
            """

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            // Find key tokens
            var routineFound = false
            var helloWorldFound = false
            var valParamFound = false
            var optionalFound = false
            var localVarFound = false

            for token in tokens {
                switch token.type {
                case .atom(let name):
                    if name == "ROUTINE" { routineFound = true }
                    if name == "HELLO-WORLD" { helloWorldFound = true }
                    if name == "VAL" { valParamFound = true }
                case .string(let text):
                    if text == "OPT" { optionalFound = true }
                case .localVariable(let name):
                    if name == "VAL" { localVarFound = true }
                default:
                    break
                }
            }

            #expect(routineFound)
            #expect(helloWorldFound)
            #expect(valParamFound)
            #expect(optionalFound)
            #expect(localVarFound)
        }
    }

    @Suite("Error Handling")
    struct ErrorHandling {

        @Test("Unterminated string")
        func unterminatedString() throws {
            let source = "\"Unterminated string"
            let lexer = ZILLexer(source: source, filename: "test.zil")

            do {
                _ = try lexer.nextToken()
                #expect(Bool(false), "Should have thrown error for unterminated string")
            } catch let error as ParseError {
                switch error.code {
                case .unexpectedEndOfFile:
                    // Expected
                    break
                default:
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            } catch {
                #expect(Bool(false), "Wrong error type: \\(error)")
            }
        }

        @Test("Invalid character recognition")
        func invalidCharacterRecognition() throws {
            let source = "@invalid"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .invalid(let char) = token.type {
                #expect(char == "@")
            } else {
                #expect(Bool(false), "Expected invalid token, got \\(token.type)")
            }
        }

        @Test("Invalid number format")
        func invalidNumberFormat() throws {
            let source = "$ZZZZ" // Invalid hex
            let lexer = ZILLexer(source: source, filename: "test.zil")

            do {
                _ = try lexer.nextToken()
                #expect(Bool(false), "Should have thrown error for invalid number")
            } catch let error as ParseError {
                switch error.code {
                case .invalidSyntax:
                    // Expected
                    break
                default:
                    #expect(Bool(false), "Wrong error type: \(error)")
                }
            } catch {
                #expect(Bool(false), "Wrong error type: \\(error)")
            }
        }
    }

    @Suite("Position Tracking")
    struct PositionTracking {

        @Test("Line and column tracking")
        func lineAndColumnTracking() throws {
            let source = """
            HELLO
            WORLD
            TEST
            """
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            // Check positions of atoms
            if case .atom = tokens[0].type {
                #expect(tokens[0].location.line == 1)
                #expect(tokens[0].location.column == 1)
            }

            if case .atom = tokens[1].type {
                #expect(tokens[1].location.line == 2)
                #expect(tokens[1].location.column == 1)
            }

            if case .atom = tokens[2].type {
                #expect(tokens[2].location.line == 3)
                #expect(tokens[2].location.column == 1)
            }
        }

        @Test("Token value preservation")
        func tokenValuePreservation() throws {
            let source = "<TELL \"Hello\" ,WINNER>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            // Check that raw values are preserved
            #expect(tokens[0].value == "<")
            #expect(tokens[1].value == "TELL")
            #expect(tokens[2].value == "\"Hello\"")
            #expect(tokens[3].value == ",WINNER")
            #expect(tokens[4].value == ">")
        }
    }

    @Suite("Bracket Matching")
    struct BracketMatching {

        @Test("Balanced brackets")
        func balancedBrackets() throws {
            let source = "<COND (<TRUE> <TELL \"Yes\">)>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            _ = try lexer.tokenizeAll()

            #expect(lexer.areBracketsBalanced)
            #expect(lexer.bracketDepth == 0)
        }

        @Test("Unbalanced brackets detection")
        func unbalancedBracketsDetection() throws {
            let source = "<TELL \"Hello\""
            let lexer = ZILLexer(source: source, filename: "test.zil")
            _ = try lexer.tokenizeAll()

            #expect(!lexer.areBracketsBalanced)
            #expect(lexer.bracketDepth == 1)
        }

        @Test("Mixed bracket types")
        func mixedBracketTypes() throws {
            let source = "<ROUTINE FOO (A B C)>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            _ = try lexer.tokenizeAll()

            #expect(lexer.areBracketsBalanced)
        }
    }

    @Suite("Whitespace Handling")
    struct WhitespaceHandling {

        @Test("Multiple spaces and tabs")
        func multipleSpacesAndTabs() throws {
            let source = "HELLO    \t  WORLD"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let tokens = try lexer.tokenizeAll()

            #expect(tokens.count == 3) // HELLO, WORLD, EOF

            if case .atom(let name1) = tokens[0].type,
               case .atom(let name2) = tokens[1].type {
                #expect(name1 == "HELLO")
                #expect(name2 == "WORLD")
            } else {
                #expect(Bool(false), "Expected two atom tokens")
            }
        }

        @Test("Newline handling in multiline strings")
        func newlineHandlingInMultilineStrings() throws {
            let source = "\"Line 1\nLine 2\nLine 3\""
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let token = try lexer.nextToken()

            if case .string(let text) = token.type {
                #expect(text.contains("\n"))
            } else {
                #expect(Bool(false), "Expected string token")
            }
        }
    }
}