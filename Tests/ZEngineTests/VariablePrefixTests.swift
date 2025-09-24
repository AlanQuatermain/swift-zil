import Testing
@testable import ZEngine

@Suite("Variable Prefix Parsing Tests")
struct VariablePrefixTests {

    @Test("Comma-prefixed variables are parsed as global variables")
    func commaPrefixedGlobalVariables() throws {
        let testCases = [
            ",WINNER",
            ",SCORE",
            ",PLAYER-LOC",
            ",HERE",
            ",LAMP-ON",
            ",GLOBAL-VAR"
        ]

        for source in testCases {
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            guard case .globalVariable(let name, let location) = expression else {
                #expect(Bool(false), "'\(source)' should parse as globalVariable, got: \(expression)")
                continue
            }

            let expectedName = String(source.dropFirst()) // Remove comma prefix
            #expect(name == expectedName, "Global variable name: expected '\(expectedName)', got '\(name)'")
            #expect(location.file == "test.zil", "Source location should be preserved")
        }
    }

    @Test("Period-prefixed variables are parsed as local variables")
    func periodPrefixedLocalVariables() throws {
        let testCases = [
            ".TEMP",
            ".VAL",
            ".COUNT",
            ".LOCAL-VAR",
            ".RESULT",
            ".AUX-VAR"
        ]

        for source in testCases {
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            guard case .localVariable(let name, let location) = expression else {
                #expect(Bool(false), "'\(source)' should parse as localVariable, got: \(expression)")
                continue
            }

            let expectedName = String(source.dropFirst()) // Remove period prefix
            #expect(name == expectedName, "Local variable name: expected '\(expectedName)', got '\(name)'")
            #expect(location.file == "test.zil", "Source location should be preserved")
        }
    }

