import Testing
@testable import ZEngine

@Suite("ZIL Parser Tests")
struct ParserTests {

    @Suite("Basic Expression Parsing")
    struct BasicExpressionParsing {

        @Test("Atom parsing")
        func atomParsing() throws {
            let source = "HELLO"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if case .atom(let name, _) = expression {
                #expect(name == "HELLO")
            } else {
                #expect(Bool(false), "Expected atom expression")
            }
        }

        @Test("Number parsing")
        func numberParsing() throws {
            let testCases: [(String, Int16)] = [
                ("123", 123),
                ("-456", -456),
                ("$FF", 255),
                ("%77", 63),
                ("#1010", 10)
            ]

            for (source, expected) in testCases {
                let lexer = ZILLexer(source: source, filename: "test.zil")
                let parser = try ZILParser(lexer: lexer)

                let expression = try parser.parseExpression()

                if case .number(let value, _) = expression {
                    #expect(value == expected, "Expected \(expected) for '\(source)', got \(value)")
                } else {
                    #expect(Bool(false), "Expected number expression for '\(source)'")
                }
            }
        }

        @Test("String parsing")
        func stringParsing() throws {
            let source = #""Hello, World!""#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if case .string(let text, _) = expression {
                #expect(text == "Hello, World!")
            } else {
                #expect(Bool(false), "Expected string expression")
            }
        }

        @Test("Variable reference parsing")
        func variableReferenceParsing() throws {
            let testCases: [(String, String)] = [
                (",WINNER", "WINNER"),
                (".TEMP", "TEMP"),
                ("P?DESC", "DESC"),
                ("F?TAKEBIT", "TAKEBIT")
            ]

            for (source, expectedName) in testCases {
                let lexer = ZILLexer(source: source, filename: "test.zil")
                let parser = try ZILParser(lexer: lexer)

                let expression = try parser.parseExpression()

                switch expression {
                case .globalVariable(let name, _):
                    #expect(name == expectedName, "Global variable: expected '\(expectedName)', got '\(name)'")
                case .localVariable(let name, _):
                    #expect(name == expectedName, "Local variable: expected '\(expectedName)', got '\(name)'")
                case .propertyReference(let name, _):
                    #expect(name == expectedName, "Property reference: expected '\(expectedName)', got '\(name)'")
                case .flagReference(let name, _):
                    #expect(name == expectedName, "Flag reference: expected '\(expectedName)', got '\(name)'")
                default:
                    #expect(Bool(false), "Unexpected expression type for '\(source)': \(expression)")
                }
            }
        }

