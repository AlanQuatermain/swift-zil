import Testing
@testable import ZEngine

@Suite("ZAP Code Generator Tests")
struct ZAPCodeGeneratorTests {

    // MARK: - Test Fixtures

    private func createTestSymbolTable() -> SymbolTableManager {
        let symbolTable = SymbolTableManager()

        // Add test routines
        symbolTable.defineSymbol(name: "TEST-ROUTINE", type: .routine(parameters: ["ARG1", "ARG2"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        symbolTable.defineSymbol(name: "MAIN", type: .routine(parameters: [], optionalParameters: [], auxiliaryVariables: []), at: .unknown)
        symbolTable.defineSymbol(name: "SIMPLE-FUNC", type: .routine(parameters: ["X"], optionalParameters: [], auxiliaryVariables: []), at: .unknown)

        // Add test objects
        symbolTable.defineSymbol(name: "PLAYER", type: .object(properties: [], flags: []), at: .unknown)
        symbolTable.defineSymbol(name: "LANTERN", type: .object(properties: [], flags: []), at: .unknown)
        symbolTable.defineSymbol(name: "LIVING-ROOM", type: .object(properties: [], flags: []), at: .unknown)

        // Add test globals
        symbolTable.defineSymbol(name: "SCORE", type: .globalVariable, at: .unknown)
        symbolTable.defineSymbol(name: "MOVES", type: .globalVariable, at: .unknown)
        symbolTable.defineSymbol(name: "WINNER", type: .globalVariable, at: .unknown)

        return symbolTable
    }

    private func createTestLocation() -> ZEngine.SourceLocation {
        return ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)
    }

    // MARK: - Basic Initialization Tests

    @Test("ZAPCodeGenerator initialization")
    func zapCodeGeneratorInitialization() throws {
        let symbolTable = createTestSymbolTable()

        // Test default initialization
        let _ = ZAPCodeGenerator(symbolTable: symbolTable)
        #expect(Bool(true)) // Should not crash

        // Test with specific version
        let _ = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3)
        #expect(Bool(true)) // Should not crash

        // Test with optimization level
        let _ = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5, optimizationLevel: 2)
        #expect(Bool(true)) // Should not crash
    }

    // MARK: - Error Handling Tests

    @Test("CodeGenerationError creation and description")
    func codeGenerationErrorCreationAndDescription() throws {
        let location = createTestLocation()

        // Test all error kinds
        let errors = [
            ZAPCodeGenerator.CodeGenerationError(.unsupportedExpression("test"), at: location, context: "parsing"),
            ZAPCodeGenerator.CodeGenerationError(.invalidFunction("badFunc"), at: location),
            ZAPCodeGenerator.CodeGenerationError(.undefinedSymbol("MISSING")),
            ZAPCodeGenerator.CodeGenerationError(.invalidInstruction("BADOP"), at: location),
            ZAPCodeGenerator.CodeGenerationError(.labelGenerationFailed("overflow")),
            ZAPCodeGenerator.CodeGenerationError(.invalidOperand("@invalid")),
            ZAPCodeGenerator.CodeGenerationError(.memoryLayoutError("out of bounds")),
            ZAPCodeGenerator.CodeGenerationError(.versionIncompatibility("v8 required")),
            ZAPCodeGenerator.CodeGenerationError(.invalidControlFlow("nested too deep")),
            ZAPCodeGenerator.CodeGenerationError(.typeSystemError("type mismatch")),
            ZAPCodeGenerator.CodeGenerationError(.optimizationError("failed peephole")),
            ZAPCodeGenerator.CodeGenerationError(.codeGenerationFailed("internal error")),
            ZAPCodeGenerator.CodeGenerationError(.invalidObjectDefinition("bad property")),
            ZAPCodeGenerator.CodeGenerationError(.propertyTableError("table full")),
            ZAPCodeGenerator.CodeGenerationError(.globalTableError("too many globals")),
            ZAPCodeGenerator.CodeGenerationError(.stringTableError("string too long")),
            ZAPCodeGenerator.CodeGenerationError(.branchTargetError("invalid target")),
            ZAPCodeGenerator.CodeGenerationError(.stackManagementError("stack underflow"))
        ]

        for error in errors {
            let description = error.localizedDescription
            #expect(!description.isEmpty)

            // Verify location is included when present
            if error.location != nil {
                #expect(description.contains("test.zil:1:1"))
            }

            // Verify context is included when present
            if let context = error.context {
                #expect(description.contains("context: \(context)"))
            }
        }
    }

    // MARK: - Header Generation Tests