    @Test("Variables in complex expressions maintain prefix semantics")
    func variablePrefixInComplexExpressions() throws {
        let source = """
        <ROUTINE TEST-VARS ("AUX" LOCAL-VAR)
            <SET LOCAL-VAR ,GLOBAL-VAR>
            <SETG GLOBAL-VAR .LOCAL-VAR>
            <RETURN <+ ,SCORE .TEMP>>>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let declarations = try parser.parseProgram()

        #expect(declarations.count == 1)

        guard case .routine(let routine) = declarations[0] else {
            #expect(Bool(false), "Should be a routine")
            return
        }

        // Find all variable references in the routine body
        func findVariableReferences(_ expr: ZILExpression) -> [(type: String, name: String)] {
            switch expr {
            case .localVariable(let name, _):
                return [("local", name)]
            case .globalVariable(let name, _):
                return [("global", name)]
            case .list(let elements, _):
                return elements.flatMap(findVariableReferences)
            default:
                return []
            }
        }

        let allVarRefs = routine.body.flatMap(findVariableReferences)

        // Verify we have both global and local variable references
        let globalRefs = allVarRefs.filter { $0.type == "global" }
        let localRefs = allVarRefs.filter { $0.type == "local" }

        #expect(globalRefs.count >= 2, "Should find global variable references")
        #expect(localRefs.count >= 1, "Should find local variable references")

        // Verify specific variables are categorized correctly
        #expect(globalRefs.contains { $0.name == "GLOBAL-VAR" }, "Should find ,GLOBAL-VAR as global")
        #expect(globalRefs.contains { $0.name == "SCORE" }, "Should find ,SCORE as global")
        #expect(localRefs.contains { $0.name == "LOCAL-VAR" }, "Should find .LOCAL-VAR as local")
        #expect(localRefs.contains { $0.name == "TEMP" }, "Should find .TEMP as local")
    }

    @Test("Mixed variable types in arithmetic expressions")
    func mixedVariableTypesInArithmetic() throws {
        let source = "<SET .LOCAL-VAR <+ ,GLOBAL1 <- ,GLOBAL2 .LOCAL2>>>"

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let expression = try parser.parseExpression()

        // Navigate into the nested arithmetic expression
        guard case .list(let setElements, _) = expression,
              setElements.count == 3,
              case .localVariable(let localVarName, _) = setElements[1],
              case .list = setElements[2] else {
            #expect(Bool(false), "Should parse as SET expression with local variable and arithmetic")
            return
        }

        #expect(localVarName == "LOCAL-VAR", "SET target should be local variable")

        // Verify the arithmetic expression contains both global and local variables
        func findVarTypes(_ expr: ZILExpression) -> [String] {
            switch expr {
            case .globalVariable(_, _): return ["global"]
            case .localVariable(_, _): return ["local"]
            case .list(let elements, _): return elements.flatMap(findVarTypes)
            default: return []
            }
        }

        let varTypes = findVarTypes(setElements[2])
        #expect(varTypes.contains("global"), "Should contain global variables")
        #expect(varTypes.contains("local"), "Should contain local variables")
    }

    @Test("Variable prefix semantics in conditional expressions")
    func variablePrefixInConditionals() throws {
        let source = """
        <COND (<EQUAL? ,PLAYER-LOC ,LIVING-ROOM>
               <SET .TEMP <GETP ,PLAYER ,P?STRENGTH>>
               <COND (<G? .TEMP 10>
                      <TELL "You are strong!" CR>)>)>
        """

        let lexer = ZILLexer(source: source, filename: "test.zil")
        let parser = try ZILParser(lexer: lexer)
        let expression = try parser.parseExpression()

        // Count variable references by type
        func countVariablesByType(_ expr: ZILExpression) -> (globals: Int, locals: Int) {
            switch expr {
            case .globalVariable(_, _):
                return (1, 0)
            case .localVariable(_, _):
                return (0, 1)
            case .list(let elements, _):
                let counts = elements.map(countVariablesByType)
                let totalGlobals = counts.reduce(0) { $0 + $1.globals }
                let totalLocals = counts.reduce(0) { $0 + $1.locals }
                return (totalGlobals, totalLocals)
            default:
                return (0, 0)
            }
        }

        let (globalCount, localCount) = countVariablesByType(expression)

        #expect(globalCount >= 3, "Should find multiple global variables (,PLAYER-LOC, ,LIVING-ROOM, ,PLAYER, ,P?STRENGTH)")
        #expect(localCount >= 2, "Should find local variables (.TEMP used multiple times)")
    }

    @Test("Error case: variables without proper prefixes")
    func unprefixedVariablesToAtoms() throws {
        // Variables without comma or period should be parsed as atoms, not variables
        let testCases = ["WINNER", "TEMP", "SCORE", "GLOBAL-VAR"]

        for source in testCases {
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            guard case .atom(let name, _) = expression else {
                #expect(Bool(false), "'\(source)' without prefix should parse as atom, got: \(expression)")
                continue
            }

            #expect(name == source, "Atom name should match source: expected '\(source)', got '\(name)'")
        }
    }

    @Test("Property and flag references maintain distinct semantics")
    func propertyAndFlagReferences() throws {
        let testCases: [(String, String)] = [
            ("P?DESC", "DESC"),
            ("P?ACTION", "ACTION"),
            ("P?STRENGTH", "STRENGTH"),
            ("F?TAKEBIT", "TAKEBIT"),
            ("F?LIGHTBIT", "LIGHTBIT"),
            ("F?ONBIT", "ONBIT")
        ]

        for (source, expectedName) in testCases {
            let lexer = ZILLexer(source: source, filename: "test.zil")
            let parser = try ZILParser(lexer: lexer)

            let expression = try parser.parseExpression()

            if source.hasPrefix("P?") {
                guard case .propertyReference(let name, _) = expression else {
                    #expect(Bool(false), "'\(source)' should parse as propertyReference, got: \(expression)")
                    continue
                }
                #expect(name == expectedName, "Property name: expected '\(expectedName)', got '\(name)'")
            } else if source.hasPrefix("F?") {
                guard case .flagReference(let name, _) = expression else {
                    #expect(Bool(false), "'\(source)' should parse as flagReference, got: \(expression)")
                    continue
                }
                #expect(name == expectedName, "Flag name: expected '\(expectedName)', got '\(name)'")
            }
        }
    }
}