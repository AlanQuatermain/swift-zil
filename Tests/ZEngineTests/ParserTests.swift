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

        @Test("ZIP-OPTIONS declaration parsing")
        func zipOptionsDeclarationParsing() throws {
            let source = "<ZIP-OPTIONS UNDO COLOR MOUSE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .zipOptions(let zipOptions) = declarations[0] {
                #expect(zipOptions.options.count == 3)
                #expect(zipOptions.options.contains("UNDO"))
                #expect(zipOptions.options.contains("COLOR"))
                #expect(zipOptions.options.contains("MOUSE"))
            } else {
                #expect(Bool(false), "Expected ZIP-OPTIONS declaration")
            }
        }

        @Test("ORDER-OBJECTS? declaration parsing")
        func orderObjectsDeclarationParsing() throws {
            let testCases = [
                ("<ORDER-OBJECTS? ROOMS-FIRST>", "ROOMS-FIRST"),
                ("<ORDER-OBJECTS? DEFINED>", "DEFINED"),
                ("<ORDER-OBJECTS? ROOMS-LAST>", "ROOMS-LAST"),
                ("<ORDER-OBJECTS? ROOMS-AND-LGS-FIRST>", "ROOMS-AND-LGS-FIRST")
            ]

            for (source, expectedOrdering) in testCases {
                let lexer = ZILLexer(source: source, filename: "test.zil")
                let parser = try ZILParser(lexer: lexer)

                let declarations = try parser.parseProgram()

                #expect(declarations.count == 1, "Expected 1 declaration for '\(source)'")

                if case .orderObjects(let orderObjects) = declarations[0] {
                    #expect(orderObjects.ordering == expectedOrdering)
                } else {
                    #expect(Bool(false), "Expected ORDER-OBJECTS? declaration for '\(source)'")
                }
            }
        }

        @Test("ORDER-TREE? declaration parsing")
        func orderTreeDeclarationParsing() throws {
            let source = "<ORDER-TREE? REVERSE-DEFINED>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .orderTree(let orderTree) = declarations[0] {
                #expect(orderTree.ordering == "REVERSE-DEFINED")
            } else {
                #expect(Bool(false), "Expected ORDER-TREE? declaration")
            }
        }

        @Test("ORDER-FLAGS? declaration parsing")
        func orderFlagsDeclarationParsing() throws {
            let source = "<ORDER-FLAGS? LAST TOUCHBIT TRANSBIT>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .orderFlags(let orderFlags) = declarations[0] {
                #expect(orderFlags.order == "LAST")
                #expect(orderFlags.flags.count == 2)
                #expect(orderFlags.flags.contains("TOUCHBIT"))
                #expect(orderFlags.flags.contains("TRANSBIT"))
            } else {
                #expect(Bool(false), "Expected ORDER-FLAGS? declaration")
            }
        }

        @Test("ROUTINE-FLAGS declaration parsing")
        func routineFlagsDeclarationParsing() throws {
            let source = "<ROUTINE-FLAGS CLEAN-STACK? KEEP?>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .routineFlags(let routineFlags) = declarations[0] {
                #expect(routineFlags.flags.count == 2)
                #expect(routineFlags.flags.contains("CLEAN-STACK?"))
                #expect(routineFlags.flags.contains("KEEP?"))
            } else {
                #expect(Bool(false), "Expected ROUTINE-FLAGS declaration")
            }
        }

        @Test("FILE-FLAGS declaration parsing")
        func fileFlagsDeclarationParsing() throws {
            let source = "<FILE-FLAGS CLEAN-STACK? MDL-ZIL?>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)

            if case .fileFlags(let fileFlags) = declarations[0] {
                #expect(fileFlags.flags.count == 2)
                #expect(fileFlags.flags.contains("CLEAN-STACK?"))
                #expect(fileFlags.flags.contains("MDL-ZIL?"))
            } else {
                #expect(Bool(false), "Expected FILE-FLAGS declaration")
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

    @Suite("SYNTAX Declaration Parsing")
    struct SyntaxDeclarationParsing {

        @Test("Simple SYNTAX with verb only")
        func simpleSyntax() throws {
            let source = "<SYNTAX VERBOSE = V-VERBOSE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "VERBOSE")
            #expect(syntax.pattern.isEmpty)
            #expect(syntax.action == "V-VERBOSE")
        }

        @Test("SYNTAX with single OBJECT")
        func syntaxWithObject() throws {
            let source = "<SYNTAX TAKE OBJECT = V-TAKE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "TAKE")
            #expect(syntax.pattern.count == 1)
            #expect(syntax.action == "V-TAKE")

            // Check object element
            if case .object(let label, let constraints) = syntax.pattern[0] {
                #expect(label == "OBJ1")
                #expect(constraints.isEmpty)
            } else {
                #expect(Bool(false), "Expected object element")
            }
        }

        @Test("SYNTAX with OBJECT and constraints")
        func syntaxWithConstraints() throws {
            let source = "<SYNTAX ACTIVATE OBJECT (FIND LIGHTBIT) (HELD CARRIED ON-GROUND IN-ROOM) = V-LAMP-ON>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "ACTIVATE")
            #expect(syntax.pattern.count == 1)
            #expect(syntax.action == "V-LAMP-ON")

            // Check object with constraints
            if case .object(let label, let constraints) = syntax.pattern[0] {
                #expect(label == "OBJ1")
                // Constraints should be flattened: FIND, LIGHTBIT, HELD, CARRIED, ON-GROUND, IN-ROOM
                #expect(constraints.count == 6)

                // Verify first few constraints
                if case .atom(let name, _) = constraints[0] {
                    #expect(name == "FIND")
                }
                if case .atom(let name, _) = constraints[1] {
                    #expect(name == "LIGHTBIT")
                }
            } else {
                #expect(Bool(false), "Expected object element")
            }
        }

        @Test("SYNTAX with prepositions")
        func syntaxWithPrepositions() throws {
            let source = "<SYNTAX CLIMB UP OBJECT (FIND CLIMBBIT) (ON-GROUND IN-ROOM) = V-CLIMB-UP>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "CLIMB")
            #expect(syntax.pattern.count == 2) // UP and OBJECT
            #expect(syntax.action == "V-CLIMB-UP")

            // Check preposition
            if case .preposition(let word) = syntax.pattern[0] {
                #expect(word == "UP")
            } else {
                #expect(Bool(false), "Expected preposition element")
            }

            // Check object
            if case .object(let label, let constraints) = syntax.pattern[1] {
                #expect(label == "OBJ1")
                #expect(constraints.count == 4) // FIND, CLIMBBIT, ON-GROUND, IN-ROOM
            } else {
                #expect(Bool(false), "Expected object element")
            }
        }

        @Test("SYNTAX with multiple objects")
        func syntaxWithMultipleObjects() throws {
            let source = "<SYNTAX PUT OBJECT IN OBJECT = V-PUT>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "PUT")
            #expect(syntax.pattern.count == 3) // OBJECT, IN, OBJECT
            #expect(syntax.action == "V-PUT")

            // Check first object (OBJ1)
            if case .object(let label, _) = syntax.pattern[0] {
                #expect(label == "OBJ1")
            } else {
                #expect(Bool(false), "Expected first object element")
            }

            // Check preposition
            if case .preposition(let word) = syntax.pattern[1] {
                #expect(word == "IN")
            } else {
                #expect(Bool(false), "Expected preposition element")
            }

            // Check second object (OBJ2)
            if case .object(let label, _) = syntax.pattern[2] {
                #expect(label == "OBJ2")
            } else {
                #expect(Bool(false), "Expected second object element")
            }
        }

        @Test("SYNTAX with preaction")
        func syntaxWithPreaction() throws {
            let source = "<SYNTAX TAKE OBJECT = V-TAKE PRE-TAKE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "TAKE")
            #expect(syntax.action == "V-TAKE PRE-TAKE")
        }

        @Test("SYNTAX with complex pattern from real game")
        func syntaxComplexPattern() throws {
            let source = "<SYNTAX ATTACK OBJECT (FIND ACTORBIT) (ON-GROUND IN-ROOM) WITH OBJECT (FIND WEAPONBIT) (HELD CARRIED HAVE) = V-ATTACK>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .syntax(let syntax) = declarations[0] else {
                #expect(Bool(false), "Expected SYNTAX declaration")
                return
            }

            #expect(syntax.verb == "ATTACK")
            #expect(syntax.pattern.count == 3) // OBJECT, WITH, OBJECT
            #expect(syntax.action == "V-ATTACK")

            // First object
            if case .object(let label, let constraints) = syntax.pattern[0] {
                #expect(label == "OBJ1")
                #expect(constraints.count == 4) // FIND, ACTORBIT, ON-GROUND, IN-ROOM
            }

            // Preposition WITH
            if case .preposition(let word) = syntax.pattern[1] {
                #expect(word == "WITH")
            }

            // Second object
            if case .object(let label, let constraints) = syntax.pattern[2] {
                #expect(label == "OBJ2")
                #expect(constraints.count == 5) // FIND, WEAPONBIT, HELD, CARRIED, HAVE
            }
        }

        @Test("SYNTAX error handling - missing verb")
        func syntaxMissingVerb() throws {
            let source = "<SYNTAX = V-ACTION>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("SYNTAX error handling - missing action")
        func syntaxMissingAction() throws {
            let source = "<SYNTAX TAKE OBJECT =>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("SYNTAX error handling - missing equals")
        func syntaxMissingEquals() throws {
            let source = "<SYNTAX TAKE OBJECT V-TAKE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }
    }

    @Suite("DEFMAC Declaration Parsing")
    struct DefmacDeclarationParsing {

        @Test("Macro expansion during parsing")
        func macroExpansionDuringParsing() throws {
            // Define a simple macro and then use it
            let source = """
            <DEFMAC DOUBLE (X) <FORM + .X .X>>
            <ROUTINE TEST-DOUBLE ()
                <DOUBLE 5>>
            """

            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            // Should have 2 declarations: DEFMAC and ROUTINE
            #expect(declarations.count == 2)

            // First should be DEFMAC
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }
            #expect(defmac.name == "DOUBLE")

            // Second should be ROUTINE with expanded macro in body
            guard case .routine(let routine) = declarations[1] else {
                Issue.record("Expected ROUTINE declaration")
                return
            }
            #expect(routine.name == "TEST-DOUBLE")
            #expect(routine.body.count == 1)

            // The body should contain the expanded macro: <+ 5 5>
            guard case .list(let elements, _) = routine.body[0] else {
                Issue.record("Expected list expression in routine body")
                return
            }

            // Verify macro was expanded to <+ 5 5>
            #expect(elements.count == 3)
            guard case .atom(let op, _) = elements[0] else {
                Issue.record("Expected atom for operator")
                return
            }
            #expect(op == "+")
            guard case .number(let num1, _) = elements[1] else {
                Issue.record("Expected number")
                return
            }
            #expect(num1 == 5)
            guard case .number(let num2, _) = elements[2] else {
                Issue.record("Expected number")
                return
            }
            #expect(num2 == 5)
        }

        @Test("Simple DEFMAC with no parameters")
        func simpleDefmacWithNoParameters() throws {
            let source = "<DEFMAC RFATAL () <FORM TELL \"Fatal error.\" CR>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "RFATAL")
            #expect(defmac.parameters.isEmpty)
            #expect(defmac.parameterNames.isEmpty)
            #expect(!defmac.hasVariableArgs)

            // Verify body is a FORM expression
            guard case .list(let elements, _) = defmac.body else {
                Issue.record("Expected list expression for body")
                return
            }
            guard case .atom(let formName, _) = elements.first else {
                Issue.record("Expected FORM atom")
                return
            }
            #expect(formName == "FORM")
        }

        @Test("DEFMAC with ARGS parameter")
        func defmacWithArgsParameter() throws {
            let source = #"<DEFMAC TELL ("ARGS" A) <FORM PRINTI !.A>>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "TELL")
            #expect(defmac.parameters.count == 1)
            #expect(defmac.hasVariableArgs)

            guard case .variableArgs(let name) = defmac.parameters[0] else {
                Issue.record("Expected variableArgs parameter")
                return
            }
            #expect(name == "A")
            #expect(defmac.parameterNames == ["A"])
        }

        @Test("DEFMAC with quoted parameter")
        func defmacWithQuotedParameter() throws {
            let source = "<DEFMAC ENABLE ('INT) <FORM PUT .INT ,C-ENABLED? 1>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "ENABLE")
            #expect(defmac.parameters.count == 1)

            guard case .quoted(let name) = defmac.parameters[0] else {
                Issue.record("Expected quoted parameter")
                return
            }
            #expect(name == "INT")
            #expect(defmac.parameterNames == ["INT"])
        }

        @Test("DEFMAC with quoted parameter and ARGS")
        func defmacWithQuotedParameterAndArgs() throws {
            let source = #"<DEFMAC BSET ('OBJ "ARGS" BITS) <FORM FSET .OBJ !.BITS>>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "BSET")
            #expect(defmac.parameters.count == 2)
            #expect(defmac.hasVariableArgs)

            // First parameter should be quoted
            guard case .quoted(let objName) = defmac.parameters[0] else {
                Issue.record("Expected first parameter to be quoted")
                return
            }
            #expect(objName == "OBJ")

            // Second parameter should be variableArgs
            guard case .variableArgs(let bitsName) = defmac.parameters[1] else {
                Issue.record("Expected second parameter to be variableArgs")
                return
            }
            #expect(bitsName == "BITS")

            #expect(defmac.parameterNames == ["OBJ", "BITS"])
        }

        @Test("DEFMAC with OPTIONAL parameter")
        func defmacWithOptionalParameter() throws {
            let source = "<DEFMAC PROB ('BASE? \"OPTIONAL\" 'LOSER?) <FORM COND>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "PROB")
            #expect(defmac.parameters.count == 2)

            // First parameter should be quoted
            guard case .quoted(let baseName) = defmac.parameters[0] else {
                Issue.record("Expected first parameter to be quoted")
                return
            }
            #expect(baseName == "BASE?")

            // Second parameter should be optional
            guard case .optional(let loserName, let defaultValue) = defmac.parameters[1] else {
                Issue.record("Expected second parameter to be optional")
                return
            }
            #expect(loserName == "LOSER?")
            // Optional parameter without explicit default should have nil default
            #expect(defaultValue == nil)

            #expect(defmac.parameterNames == ["BASE?", "LOSER?"])
        }

        @Test("DEFMAC with standard parameters")
        func defmacWithStandardParameters() throws {
            let source = "<DEFMAC ADD-ONE (X) <FORM + .X 1>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "ADD-ONE")
            #expect(defmac.parameters.count == 1)

            guard case .standard(let name) = defmac.parameters[0] else {
                Issue.record("Expected standard parameter")
                return
            }
            #expect(name == "X")
        }

        @Test("DEFMAC with multiple standard parameters")
        func defmacWithMultipleStandardParameters() throws {
            let source = "<DEFMAC MAX-TWO (A B) <FORM COND (<FORM G? .A .B> .A) (ELSE .B)>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "MAX-TWO")
            #expect(defmac.parameters.count == 2)

            guard case .standard(let aName) = defmac.parameters[0] else {
                Issue.record("Expected first parameter to be standard")
                return
            }
            #expect(aName == "A")

            guard case .standard(let bName) = defmac.parameters[1] else {
                Issue.record("Expected second parameter to be standard")
                return
            }
            #expect(bName == "B")
        }

        @Test("DEFMAC error - ARGS after OPTIONAL")
        func defmacErrorArgsAfterOptional() throws {
            let source = #"<DEFMAC BAD ("OPTIONAL" X "ARGS" Y) <FORM FOO>>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("DEFMAC error - quoted parameter after OPTIONAL")
        func defmacErrorQuotedAfterOptional() throws {
            let source = "<DEFMAC BAD (\"OPTIONAL\" X 'Y) <FORM FOO>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("DEFMAC error - standard parameter after OPTIONAL")
        func defmacErrorStandardAfterOptional() throws {
            let source = "<DEFMAC BAD (\"OPTIONAL\" X Y) <FORM FOO>>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("DEFMAC error - multiple ARGS parameters")
        func defmacErrorMultipleArgs() throws {
            let source = #"<DEFMAC BAD ("ARGS" X "ARGS" Y) <FORM FOO>>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("DEFMAC complex from real Zork")
        func defmacComplexFromRealZork() throws {
            // Real VERB? macro from Zork 1
            let source = #"<DEFMAC VERB? ("ARGS" ATMS) <MULTIFROB PRSA .ATMS>>"#
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .defmac(let defmac) = declarations[0] else {
                Issue.record("Expected DEFMAC declaration")
                return
            }

            #expect(defmac.name == "VERB?")
            #expect(defmac.hasVariableArgs)

            // Verify body structure
            guard case .list(let elements, _) = defmac.body else {
                Issue.record("Expected list expression for body")
                return
            }
            guard case .atom(let funcName, _) = elements.first else {
                Issue.record("Expected atom for function name")
                return
            }
            #expect(funcName == "MULTIFROB")
        }
    }

    @Suite("SYNONYM Declaration Parsing")
    struct SynonymDeclarationTests {
        @Test("Simple SYNONYM with one synonym")
        func simpleSynonymWithOneSynonym() throws {
            let source = "<SYNONYM NORTH N>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "NORTH")
            #expect(synonym.words == ["N"])
        }

        @Test("SYNONYM with multiple synonyms")
        func synonymWithMultipleSynonyms() throws {
            let source = "<SYNONYM TAKE CARRY GET HOLD>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "TAKE")
            #expect(synonym.words == ["CARRY", "GET", "HOLD"])
        }

        @Test("SYNONYM from real game - direction")
        func synonymFromRealGameDirection() throws {
            let source = "<SYNONYM DOWN D DOWNSTAIRS>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "DOWN")
            #expect(synonym.words == ["D", "DOWNSTAIRS"])
        }

        @Test("SYNONYM error - too few words")
        func synonymErrorTooFewWords() throws {
            let source = "<SYNONYM TAKE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("SYNONYM error - no words")
        func synonymErrorNoWords() throws {
            let source = "<SYNONYM>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }
    }

    @Suite("BUZZ Declaration Parsing")
    struct BuzzDeclarationTests {
        @Test("Simple BUZZ with few words")
        func simpleBuzzWithFewWords() throws {
            let source = "<BUZZ A AN THE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .buzz(let buzz) = declarations[0] else {
                Issue.record("Expected BUZZ declaration")
                return
            }

            #expect(buzz.words == ["A", "AN", "THE"])
        }

        @Test("BUZZ with many words")
        func buzzWithManyWords() throws {
            let source = "<BUZZ A AN THE IS AND OF THEN ALL ONE BUT EXCEPT>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .buzz(let buzz) = declarations[0] else {
                Issue.record("Expected BUZZ declaration")
                return
            }

            #expect(buzz.words.count == 11)  // A, AN, THE, IS, AND, OF, THEN, ALL, ONE, BUT, EXCEPT
            #expect(buzz.words.contains("A"))
            #expect(buzz.words.contains("THE"))
            #expect(buzz.words.contains("EXCEPT"))
        }

        @Test("BUZZ from real game - Zork 1")
        func buzzFromRealGameZork1() throws {
            let source = "<BUZZ AGAIN G OOPS>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .buzz(let buzz) = declarations[0] else {
                Issue.record("Expected BUZZ declaration")
                return
            }

            #expect(buzz.words == ["AGAIN", "G", "OOPS"])
        }

        @Test("BUZZ with comments")
        func buzzWithComments() throws {
            let source = """
            <BUZZ A AN THE ; articles
                  AND OR ; conjunctions
                  PLEASE> ; politeness
            """
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .buzz(let buzz) = declarations[0] else {
                Issue.record("Expected BUZZ declaration")
                return
            }

            // Comments should be skipped
            #expect(buzz.words == ["A", "AN", "THE", "AND", "OR", "PLEASE"])
        }

        @Test("BUZZ error - no words")
        func buzzErrorNoWords() throws {
            let source = "<BUZZ>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }
    }

    @Suite("Part-of-Speech SYNONYM Declaration Parsing")
    struct PartOfSpeechSynonymTests {

        @Test("PREP-SYNONYM from Stationfall")
        func prepSynonymFromStationfall() throws {
            let source = "<PREP-SYNONYM TO TOWARD>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "TO")
            #expect(synonym.words == ["TOWARD"])
            #expect(synonym.type == .preposition)
        }

        @Test("PREP-SYNONYM with multiple synonyms")
        func prepSynonymWithMultipleSynonyms() throws {
            let source = "<PREP-SYNONYM IN INSIDE INTO>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "IN")
            #expect(synonym.words == ["INSIDE", "INTO"])
            #expect(synonym.type == .preposition)
        }

        @Test("PREP-SYNONYM from Sherlock")
        func prepSynonymFromSherlock() throws {
            let source = "<PREP-SYNONYM UNDER BELOW BENEATH UNDERNEATH>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "UNDER")
            #expect(synonym.words == ["BELOW", "BENEATH", "UNDERNEATH"])
            #expect(synonym.type == .preposition)
        }

        @Test("VERB-SYNONYM basic")
        func verbSynonymBasic() throws {
            let source = "<VERB-SYNONYM TAKE GET GRAB>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "TAKE")
            #expect(synonym.words == ["GET", "GRAB"])
            #expect(synonym.type == .verb)
        }

        @Test("VERB-SYNONYM single synonym")
        func verbSynonymSingle() throws {
            let source = "<VERB-SYNONYM EXAMINE X>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "EXAMINE")
            #expect(synonym.words == ["X"])
            #expect(synonym.type == .verb)
        }

        @Test("ADJ-SYNONYM from real game")
        func adjSynonymFromRealGame() throws {
            let source = "<ADJ-SYNONYM BRASS BRONZE>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 1)
            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "BRASS")
            #expect(synonym.words == ["BRONZE"])
            #expect(synonym.type == .adjective)
        }

        @Test("ADJ-SYNONYM with multiple synonyms")
        func adjSynonymWithMultipleSynonyms() throws {
            let source = "<ADJ-SYNONYM RED SCARLET CRIMSON>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            guard case .synonym(let synonym) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }

            #expect(synonym.canonical == "RED")
            #expect(synonym.words == ["SCARLET", "CRIMSON"])
            #expect(synonym.type == .adjective)
        }

        @Test("Mixed synonym types in same file")
        func mixedSynonymTypes() throws {
            let source = """
            <SYNONYM NORTH N>
            <PREP-SYNONYM WITH USING>
            <VERB-SYNONYM DROP DISCARD>
            <ADJ-SYNONYM SMALL TINY>
            """
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            let declarations = try parser.parseProgram()

            #expect(declarations.count == 4)

            // Check first: generic SYNONYM
            guard case .synonym(let syn1) = declarations[0] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }
            #expect(syn1.type == .generic)
            #expect(syn1.canonical == "NORTH")

            // Check second: PREP-SYNONYM
            guard case .synonym(let syn2) = declarations[1] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }
            #expect(syn2.type == .preposition)
            #expect(syn2.canonical == "WITH")

            // Check third: VERB-SYNONYM
            guard case .synonym(let syn3) = declarations[2] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }
            #expect(syn3.type == .verb)
            #expect(syn3.canonical == "DROP")

            // Check fourth: ADJ-SYNONYM
            guard case .synonym(let syn4) = declarations[3] else {
                Issue.record("Expected SYNONYM declaration")
                return
            }
            #expect(syn4.type == .adjective)
            #expect(syn4.canonical == "SMALL")
        }

        @Test("PREP-SYNONYM error - too few words")
        func prepSynonymErrorTooFewWords() throws {
            let source = "<PREP-SYNONYM WITH>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("VERB-SYNONYM error - no words")
        func verbSynonymErrorNoWords() throws {
            let source = "<VERB-SYNONYM>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
            }
        }

        @Test("ADJ-SYNONYM error - too few words")
        func adjSynonymErrorTooFewWords() throws {
            let source = "<ADJ-SYNONYM BRASS>"
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer, filePath: "test.zil")

            #expect(throws: ParseError.self) {
                _ = try parser.parseProgram()
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