        @Test("Simple S-expression parsing")
        func simpleSExpressionParsing() throws {
            let source = #"<TELL "Hello">"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if case .list(let elements, _) = expression {
                #expect(elements.count == 2)

                if case .atom(let command, _) = elements[0] {
                    #expect(command == "TELL")
                } else {
                    #expect(Bool(false), "First element should be TELL atom")
                }

                if case .string(let text, _) = elements[1] {
                    #expect(text == "Hello")
                } else {
                    #expect(Bool(false), "Second element should be string")
                }
            } else {
                #expect(Bool(false), "Expected list expression")
            }
        }

        @Test("Nested S-expression parsing")
        func nestedSExpressionParsing() throws {
            let source = #"<COND (<TRUE> <TELL "Yes">)>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if case .list(let outerElements, _) = expression {
                #expect(outerElements.count == 2)

                // Check COND atom
                if case .atom(let command, _) = outerElements[0] {
                    #expect(command == "COND")
                } else {
                    #expect(Bool(false), "First element should be COND")
                }

                // Check nested list
                if case .list(let innerElements, _) = outerElements[1] {
                    #expect(innerElements.count == 2)
                } else {
                    #expect(Bool(false), "Second element should be nested list")
                }
            } else {
                #expect(Bool(false), "Expected outer list expression")
            }
        }
    }

    @Suite("Declaration Parsing")
    struct DeclarationParsing {

        @Test("Routine declaration parsing")
        func routineDeclarationParsing() throws {
            let source = #"""
            <ROUTINE HELLO-WORLD (NAME "OPT" COUNT "AUX" TEMP)
                <TELL "Hello, " .NAME>
                <RTRUE>>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .routine(let routine) = declarations[0] {
                #expect(routine.name == "HELLO-WORLD")
                #expect(routine.parameters == ["NAME"])
                #expect(routine.optionalParameters.map(\.name) == ["COUNT"])
                #expect(routine.auxiliaryVariables.map(\.name) == ["TEMP"])
                #expect(routine.body.count == 2)
            } else {
                #expect(Bool(false), "Expected routine declaration")
            }
        }

        @Test("Object declaration parsing")
        func objectDeclarationParsing() throws {
            let source = #"""
            <OBJECT LANTERN
                (IN LIVING-ROOM)
                (SYNONYM LAMP LANTERN)
                (DESC "brass lantern")
                (FLAGS TAKEBIT LIGHTBIT)>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .object(let object) = declarations[0] {
                #expect(object.name == "LANTERN")
                #expect(object.properties.count == 4)

                // Check property names
                let propertyNames = object.properties.map { $0.name }
                #expect(propertyNames.contains("IN"))
                #expect(propertyNames.contains("SYNONYM"))
                #expect(propertyNames.contains("DESC"))
                #expect(propertyNames.contains("FLAGS"))
            } else {
                #expect(Bool(false), "Expected object declaration")
            }
        }

        @Test("Global variable declaration parsing")
        func globalVariableDeclarationParsing() throws {
            let source = "<SETG WINNER 0>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .global(let global) = declarations[0] {
                #expect(global.name == "WINNER")
                if case .number(let value, _) = global.value {
                    #expect(value == 0)
                } else {
                    #expect(Bool(false), "Expected number value")
                }
            } else {
                #expect(Bool(false), "Expected global declaration")
            }
        }

        @Test("Property definition parsing")
        func propertyDefinitionParsing() throws {
            let source = "<PROPDEF SIZE 5>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .property(let property) = declarations[0] {
                #expect(property.name == "SIZE")
                if case .number(let value, _) = property.defaultValue {
                    #expect(value == 5)
                } else {
                    #expect(Bool(false), "Expected number default value")
                }
            } else {
                #expect(Bool(false), "Expected property declaration")
            }
        }

        @Test("Constant declaration parsing")
        func constantDeclarationParsing() throws {
            let source = #"<CONSTANT MAX-SCORE 350>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .constant(let constant) = declarations[0] {
                #expect(constant.name == "MAX-SCORE")
                if case .number(let value, _) = constant.value {
                    #expect(value == 350)
                } else {
                    #expect(Bool(false), "Expected number value")
                }
            } else {
                #expect(Bool(false), "Expected constant declaration")
            }
        }

        @Test("Insert file declaration parsing")
        func insertFileDeclarationParsing() throws {
            let testCases = [
                (#"<INSERT-FILE "GLOBALS">"#, "GLOBALS", false),
                (#"<INSERT-FILE "PARSER" T>"#, "PARSER", true)
            ]

            for (source, _, _) in testCases {
                let lexer = ZILLexer(source: source, filename: "test.zil")
                let parser = try ZILParser(lexer: lexer)

                // Expect error since these files don't exist in test environment
                #expect(throws: (any Error).self) {
                    try parser.parseProgram()
                }
            }
        }

        @Test("Version declaration parsing")
        func versionDeclarationParsing() throws {
            let source = "<VERSION ZIP>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .version(let version) = declarations[0] {
                #expect(version.version == "ZIP")
            } else {
                #expect(Bool(false), "Expected version declaration")
            }
        }
    }

    @Suite("Complex ZIL Programs")
    struct ComplexZILPrograms {

        @Test("Multiple declarations")
        func multipleDeclarations() throws {
            let source = #"""
            <VERSION ZIP>

            <SETG SCORE 0>

            <PROPDEF SIZE 5>

            <OBJECT PLAYER
                (DESC "yourself")>

            <ROUTINE MAIN ()
                <TELL "Welcome!" CR>>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 5)

            // Check each declaration type
            #expect(declarations[0].isVersionDeclaration)
            #expect(declarations[1].isGlobalDeclaration)
            #expect(declarations[2].isPropertyDeclaration)
            #expect(declarations[3].isObjectDeclaration)
            #expect(declarations[4].isRoutineDeclaration)
        }

        @Test("Comment handling in programs")
        func commentHandlingInPrograms() throws {
            let source = #"""
            ; This is a line comment
            <VERSION ZIP>

            "This is also a comment"
            <SETG SCORE 0>

            <ROUTINE TEST ()
                ; Another comment
                <TELL "Done">>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            // Comments should be filtered out, only actual declarations remain
            #expect(declarations.count == 3)
        }

        @Test("Real ZIL-like structure")
        func realZILLikeStructure() throws {
            let source = #"""
            <ROUTINE LIVING-ROOM-F (RARG)
                <COND (<EQUAL? .RARG ,M-LOOK>
                       <TELL "You are in the living room." CR>)
                      (<EQUAL? .RARG ,M-END>
                       <COND (,LAMP-ON
                              <TELL "The lamp provides light." CR>)>)>>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .routine(let routine) = declarations[0] {
                #expect(routine.name == "LIVING-ROOM-F")
                #expect(routine.parameters == ["RARG"])
                #expect(routine.body.count == 1) // One COND expression

                // Check the COND structure
                if case .list(let elements, _) = routine.body[0] {
                    if case .atom(let command, _) = elements[0] {
                        #expect(command == "COND")
                    }
                }
            } else {
                #expect(Bool(false), "Expected routine declaration")
            }
        }
    }

    @Suite("Error Handling")
    struct ErrorHandling {

        @Test("Unexpected token error")
        func unexpectedTokenError() throws {
            let source = "< TELL }" // Invalid closing brace
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            do {
                _ = try parser.parseProgram()
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as ParseError {
                switch error.code {
                case .unexpectedToken(let expected, let found):
                    #expect(expected.contains("expression"))
                    #expect("\(found)".contains("invalid"))
                default:
                    #expect(Bool(false), "Expected unexpected token error")
                }
            }
        }

        @Test("Expected atom error")
        func expectedAtomError() throws {
            let source = "< 123 >" // Number where atom expected
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            do {
                _ = try parser.parseProgram()
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as ParseError {
                switch error.code {
                case .expectedAtom:
                    // Expected error
                    break
                default:
                    #expect(Bool(false), "Expected 'expected atom' error, got \(error.code)")
                }
            }
        }

        @Test("Expected routine name error")
        func expectedRoutineNameError() throws {
            let source = "<ROUTINE 123>" // Number where routine name expected
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            do {
                _ = try parser.parseProgram()
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as ParseError {
                switch error.code {
                case .expectedRoutineName:
                    // Expected error
                    break
                default:
                    #expect(Bool(false), "Expected 'expected routine name' error")
                }
            }
        }

        @Test("Unknown declaration error")
        func unknownDeclarationError() throws {
            let source = "<UNKNOWN-DECLARATION>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            do {
                _ = try parser.parseProgram()
                #expect(Bool(false), "Should have thrown an error")
            } catch let error as ParseError {
                switch error.code {
                case .unknownDeclaration(let keyword):
                    #expect(keyword == "UNKNOWN-DECLARATION")
                default:
                    #expect(Bool(false), "Expected 'unknown declaration' error")
                }
            }
        }
    }

    @Suite("Edge Cases")
    struct EdgeCases {

        @Test("Empty parameter list")
        func emptyParameterList() throws {
            let source = #"""
            <ROUTINE EMPTY-PARAMS ()
                <RTRUE>>
            """#

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            if case .routine(let routine) = declarations[0] {
                #expect(routine.parameters.isEmpty)
                #expect(routine.optionalParameters.isEmpty)
                #expect(routine.auxiliaryVariables.isEmpty)
            }
        }

        @Test("Object with no properties")
        func objectWithNoProperties() throws {
            let source = "<OBJECT EMPTY>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            if case .object(let object) = declarations[0] {
                #expect(object.name == "EMPTY")
                #expect(object.properties.isEmpty)
            }
        }

        @Test("Parentheses expressions")
        func parenthesesExpressions() throws {
            let source = "(HELLO WORLD)"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if case .list(let elements, _) = expression {
                #expect(elements.count == 2)
            } else {
                #expect(Bool(false), "Expected list expression from parentheses")
            }
        }
    }
}

// MARK: - Helper Extensions

extension ZILDeclaration {
    var isVersionDeclaration: Bool {
        if case .version = self { return true }
        return false
    }

    var isGlobalDeclaration: Bool {
        if case .global = self { return true }
        return false
    }

    var isPropertyDeclaration: Bool {
        if case .property = self { return true }
        return false
    }

    var isObjectDeclaration: Bool {
        if case .object = self { return true }
        return false
    }

    var isRoutineDeclaration: Bool {
        if case .routine = self { return true }
        return false
    }
}