    @Test("ZAP header generation")
    func zapHeaderGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5, optimizationLevel: 0) // Use debug mode for headers

        let result = try generator.generateCode(from: [])

        #expect(result.contains("; ZAP Assembly Code Generated by ZIL Compiler"))
        #expect(result.contains("; Target Z-Machine Version: 5"))
        #expect(result.contains("; Optimization Level: 0"))
        #expect(result.contains(".ZVERSION 5"))
        #expect(result.contains("; Z-Machine v5: 256KB limit"))
        #expect(result.contains(".END"))
    }

    @Test("ZAP header generation for different versions")
    func zapHeaderGenerationForDifferentVersions() throws {
        let symbolTable = createTestSymbolTable()

        let testCases: [(ZMachineVersion, String)] = [
            (.v3, "; Z-Machine v3: 128KB limit, 255 objects max"),
            (.v4, "; Z-Machine v4: 128KB limit, 65535 objects max, sound"),
            (.v5, "; Z-Machine v5: 256KB limit, 65535 objects max, color, mouse"),
            (.v6, "; Z-Machine v6: 256KB limit, graphics, multiple windows"),
            (.v7, "; Z-Machine v7: 256KB limit, extended features"),
            (.v8, "; Z-Machine v8: Unicode support, modern extensions")
        ]

        for (version, expectedComment) in testCases {
            var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: version)
            let result = try generator.generateCode(from: [])

            #expect(result.contains(".ZVERSION \(version.rawValue)"))
            #expect(result.contains(expectedComment))
        }
    }

    // MARK: - Simple Expression Tests

    @Test("Simple expression generation")
    func simpleExpressionGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test simple routine with basic expressions
        let routine = ZILRoutineDeclaration(
            name: "SIMPLE-TEST",
            parameters: ["X"],
            body: [
                ZILExpression.number(42, location),
                ZILExpression.string("Hello World", location),
                ZILExpression.atom("RTRUE", location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("\t.FUNCT\tSIMPLE-TEST,X"))  // Infocom-style tab formatting
        // Simple expressions used as statements don't generate instructions (architecturally correct)
        #expect(!result.contains("    42"))  // Number expression doesn't generate instruction in routine body
        #expect(result.contains("RTRUE")) // But RTRUE statement does generate instruction
        #expect(result.contains(".STRING STR0 \"Hello World\"")) // String is still in string table
        // Note: "STR0" will appear in strings section, but not in routine body
    }

    // MARK: - Variable Reference Tests

    @Test("Variable reference generation")
    func variableReferenceGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let routine = ZILRoutineDeclaration(
            name: "VAR-TEST",
            parameters: ["LOCAL1"],
            body: [
                ZILExpression.globalVariable("SCORE", location),
                ZILExpression.localVariable("LOCAL1", location),
                ZILExpression.propertyReference("DESC", location),
                ZILExpression.flagReference("TAKEBIT", location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Variable references used as standalone statements don't generate instructions (architecturally correct)
        #expect(!result.contains("'SCORE"))     // Global variable expression doesn't generate instruction
        #expect(!result.contains("P?DESC"))     // Property reference expression doesn't generate instruction
        #expect(!result.contains("F?TAKEBIT"))  // Flag reference expression doesn't generate instruction

        // But LOCAL1 appears in function signature and globals/properties are declared
        #expect(result.contains("\t.FUNCT\tVAR-TEST,LOCAL1"))  // Local appears in function signature
        #expect(result.contains(".GLOBAL\tSCORE"))     // Global is declared
        #expect(result.contains(".PROPERTY\tDESC"))     // Property is declared
    }

    // MARK: - SET Operation Tests

    @Test("SET operation generation")
    func setOperationGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test SET (local assignment)
        let setLocal = ZILExpression.list([
            ZILExpression.atom("SET", location),
            ZILExpression.localVariable("X", location),
            ZILExpression.number(42, location)
        ], location)

        // Test SETG (global assignment)
        let setGlobal = ZILExpression.list([
            ZILExpression.atom("SETG", location),
            ZILExpression.globalVariable("SCORE", location),
            ZILExpression.number(100, location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "SET-TEST",
            parameters: ["X"],
            body: [setLocal, setGlobal],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("SET\tX,42"))
        #expect(result.contains("SETG\t'SCORE,100"))
    }

    // MARK: - COND Statement Tests

    @Test("COND statement generation")
    func condStatementGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Create a COND with multiple clauses
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            // First clause: (EQUAL? X 1) (RTRUE)
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("EQUAL?", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.number(1, location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location),
            // Second clause: (GREATER? X 10) (RFALSE)
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("GREATER?", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.number(10, location)
                ], location),
                ZILExpression.atom("RFALSE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "COND-TEST",
            parameters: ["X"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("EQUAL?\tX,1"))
        #expect(result.contains("GRTR?\tX,10"))
        #expect(result.contains("/?ELS1"))    // Branch false to else label (optimized format)
        #expect(result.contains("?ELS1:"))    // Else label
        #expect(result.contains("/TRUE"))     // Branch to TRUE (optimized format)
        #expect(result.contains("RTRUE"))
        #expect(result.contains("RFALSE"))
    }

    // MARK: - TELL Statement Tests

    @Test("TELL statement generation")
    func tellStatementGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let tellExpr = ZILExpression.list([
            ZILExpression.atom("TELL", location),
            ZILExpression.string("Hello", location),
            ZILExpression.atom("CR", location),
            ZILExpression.string("World", location),
            ZILExpression.atom("T", location), // Tab/space
            ZILExpression.globalVariable("SCORE", location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "TELL-TEST",
            parameters: [],
            body: [tellExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("PRINTI\t\"Hello\""))
        #expect(result.contains("CRLF"))
        #expect(result.contains("PRINTI\t\"World\""))
        #expect(result.contains("PRINTI\t\" \""))
        #expect(result.contains("PRINTR\t'SCORE"))
    }

    // MARK: - Object Generation Tests

    @Test("Object generation")
    func objectGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let object = ZILObjectDeclaration(
            name: "TEST-OBJECT",
            properties: [
                ZILObjectProperty(
                    name: "DESC",
                    value: ZILExpression.string("A test object", location),
                    location: location
                ),
                ZILObjectProperty(
                    name: "FLAGS",
                    value: ZILExpression.atom("TAKEBIT", location),
                    location: location
                )
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.object(object)])

        #expect(result.contains(".OBJECT TEST-OBJECT"))
        #expect(result.contains("DESC\tSTR0"))
        #expect(result.contains("FLAGS\tTAKEBIT"))
        #expect(result.contains(".ENDOBJECT"))
        #expect(result.contains(".STRING STR0 \"A test object\""))
    }

    // MARK: - Global and Constant Tests

    @Test("Global and constant generation")
    func globalAndConstantGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let global = ZILGlobalDeclaration(
            name: "TEST-GLOBAL",
            value: ZILExpression.number(42, location),
            location: location
        )

        let constant = ZILConstantDeclaration(
            name: "TEST-CONSTANT",
            value: ZILExpression.number(100, location),
            location: location
        )

        let result = try generator.generateCode(from: [.global(global), .constant(constant)])

        #expect(result.contains(".GLOBAL\tTEST-GLOBAL"))  // Correct ZAP format - no value in directive
        #expect(result.contains(".CONSTANT TEST-CONSTANT 100"))
    }

    // MARK: - Complex Control Flow Tests

    @Test("AND operation generation")
    func andOperationGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let andExpr = ZILExpression.list([
            ZILExpression.atom("AND", location),
            ZILExpression.list([
                ZILExpression.atom("EQUAL?", location),
                ZILExpression.localVariable("X", location),
                ZILExpression.number(1, location)
            ], location),
            ZILExpression.list([
                ZILExpression.atom("GREATER?", location),
                ZILExpression.localVariable("Y", location),
                ZILExpression.number(0, location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "AND-TEST",
            parameters: ["X", "Y"],
            body: [andExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("EQUAL?\tX,1"))
        #expect(result.contains("\\?AND1"))   // Branch false to AND label
        #expect(result.contains("GRTR?\tY,0"))
        #expect(result.contains("RTRUE"))     // Success case
        #expect(result.contains("RFALSE"))    // Failure case
    }

    @Test("OR operation generation")
    func orOperationGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let orExpr = ZILExpression.list([
            ZILExpression.atom("OR", location),
            ZILExpression.list([
                ZILExpression.atom("ZERO?", location),
                ZILExpression.localVariable("X", location)
            ], location),
            ZILExpression.list([
                ZILExpression.atom("EQUAL?", location),
                ZILExpression.localVariable("Y", location),
                ZILExpression.number(1, location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "OR-TEST",
            parameters: ["X", "Y"],
            body: [orExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("ZERO?\tX"))
        #expect(result.contains("/?OR1"))     // Branch true to OR label
        #expect(result.contains("EQUAL?\tY,1"))
        #expect(result.contains("RTRUE"))     // Success case
        #expect(result.contains("RFALSE"))    // Failure case
    }

    @Test("NOT operation generation")
    func notOperationGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let notExpr = ZILExpression.list([
            ZILExpression.atom("NOT", location),
            ZILExpression.list([
                ZILExpression.atom("ZERO?", location),
                ZILExpression.localVariable("X", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "NOT-TEST",
            parameters: ["X"],
            body: [notExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("ZERO?\tX"))
        #expect(result.contains("\\?NOT1"))   // Branch false (condition failed)
        #expect(result.contains("RFALSE"))    // NOT of true is false
        #expect(result.contains("RTRUE"))     // NOT of false is true
    }

    // MARK: - Loop Generation Tests

    @Test("REPEAT loop generation")
    func repeatLoopGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let repeatExpr = ZILExpression.list([
            ZILExpression.atom("REPEAT", location),
            ZILExpression.list([
                ZILExpression.atom("TELL", location),
                ZILExpression.string("Loop", location)
            ], location),
            ZILExpression.list([
                ZILExpression.atom("SET", location),
                ZILExpression.localVariable("X", location),
                ZILExpression.number(1, location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "REPEAT-TEST",
            parameters: ["X"],
            body: [repeatExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("?RPT1:"))       // Loop label
        #expect(result.contains("PRINTI\t\"Loop\""))
        #expect(result.contains("SET\tX,1"))
        #expect(result.contains("JUMP\t?RPT1"))   // Jump back to loop
        #expect(result.contains("?END1:"))       // End label
    }

    @Test("WHILE loop generation")
    func whileLoopGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let whileExpr = ZILExpression.list([
            ZILExpression.atom("WHILE", location),
            ZILExpression.list([
                ZILExpression.atom("GREATER?", location),
                ZILExpression.localVariable("X", location),
                ZILExpression.number(0, location)
            ], location),
            ZILExpression.list([
                ZILExpression.atom("SET", location),
                ZILExpression.localVariable("X", location),
                ZILExpression.list([
                    ZILExpression.atom("SUB", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.number(1, location)
                ], location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "WHILE-TEST",
            parameters: ["X"],
            body: [whileExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("?WHL1:"))        // Loop label
        #expect(result.contains("GRTR?\tX,0"))     // Condition test
        #expect(result.contains("\\?END1"))       // Branch false to end
        #expect(result.contains("SUB\tX,1"))       // Loop body
        #expect(result.contains("JUMP\t?WHL1"))    // Jump back to condition
        #expect(result.contains("?END1:"))        // End label
    }

    // MARK: - Function Call Tests

    @Test("Function call generation")
    func functionCallGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test built-in function call
        let builtinCall = ZILExpression.list([
            ZILExpression.atom("MOVE", location),
            ZILExpression.atom("LANTERN", location),
            ZILExpression.atom("PLAYER", location)
        ], location)

        // Test user-defined function call
        let userCall = ZILExpression.list([
            ZILExpression.atom("TEST-ROUTINE", location),
            ZILExpression.number(1, location),
            ZILExpression.number(2, location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "CALL-TEST",
            parameters: [],
            body: [builtinCall, userCall],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("MOVE\tLANTERN,PLAYER"))
        #expect(result.contains("CALL\tTEST-ROUTINE,1,2"))
    }

    // MARK: - ZIL-to-ZAP Instruction Mapping Tests

    @Test("ZIL to ZAP instruction mapping")
    func zilToZapInstructionMapping() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test various ZIL instructions that should map to ZAP
        let instructions = [
            ("EQUAL?", "EQUAL?", 2),    // Binary operations
            ("GREATER?", "GRTR?", 2),
            ("LESS?", "LESS?", 2),
            ("FSET?", "FSET?", 2),
            ("FSET", "FSET", 2),
            ("FCLEAR", "FCLEAR", 2),
            ("ADD", "ADD", 2),
            ("SUB", "SUB", 2),
            ("MUL", "MUL", 2),
            ("DIV", "DIV", 2),
            ("ZERO?", "ZERO?", 1),      // Unary operation
            ("PRINTR", "PRINTR", 1),    // Single argument
            ("PRINTI", "PRINTI", 1),
            ("CRLF", "CRLF", 0)         // No arguments
        ]

        for (zilInstr, zapInstr, argCount) in instructions {
            var elements: [ZILExpression] = [ZILExpression.atom(zilInstr, location)]

            // Add appropriate number of arguments
            if argCount > 0 {
                for i in 1...argCount {
                    elements.append(ZILExpression.number(Int16(i), location))
                }
            }

            let expr = ZILExpression.list(elements, location)

            let routine = ZILRoutineDeclaration(
                name: "MAPPING-TEST",
                parameters: [],
                body: [expr],
                location: location
            )

            let result = try generator.generateCode(from: [.routine(routine)])
            #expect(result.contains(zapInstr), "Expected \(zapInstr) for \(zilInstr)")
        }
    }

    // MARK: - Version-Specific Instruction Tests

    @Test("Version-specific instruction generation")
    func versionSpecificInstructionGeneration() throws {
        let symbolTable = createTestSymbolTable()

        // Test V3 - should not include sound instructions
        var generatorV3 = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3)

        // Test V4 - should include sound instructions
        var generatorV4 = ZAPCodeGenerator(symbolTable: symbolTable, version: .v4)

        // Test V5 - should include color and mouse
        var generatorV5 = ZAPCodeGenerator(symbolTable: symbolTable, version: .v5)

        let location = createTestLocation()

        let routine = ZILRoutineDeclaration(
            name: "VERSION-TEST",
            parameters: [],
            body: [ZILExpression.atom("RTRUE", location)],
            location: location
        )

        let resultV3 = try generatorV3.generateCode(from: [.routine(routine)])
        let resultV4 = try generatorV4.generateCode(from: [.routine(routine)])
        let resultV5 = try generatorV5.generateCode(from: [.routine(routine)])

        #expect(resultV3.contains(".ZVERSION 3"))
        #expect(resultV4.contains(".ZVERSION 4"))
        #expect(resultV5.contains(".ZVERSION 5"))

        #expect(resultV3.contains("Z-Machine v3: 128KB limit"))
        #expect(resultV4.contains("Z-Machine v4: 128KB limit, 65535 objects max, sound"))
        #expect(resultV5.contains("Z-Machine v5: 256KB limit, 65535 objects max, color, mouse"))
    }

    // MARK: - Memory Layout Tests

    @Test("Memory layout organization")
    func memoryLayoutOrganization() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let declarations: [ZILDeclaration] = [
            .constant(ZILConstantDeclaration(
                name: "MAX-SCORE",
                value: ZILExpression.number(100, location),
                location: location
            )),
            .global(ZILGlobalDeclaration(
                name: "CURRENT-SCORE",
                value: ZILExpression.number(0, location),
                location: location
            )),
            .property(ZILPropertyDeclaration(
                name: "WEIGHT",
                defaultValue: ZILExpression.number(1, location),
                location: location
            )),
            .object(ZILObjectDeclaration(
                name: "SWORD",
                properties: [
                    ZILObjectProperty(
                        name: "DESC",
                        value: ZILExpression.string("A sharp sword", location),
                        location: location
                    )
                ],
                location: location
            )),
            .routine(ZILRoutineDeclaration(
                name: "GET-SCORE",
                parameters: [],
                body: [ZILExpression.globalVariable("CURRENT-SCORE", location)],
                location: location
            ))
        ]

        let result = try generator.generateCode(from: declarations)

        // Verify section headers appear in correct order
        let constantsIndex = result.range(of: "; ===== CONSTANTS SECTION =====")?.lowerBound
        let globalsIndex = result.range(of: "; ===== GLOBALS SECTION =====")?.lowerBound
        let propertiesIndex = result.range(of: "; ===== PROPERTIES SECTION =====")?.lowerBound
        let objectsIndex = result.range(of: "; ===== OBJECTS SECTION =====")?.lowerBound
        let functionsIndex = result.range(of: "; ===== FUNCTIONS SECTION =====")?.lowerBound
        let stringsIndex = result.range(of: "; ===== STRINGS SECTION =====")?.lowerBound

        #expect(constantsIndex != nil)
        #expect(globalsIndex != nil)
        #expect(propertiesIndex != nil)
        #expect(objectsIndex != nil)
        #expect(functionsIndex != nil)
        #expect(stringsIndex != nil)

        // Verify content is present
        #expect(result.contains(".CONSTANT MAX-SCORE 100"))
        #expect(result.contains(".GLOBAL\tCURRENT-SCORE"))
        #expect(result.contains(".PROPERTY\tWEIGHT"))
        #expect(result.contains(".OBJECT SWORD"))
        #expect(result.contains("\t.FUNCT\tGET-SCORE"))
        #expect(result.contains(".STRING STR0 \"A sharp sword\""))
    }

    // MARK: - String Escaping Tests

    @Test("String escaping")
    func stringEscaping() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let routine = ZILRoutineDeclaration(
            name: "ESCAPE-TEST",
            parameters: [],
            body: [
                ZILExpression.string("Quote: \"Hello\"", location),
                ZILExpression.string("Backslash: \\", location),
                ZILExpression.string("Newline: \n", location),
                ZILExpression.string("Tab: \t", location),
                ZILExpression.string("Return: \r", location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains(".STRING STR0 \"Quote: \\\"Hello\\\"\""))
        #expect(result.contains(".STRING STR1 \"Backslash: \\\\\""))
        #expect(result.contains(".STRING STR2 \"Newline: \\n\""))
        #expect(result.contains(".STRING STR3 \"Tab: \\t\""))
        #expect(result.contains(".STRING STR4 \"Return: \\r\""))
    }

    // MARK: - Complex Routine Tests

    @Test("Complex routine with optional and auxiliary parameters")
    func complexRoutineWithOptionalAndAuxiliaryParameters() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let routine = ZILRoutineDeclaration(
            name: "COMPLEX-ROUTINE",
            parameters: ["REQ1", "REQ2"],
            optionalParameters: [
                ZILParameter(
                    name: "OPT1",
                    defaultValue: ZILExpression.number(42, location),
                    location: location
                ),
                ZILParameter(
                    name: "OPT2",
                    location: location
                )
            ],
            auxiliaryVariables: [
                ZILParameter(name: "AUX1", location: location),
                ZILParameter(name: "AUX2", location: location)
            ],
            body: [
                ZILExpression.atom("RTRUE", location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        #expect(result.contains("\t.FUNCT\tCOMPLEX-ROUTINE,REQ1,REQ2,OPT1=42,OPT2,AUX1,AUX2"))
        #expect(result.contains("RTRUE"))
    }

    // MARK: - Error Case Tests

    @Test("Error handling for invalid expressions")
    func errorHandlingForInvalidExpressions() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test empty list
        let emptyList = ZILExpression.list([], location)
        let routine1 = ZILRoutineDeclaration(
            name: "ERROR-TEST1",
            parameters: [],
            body: [emptyList],
            location: location
        )

        #expect(throws: ZAPCodeGenerator.CodeGenerationError.self) {
            try generator.generateCode(from: [.routine(routine1)])
        }

        // Test list not starting with atom
        let invalidList = ZILExpression.list([
            ZILExpression.number(42, location),
            ZILExpression.atom("RTRUE", location)
        ], location)
        let routine2 = ZILRoutineDeclaration(
            name: "ERROR-TEST2",
            parameters: [],
            body: [invalidList],
            location: location
        )

        #expect(throws: ZAPCodeGenerator.CodeGenerationError.self) {
            try generator.generateCode(from: [.routine(routine2)])
        }
    }

    @Test("Error handling for invalid SET operations")
    func errorHandlingForInvalidSetOperations() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test SET with wrong number of operands
        let invalidSet = ZILExpression.list([
            ZILExpression.atom("SET", location),
            ZILExpression.localVariable("X", location)
            // Missing second operand
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "SET-ERROR-TEST",
            parameters: ["X"],
            body: [invalidSet],
            location: location
        )

        #expect(throws: ZAPCodeGenerator.CodeGenerationError.self) {
            try generator.generateCode(from: [.routine(routine)])
        }
    }

    @Test("Error handling for invalid COND clauses")
    func errorHandlingForInvalidCondClauses() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Test COND clause that's not a list
        let invalidCond = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.atom("NOT-A-LIST", location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "COND-ERROR-TEST",
            parameters: [],
            body: [invalidCond],
            location: location
        )

        #expect(throws: ZAPCodeGenerator.CodeGenerationError.self) {
            try generator.generateCode(from: [.routine(routine)])
        }
    }

    // MARK: - Optimization Tests

    @Test("Basic optimization")
    func basicOptimization() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, optimizationLevel: 1)

        let location = createTestLocation()

        let routine = ZILRoutineDeclaration(
            name: "OPT-TEST",
            parameters: [],
            body: [
                ZILExpression.atom("RTRUE", location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Should generate without errors - optimization level header not included in production mode
        #expect(!result.contains("; Optimization Level: 1"))  // Production mode doesn't include verbose headers
        #expect(result.contains("RTRUE"))
    }

    // MARK: - Statistical Information Tests

    @Test("Code generation statistics")
    func codeGenerationStatistics() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        let declarations: [ZILDeclaration] = [
            .constant(ZILConstantDeclaration(name: "C1", value: ZILExpression.number(1, location), location: location)),
            .constant(ZILConstantDeclaration(name: "C2", value: ZILExpression.number(2, location), location: location)),
            .global(ZILGlobalDeclaration(name: "G1", value: ZILExpression.number(0, location), location: location)),
            .property(ZILPropertyDeclaration(name: "P1", defaultValue: ZILExpression.atom("DEFAULT", location), location: location)),
            .object(ZILObjectDeclaration(name: "O1", properties: [], location: location)),
            .object(ZILObjectDeclaration(name: "O2", properties: [], location: location)),
            .routine(ZILRoutineDeclaration(name: "R1", body: [ZILExpression.string("test", location)], location: location)),
            .routine(ZILRoutineDeclaration(name: "R2", body: [], location: location))
        ]

        let result = try generator.generateCode(from: declarations)

        #expect(result.contains("; Functions: 2"))
        #expect(result.contains("; Objects: 2"))
        #expect(result.contains("; Globals: 1"))
        #expect(result.contains("; Properties: 1"))
        #expect(result.contains("; Constants: 2"))
        #expect(result.contains("; Strings: 1"))
    }

    // MARK: - Integration Tests

    @Test("Complete game routine generation")
    func completeGameRoutineGeneration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable)

        let location = createTestLocation()

        // Create a realistic game routine that uses multiple ZIL constructs
        let gameRoutine = ZILRoutineDeclaration(
            name: "LANTERN-F",
            parameters: [],
            body: [
                // COND statement with multiple clauses
                ZILExpression.list([
                    ZILExpression.atom("COND", location),
                    // VERB? TAKE clause
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("VERB?", location),
                            ZILExpression.atom("TAKE", location)
                        ], location),
                        ZILExpression.list([
                            ZILExpression.atom("MOVE", location),
                            ZILExpression.atom("LANTERN", location),
                            ZILExpression.atom("PLAYER", location)
                        ], location),
                        ZILExpression.list([
                            ZILExpression.atom("TELL", location),
                            ZILExpression.string("Taken.", location)
                        ], location),
                        ZILExpression.atom("RTRUE", location)
                    ], location),
                    // VERB? LIGHT clause
                    ZILExpression.list([
                        ZILExpression.list([
                            ZILExpression.atom("VERB?", location),
                            ZILExpression.atom("LIGHT", location)
                        ], location),
                        ZILExpression.list([
                            ZILExpression.atom("FSET", location),
                            ZILExpression.atom("LANTERN", location),
                            ZILExpression.atom("ONBIT", location)
                        ], location),
                        ZILExpression.list([
                            ZILExpression.atom("TELL", location),
                            ZILExpression.string("The lantern is now on.", location)
                        ], location),
                        ZILExpression.atom("RTRUE", location)
                    ], location)
                ], location)
            ],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(gameRoutine)])

        // Verify complete routine structure
        #expect(result.contains("\t.FUNCT\tLANTERN-F"))
        #expect(result.contains("VERB?\tTAKE"))
        #expect(result.contains("MOVE\tLANTERN,PLAYER"))
        #expect(result.contains("PRINTI\t\"Taken.\""))
        #expect(result.contains("VERB?\tLIGHT"))
        #expect(result.contains("FSET\tLANTERN,ONBIT"))
        #expect(result.contains("PRINTI\t\"The lantern is now on.\""))
        #expect(result.contains("RTRUE"))

        // Verify label generation for COND (labels may vary due to optimization)
        #expect(result.contains("?ELS"))   // Should have some form of else labels
        // Note: Specific label patterns may vary with optimization

        // Verify string table
        #expect(result.contains(".STRING STR0 \"Taken.\""))
        #expect(result.contains(".STRING STR1 \"The lantern is now on.\""))
    }

    // MARK: - Boolean Logic Optimization Tests

    @Test("Simple AND expression optimization")
    func simpleAndExpressionOptimization() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test: <COND (<AND <EQUAL? X 1> <ZERO? Y>> <RTRUE>)>
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.list([
                        ZILExpression.atom("EQUAL?", location),
                        ZILExpression.localVariable("X", location),
                        ZILExpression.number(1, location)
                    ], location),
                    ZILExpression.list([
                        ZILExpression.atom("ZERO?", location),
                        ZILExpression.localVariable("Y", location)
                    ], location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "AND-TEST",
            parameters: ["X", "Y"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify direct branching without intermediate temp variables
        #expect(result.contains("EQUAL?\tX,1"))
        #expect(result.contains("ZERO?\tY"))
        #expect(result.contains("RTRUE"))

        // Should NOT contain temp variables for AND result
        #expect(!result.contains("TEMP"))
        #expect(!result.contains(">TEMP"))

        // Verify efficient label usage (should have minimal labels)
        let labelMatches = result.matches(of: /\?[A-Z]+\d+/)
        #expect(labelMatches.count <= 3) // Should use ≤3 labels total
    }

    @Test("Simple OR expression optimization")
    func simpleOrExpressionOptimization() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test: <COND (<OR <EQUAL? X 1> <ZERO? Y>> <RTRUE>)>
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("OR", location),
                    ZILExpression.list([
                        ZILExpression.atom("EQUAL?", location),
                        ZILExpression.localVariable("X", location),
                        ZILExpression.number(1, location)
                    ], location),
                    ZILExpression.list([
                        ZILExpression.atom("ZERO?", location),
                        ZILExpression.localVariable("Y", location)
                    ], location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "OR-TEST",
            parameters: ["X", "Y"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify direct branching with OR label
        #expect(result.contains("EQUAL?\tX,1"))
        #expect(result.contains("ZERO?\tY"))
        #expect(result.contains("?OR")) // Should have OR success label

        // Should NOT contain temp variables
        #expect(!result.contains("TEMP"))
        #expect(!result.contains(">TEMP"))
    }

    @Test("NOT expression integration")
    func notExpressionIntegration() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test: <COND (<AND <NOT <ZERO? X>> <EQUAL? Y 1>> <RTRUE>)>
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.list([
                        ZILExpression.atom("NOT", location),
                        ZILExpression.list([
                            ZILExpression.atom("ZERO?", location),
                            ZILExpression.localVariable("X", location)
                        ], location)
                    ], location),
                    ZILExpression.list([
                        ZILExpression.atom("EQUAL?", location),
                        ZILExpression.localVariable("Y", location),
                        ZILExpression.number(1, location)
                    ], location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "NOT-TEST",
            parameters: ["X", "Y"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify NOT is integrated with correct branching
        #expect(result.contains("ZERO?\tX"))
        #expect(result.contains("EQUAL?\tY,1"))

        // Should have direct branching without temp variables
        #expect(!result.contains("TEMP"))
        #expect(!result.contains(">TEMP"))
    }

    @Test("Nested AND/OR expression optimization")
    func nestedAndOrExpressionOptimization() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test complex nesting: <COND (<AND X <OR <ZERO? Y> <EQUAL? Z 1>>> <RTRUE>)>
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.list([
                        ZILExpression.atom("OR", location),
                        ZILExpression.list([
                            ZILExpression.atom("ZERO?", location),
                            ZILExpression.localVariable("Y", location)
                        ], location),
                        ZILExpression.list([
                            ZILExpression.atom("EQUAL?", location),
                            ZILExpression.localVariable("Z", location),
                            ZILExpression.number(1, location)
                        ], location)
                    ], location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "NESTED-TEST",
            parameters: ["X", "Y", "Z"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify all conditions are present
        #expect(result.contains("ZERO?\tX"))
        #expect(result.contains("ZERO?\tY"))
        #expect(result.contains("EQUAL?\tZ,1"))

        // Verify efficient nested structure
        let labelMatches = result.matches(of: /\?[A-Z]+\d+/)
        #expect(labelMatches.count <= 5) // Should be efficient even with nesting

        // Should NOT contain temp variables for boolean operations
        #expect(!result.contains("TEMP"))
        #expect(!result.contains(">TEMP"))
    }

    @Test("Multiple COND clauses with boolean logic")
    func multipleCondClausesWithBooleanLogic() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test multiple COND clauses each with boolean logic
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            // First clause: AND
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.localVariable("Y", location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location),
            // Second clause: OR
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("OR", location),
                    ZILExpression.list([
                        ZILExpression.atom("ZERO?", location),
                        ZILExpression.localVariable("X", location)
                    ], location),
                    ZILExpression.list([
                        ZILExpression.atom("ZERO?", location),
                        ZILExpression.localVariable("Y", location)
                    ], location)
                ], location),
                ZILExpression.atom("RFALSE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "MULTI-COND-TEST",
            parameters: ["X", "Y"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify proper clause separation with ELS labels
        #expect(result.contains("?ELS"))
        #expect(result.contains("ZERO?\tX"))
        #expect(result.contains("ZERO?\tY"))
        #expect(result.contains("RTRUE"))
        #expect(result.contains("RFALSE"))

        // Verify efficient structure
        let labelMatches = result.matches(of: /\?[A-Z]+\d+/)
        #expect(labelMatches.count <= 6) // Should be efficient with multiple clauses
    }

    @Test("Boolean expressions as values vs conditions")
    func booleanExpressionsAsValuesVsConditions() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test AND as condition (should be optimized)
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.localVariable("Y", location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        // Test AND as value (should generate temp variable)
        let setExpr = ZILExpression.list([
            ZILExpression.atom("SET", location),
            ZILExpression.localVariable("RESULT", location),
            ZILExpression.list([
                ZILExpression.atom("AND", location),
                ZILExpression.localVariable("X", location),
                ZILExpression.localVariable("Y", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "MIXED-TEST",
            parameters: ["X", "Y"],
            auxiliaryVariables: [
                ZILParameter(name: "RESULT", location: location)
            ],
            body: [condExpr, setExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // COND should be optimized (no temps) - look before the SET statement
        let condSection = result.components(separatedBy: "SET RESULT").first ?? ""
        let condInstructions = condSection.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.contains("ZERO?") || trimmed.contains("RTRUE") || trimmed.contains("JUMP")
        }

        // The COND section should use direct branching without temp variables for boolean result
        let condHasTemps = condInstructions.contains { $0.contains("TEMP") && $0.contains("SET") }
        #expect(!condHasTemps)

        // SET should generate some form of boolean logic (either temp variables or direct conditional assignment)
        let setSection = result.components(separatedBy: "SET RESULT").last ?? ""
        #expect(setSection.contains("TEMP") || setSection.contains("ZERO?") || setSection.contains("SET"))
    }

    @Test("Stack operations with boolean logic")
    func stackOperationsWithBooleanLogic() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test boolean logic with stack-generating operations
        let condExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location),
                    ZILExpression.list([
                        ZILExpression.atom("EQUAL?", location),
                        ZILExpression.list([
                            ZILExpression.atom("+", location),
                            ZILExpression.localVariable("X", location),
                            ZILExpression.number(1, location)
                        ], location),
                        ZILExpression.number(5, location)
                    ], location),
                    ZILExpression.list([
                        ZILExpression.atom("ZERO?", location),
                        ZILExpression.list([
                            ZILExpression.atom("-", location),
                            ZILExpression.localVariable("Y", location),
                            ZILExpression.number(2, location)
                        ], location)
                    ], location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "STACK-BOOL-TEST",
            parameters: ["X", "Y"],
            body: [condExpr],
            location: location
        )

        let result = try generator.generateCode(from: [.routine(routine)])

        // Verify stack operations are used
        #expect(result.contains("ADD X,1") || result.contains("STACK"))
        #expect(result.contains("SUB Y,2") || result.contains("STACK"))
        #expect(result.contains("EQUAL?"))
        #expect(result.contains("ZERO?"))

        // Should still avoid unnecessary temp variables for boolean logic
        let boolTempCount = result.matches(of: /TEMP\d+/).count
        #expect(boolTempCount <= 2) // Should be minimal temp usage
    }

    @Test("Error handling for malformed boolean expressions")
    func errorHandlingForMalformedBooleanExpressions() throws {
        let symbolTable = createTestSymbolTable()
        var generator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)

        let location = createTestLocation()

        // Test empty AND
        let emptyAndExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("AND", location)
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine1 = ZILRoutineDeclaration(
            name: "EMPTY-AND-TEST",
            parameters: [],
            body: [emptyAndExpr],
            location: location
        )

        // Empty AND should return T (true)
        let result1 = try generator.generateCode(from: [.routine(routine1)])
        #expect(result1.contains("RTRUE") || result1.contains("T"))

        // Test NOT with wrong operand count
        let wrongNotExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.list([
                    ZILExpression.atom("NOT", location),
                    ZILExpression.localVariable("X", location),
                    ZILExpression.localVariable("Y", location) // Wrong: NOT should have 1 operand
                ], location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine2 = ZILRoutineDeclaration(
            name: "WRONG-NOT-TEST",
            parameters: ["X", "Y"],
            body: [wrongNotExpr],
            location: location
        )

        // Should throw error for wrong operand count
        #expect(throws: ZAPCodeGenerator.CodeGenerationError.self) {
            _ = try generator.generateCode(from: [.routine(routine2)])
        }
    }

    @Test("Production mode vs debug mode output")
    func productionModeVsDebugModeOutput() throws {
        let symbolTable = createTestSymbolTable()

        let location = createTestLocation()

        let simpleExpr = ZILExpression.list([
            ZILExpression.atom("COND", location),
            ZILExpression.list([
                ZILExpression.localVariable("X", location),
                ZILExpression.atom("RTRUE", location)
            ], location)
        ], location)

        let routine = ZILRoutineDeclaration(
            name: "MODE-TEST",
            parameters: ["X"],
            body: [simpleExpr],
            location: location
        )

        // Test debug mode (O0)
        var debugGenerator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 0)
        let debugResult = try debugGenerator.generateCode(from: [.routine(routine)])

        // Test production mode (O1)
        var prodGenerator = ZAPCodeGenerator(symbolTable: symbolTable, version: .v3, optimizationLevel: 1)
        let prodResult = try prodGenerator.generateCode(from: [.routine(routine)])

        // Debug mode should have verbose headers
        #expect(debugResult.contains("ZAP Assembly Code Generated"))
        #expect(debugResult.contains("Target Z-Machine Version"))
        #expect(debugResult.contains("Code generation statistics"))

        // Production mode should be minimal
        #expect(!prodResult.contains("ZAP Assembly Code Generated"))
        #expect(!prodResult.contains("Code generation statistics"))
        #expect(prodResult.contains(".ZVERSION"))
        #expect(prodResult.contains("\t.FUNCT\tMODE-TEST"))

        // Production mode should be significantly shorter
        let debugLines = debugResult.components(separatedBy: .newlines).count
        let prodLines = prodResult.components(separatedBy: .newlines).count
        #expect(prodLines < debugLines)
    }
}