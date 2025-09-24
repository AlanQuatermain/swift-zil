import Testing
@testable import ZEngine

@Suite("AST and Utility Comprehensive Tests")
struct ASTUtilityTests {

    // MARK: - ZILExpression Tests

    @Test("ZILExpression creation and properties")
    func zilExpressionCreationAndProperties() throws {
        let location = ZEngine.SourceLocation(file: "test.zil", line: 10, column: 5)

        // Test atom expression
        let atomExpr = ZILExpression.atom("HELLO", location)
        #expect(atomExpr.location == location)
        if case .atom(let name, let loc) = atomExpr {
            #expect(name == "HELLO")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be atom expression")
        }

        // Test number expression
        let numberExpr = ZILExpression.number(42, location)
        #expect(numberExpr.location == location)
        if case .number(let value, let loc) = numberExpr {
            #expect(value == 42)
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be number expression")
        }

        // Test string expression
        let stringExpr = ZILExpression.string("Hello World", location)
        #expect(stringExpr.location == location)
        if case .string(let content, let loc) = stringExpr {
            #expect(content == "Hello World")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be string expression")
        }
    }

    @Test("ZILExpression variable references")
    func zilExpressionVariableReferences() throws {
        let location = ZEngine.SourceLocation(file: "vars.zil", line: 5, column: 15)

        // Test global variable
        let globalVar = ZILExpression.globalVariable("SCORE", location)
        #expect(globalVar.location == location)
        if case .globalVariable(let name, let loc) = globalVar {
            #expect(name == "SCORE")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be global variable")
        }

        // Test local variable
        let localVar = ZILExpression.localVariable("TEMP", location)
        #expect(localVar.location == location)
        if case .localVariable(let name, let loc) = localVar {
            #expect(name == "TEMP")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be local variable")
        }

        // Test property reference
        let propRef = ZILExpression.propertyReference("DESC", location)
        #expect(propRef.location == location)
        if case .propertyReference(let name, let loc) = propRef {
            #expect(name == "DESC")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be property reference")
        }

        // Test flag reference
        let flagRef = ZILExpression.flagReference("TAKEBIT", location)
        #expect(flagRef.location == location)
        if case .flagReference(let name, let loc) = flagRef {
            #expect(name == "TAKEBIT")
            #expect(loc == location)
        } else {
            #expect(Bool(false), "Should be flag reference")
        }
    }

    @Test("ZILExpression list expressions")
    func zilExpressionListExpressions() throws {
        let location = ZEngine.SourceLocation(file: "list.zil", line: 3, column: 8)
        let atomLocation = ZEngine.SourceLocation(file: "list.zil", line: 3, column: 9)

        let elements = [
            ZILExpression.atom("TELL", atomLocation),
            ZILExpression.string("Hello", atomLocation)
        ]

        let listExpr = ZILExpression.list(elements, location)
        #expect(listExpr.location == location)

        if case .list(let items, let loc) = listExpr {
            #expect(items.count == 2)
            #expect(loc == location)

            if case .atom(let name, _) = items[0] {
                #expect(name == "TELL")
            } else {
                #expect(Bool(false), "First element should be atom")
            }

            if case .string(let content, _) = items[1] {
                #expect(content == "Hello")
            } else {
                #expect(Bool(false), "Second element should be string")
            }
        } else {
            #expect(Bool(false), "Should be list expression")
        }
    }

    @Test("ZILExpression equality")
    func zilExpressionEquality() throws {
        let location1 = ZEngine.SourceLocation(file: "test1.zil", line: 1, column: 1)
        let location2 = ZEngine.SourceLocation(file: "test2.zil", line: 2, column: 2)

        // Same content, same location should be equal
        let expr1 = ZILExpression.atom("TEST", location1)
        let expr2 = ZILExpression.atom("TEST", location1)
        #expect(expr1 == expr2)

        // Same content, different location should not be equal
        let expr3 = ZILExpression.atom("TEST", location2)
        #expect(expr1 != expr3)

        // Different content, same location should not be equal
        let expr4 = ZILExpression.atom("OTHER", location1)
        #expect(expr1 != expr4)

        // Different types should not be equal
        let numberExpr = ZILExpression.number(42, location1)
        #expect(expr1 != numberExpr)
    }

    // MARK: - ZILParameter Tests

    @Test("ZILParameter creation and properties")
    func zilParameterCreationAndProperties() throws {
        let location = ZEngine.SourceLocation(file: "param.zil", line: 2, column: 10)

        // Parameter without default value
        let requiredParam = ZILParameter(name: "ARG1", location: location)
        #expect(requiredParam.name == "ARG1")
        #expect(requiredParam.defaultValue == nil)
        #expect(requiredParam.location == location)

        // Parameter with default value
        let defaultValue = ZILExpression.number(42, location)
        let optionalParam = ZILParameter(name: "ARG2", defaultValue: defaultValue, location: location)
        #expect(optionalParam.name == "ARG2")
        #expect(optionalParam.defaultValue != nil)
        #expect(optionalParam.location == location)

        if let defVal = optionalParam.defaultValue,
           case .number(let value, _) = defVal {
            #expect(value == 42)
        } else {
            #expect(Bool(false), "Should have number default value")
        }
    }

    @Test("ZILParameter equality")
    func zilParameterEquality() throws {
        let location = ZEngine.SourceLocation(file: "param.zil", line: 1, column: 1)
        let defaultValue = ZILExpression.atom("DEFAULT", location)

        let param1 = ZILParameter(name: "TEST", defaultValue: defaultValue, location: location)
        let param2 = ZILParameter(name: "TEST", defaultValue: defaultValue, location: location)
        let param3 = ZILParameter(name: "OTHER", defaultValue: defaultValue, location: location)

        #expect(param1 == param2)
        #expect(param1 != param3)
    }

    // MARK: - ZILRoutineDeclaration Tests

    @Test("ZILRoutineDeclaration creation and properties")
    func zilRoutineDeclarationCreationAndProperties() throws {
        let location = ZEngine.SourceLocation(file: "routine.zil", line: 1, column: 1)
        let paramLocation = ZEngine.SourceLocation(file: "routine.zil", line: 1, column: 15)
        let bodyLocation = ZEngine.SourceLocation(file: "routine.zil", line: 2, column: 5)

        // Simple routine with just required parameters
        let simpleRoutine = ZILRoutineDeclaration(
            name: "SIMPLE",
            parameters: ["ARG1", "ARG2"],
            body: [ZILExpression.atom("RTRUE", bodyLocation)],
            location: location
        )

        #expect(simpleRoutine.name == "SIMPLE")
        #expect(simpleRoutine.parameters == ["ARG1", "ARG2"])
        #expect(simpleRoutine.optionalParameters.isEmpty)
        #expect(simpleRoutine.auxiliaryVariables.isEmpty)
        #expect(simpleRoutine.body.count == 1)
        #expect(simpleRoutine.location == location)

        // Complex routine with optional and auxiliary parameters
        let optionalParam = ZILParameter(name: "OPT1", defaultValue: ZILExpression.number(0, paramLocation), location: paramLocation)
        let auxVar = ZILParameter(name: "AUX1", location: paramLocation)

        let complexRoutine = ZILRoutineDeclaration(
            name: "COMPLEX",
            parameters: ["REQ1"],
            optionalParameters: [optionalParam],
            auxiliaryVariables: [auxVar],
            body: [
                ZILExpression.atom("TELL", bodyLocation),
                ZILExpression.string("Hello", bodyLocation)
            ],
            location: location
        )

        #expect(complexRoutine.name == "COMPLEX")
        #expect(complexRoutine.parameters == ["REQ1"])
        #expect(complexRoutine.optionalParameters.count == 1)
        #expect(complexRoutine.auxiliaryVariables.count == 1)
        #expect(complexRoutine.body.count == 2)
        #expect(complexRoutine.optionalParameters[0].name == "OPT1")
        #expect(complexRoutine.auxiliaryVariables[0].name == "AUX1")
    }

    // MARK: - ZILObjectDeclaration Tests

    @Test("ZILObjectDeclaration creation and properties")
    func zilObjectDeclarationCreationAndProperties() throws {
        let location = ZEngine.SourceLocation(file: "object.zil", line: 1, column: 1)
        let propLocation = ZEngine.SourceLocation(file: "object.zil", line: 2, column: 5)

        let properties = [
            ZILObjectProperty(name: "DESC", value: ZILExpression.string("A test object", propLocation), location: propLocation),
            ZILObjectProperty(name: "FLAGS", value: ZILExpression.atom("TAKEBIT", propLocation), location: propLocation)
        ]

        let objectDecl = ZILObjectDeclaration(name: "TEST-OBJECT", properties: properties, location: location)

        #expect(objectDecl.name == "TEST-OBJECT")
        #expect(objectDecl.properties.count == 2)
        #expect(objectDecl.location == location)
        #expect(objectDecl.properties[0].name == "DESC")
        #expect(objectDecl.properties[1].name == "FLAGS")
    }

    // MARK: - ZILDeclaration Tests

    @Test("ZILDeclaration creation and location extraction")
    func zilDeclarationCreationAndLocationExtraction() throws {
        let location = ZEngine.SourceLocation(file: "decl.zil", line: 5, column: 10)

        // Test routine declaration
        let routineDecl = ZILRoutineDeclaration(name: "TEST", body: [], location: location)
        let routineWrapper = ZILDeclaration.routine(routineDecl)
        #expect(routineWrapper.location == location)

        // Test object declaration
        let objectDecl = ZILObjectDeclaration(name: "OBJ", properties: [], location: location)
        let objectWrapper = ZILDeclaration.object(objectDecl)
        #expect(objectWrapper.location == location)

        // Test global declaration
        let globalDecl = ZILGlobalDeclaration(name: "VAR", value: ZILExpression.number(42, location), location: location)
        let globalWrapper = ZILDeclaration.global(globalDecl)
        #expect(globalWrapper.location == location)

        // Test property declaration
        let propDecl = ZILPropertyDeclaration(name: "PROP", defaultValue: ZILExpression.atom("DEFAULT", location), location: location)
        let propWrapper = ZILDeclaration.property(propDecl)
        #expect(propWrapper.location == location)

        // Test constant declaration
        let constDecl = ZILConstantDeclaration(name: "CONST", value: ZILExpression.number(100, location), location: location)
        let constWrapper = ZILDeclaration.constant(constDecl)
        #expect(constWrapper.location == location)

        // Test insert file declaration
        let insertDecl = ZILInsertFileDeclaration(filename: "library.zil", location: location)
        let insertWrapper = ZILDeclaration.insertFile(insertDecl)
        #expect(insertWrapper.location == location)

        // Test version declaration
        let versionDecl = ZILVersionDeclaration(version: "ZIP", location: location)
        let versionWrapper = ZILDeclaration.version(versionDecl)
        #expect(versionWrapper.location == location)
    }

    // MARK: - ZILNode Protocol Tests

    @Test("ZILNode protocol conformance")
    func zilNodeProtocolConformance() throws {
        let location = ZEngine.SourceLocation(file: "node.zil", line: 1, column: 1)

        // Test that expressions conform to ZILNode
        let expr: any ZILNode = ZILExpression.atom("TEST", location)
        #expect(expr.location == location)

        // Test that declarations conform to ZILNode
        let routineDecl = ZILRoutineDeclaration(name: "ROUTINE", body: [], location: location)
        let decl: any ZILNode = ZILDeclaration.routine(routineDecl)
        #expect(decl.location == location)

        // Test that individual declaration structs conform to ZILNode
        let objDecl: any ZILNode = ZILObjectDeclaration(name: "OBJ", properties: [], location: location)
        #expect(objDecl.location == location)

        let globalDecl: any ZILNode = ZILGlobalDeclaration(name: "VAR", value: ZILExpression.number(1, location), location: location)
        #expect(globalDecl.location == location)
    }

    // MARK: - ZUtils Tests

    @Test("ZUtils makeValidIdentifier basic functionality")
    func zutilsMakeValidIdentifierBasic() throws {
        // Basic transformations
        #expect(ZUtils.makeValidIdentifier("hello world") == "HELLO-WORLD")
        #expect(ZUtils.makeValidIdentifier("test_var") == "TEST-VAR")
        #expect(ZUtils.makeValidIdentifier("MixedCase") == "MIXEDCASE")
        #expect(ZUtils.makeValidIdentifier("with-hyphens") == "WITH-HYPHENS")

        // Starting with numbers
        #expect(ZUtils.makeValidIdentifier("123test") == "Z-123TEST")
        #expect(ZUtils.makeValidIdentifier("9var") == "Z-9VAR")

        // Starting with hyphen
        #expect(ZUtils.makeValidIdentifier("-test") == "Z--TEST")

        // Reserved words
        #expect(ZUtils.makeValidIdentifier("ROUTINE") == "ROUTINE-1")
        #expect(ZUtils.makeValidIdentifier("OBJECT") == "OBJECT-1")
        #expect(ZUtils.makeValidIdentifier("IF") == "IF-1")

        // Edge cases
        #expect(ZUtils.makeValidIdentifier("") == "UNNAMED")
        #expect(ZUtils.makeValidIdentifier("   ") == "Z----") // Spaces become hyphens, then prefixed with Z- due to starting with hyphen
    }

    @Test("ZUtils makeValidIdentifier character filtering")
    func zutilsMakeValidIdentifierCharacterFiltering() throws {
        // Invalid characters should be removed
        #expect(ZUtils.makeValidIdentifier("test@symbol") == "TESTSYMBOL")
        #expect(ZUtils.makeValidIdentifier("var#with$special%chars") == "VARWITHSPECIALCHARS")
        #expect(ZUtils.makeValidIdentifier("test!") == "TEST")
        #expect(ZUtils.makeValidIdentifier("(test)") == "TEST")

        // Valid characters should be preserved
        #expect(ZUtils.makeValidIdentifier("valid-chars?") == "VALID-CHARS?")
        #expect(ZUtils.makeValidIdentifier("test123") == "TEST123")
        #expect(ZUtils.makeValidIdentifier("ABC?DEF-123") == "ABC?DEF-123")

        // Unicode and special characters
        #expect(ZUtils.makeValidIdentifier("tëst") == "TËST") // Non-ASCII letters are preserved in Swift's alphanumerics set
        #expect(ZUtils.makeValidIdentifier("test\n\tvar") == "TESTVAR") // Whitespace becomes empty and gets replaced
    }

    @Test("ZUtils address packing functions")
    func zutilsAddressPacking() throws {
        // Test v3 packing (divide by 2)
        #expect(ZUtils.packAddress(100, version: .v3) == 50)
        #expect(ZUtils.packAddress(0, version: .v3) == 0)
        #expect(ZUtils.packAddress(65534, version: .v3) == 32767)

        // Test v4/v5 packing (divide by 4)
        #expect(ZUtils.packAddress(100, version: .v4) == 25)
        #expect(ZUtils.packAddress(100, version: .v5) == 25)
        #expect(ZUtils.packAddress(0, version: .v4) == 0)
        #expect(ZUtils.packAddress(65532, version: .v4) == 16383)

        // Test v6/v7 packing (divide by 4)
        #expect(ZUtils.packAddress(100, version: .v6) == 25)
        #expect(ZUtils.packAddress(100, version: .v7) == 25)

        // Test v8 packing (divide by 8)
        #expect(ZUtils.packAddress(100, version: .v8) == 12)
        #expect(ZUtils.packAddress(800, version: .v8) == 100)
        #expect(ZUtils.packAddress(0, version: .v8) == 0)
    }

    @Test("ZUtils address unpacking functions")
    func zutilsAddressUnpacking() throws {
        // Test v3 unpacking (multiply by 2)
        #expect(ZUtils.unpackAddress(50, version: .v3) == 100)
        #expect(ZUtils.unpackAddress(0, version: .v3) == 0)
        #expect(ZUtils.unpackAddress(32767, version: .v3) == 65534)

        // Test v4/v5 unpacking (multiply by 4)
        #expect(ZUtils.unpackAddress(25, version: .v4) == 100)
        #expect(ZUtils.unpackAddress(25, version: .v5) == 100)
        #expect(ZUtils.unpackAddress(0, version: .v4) == 0)
        #expect(ZUtils.unpackAddress(16383, version: .v4) == 65532)

        // Test v6/v7 unpacking (multiply by 4)
        #expect(ZUtils.unpackAddress(25, version: .v6) == 100)
        #expect(ZUtils.unpackAddress(25, version: .v7) == 100)

        // Test v8 unpacking (multiply by 8)
        #expect(ZUtils.unpackAddress(12, version: .v8) == 96)
        #expect(ZUtils.unpackAddress(100, version: .v8) == 800)
        #expect(ZUtils.unpackAddress(0, version: .v8) == 0)
    }

    @Test("ZUtils pack/unpack address roundtrip")
    func zutilsPackUnpackRoundtrip() throws {
        let testAddresses: [UInt32] = [0, 100, 1000, 10000, 50000]
        let versions: [ZMachineVersion] = [.v3, .v4, .v5, .v6, .v7, .v8]

        for address in testAddresses {
            for version in versions {
                let packed = ZUtils.packAddress(address, version: version)
                let unpacked = ZUtils.unpackAddress(packed, version: version)

                // Due to integer division, we might lose some precision
                // The unpacked address should be <= original and differ by less than the divisor
                #expect(unpacked <= address)
                let divisor: UInt32 = version == .v3 ? 2 : version == .v8 ? 8 : 4
                #expect(address - unpacked < divisor)
            }
        }
    }

    @Test("ZUtils range checking functions")
    func zutilsRangeCheckingFunctions() throws {
        // Test fitsInByte (signed 8-bit: -128 to 127)
        #expect(ZUtils.fitsInByte(0) == true)
        #expect(ZUtils.fitsInByte(127) == true)
        #expect(ZUtils.fitsInByte(-128) == true)
        #expect(ZUtils.fitsInByte(128) == false)
        #expect(ZUtils.fitsInByte(-129) == false)
        #expect(ZUtils.fitsInByte(1000) == false)
        #expect(ZUtils.fitsInByte(-1000) == false)

        // Test fitsInUnsignedByte (0 to 255)
        #expect(ZUtils.fitsInUnsignedByte(0) == true)
        #expect(ZUtils.fitsInUnsignedByte(255) == true)
        #expect(ZUtils.fitsInUnsignedByte(128) == true)
        #expect(ZUtils.fitsInUnsignedByte(-1) == false)
        #expect(ZUtils.fitsInUnsignedByte(256) == false)
        #expect(ZUtils.fitsInUnsignedByte(1000) == false)

        // Test fitsInWord (signed 16-bit: -32768 to 32767)
        #expect(ZUtils.fitsInWord(0) == true)
        #expect(ZUtils.fitsInWord(32767) == true)
        #expect(ZUtils.fitsInWord(-32768) == true)
        #expect(ZUtils.fitsInWord(32768) == false)
        #expect(ZUtils.fitsInWord(-32769) == false)
        #expect(ZUtils.fitsInWord(65536) == false)
        #expect(ZUtils.fitsInWord(-65536) == false)
    }

    // MARK: - Constants Tests

    @Test("ZConstants reserved words validation")
    func zconstantsReservedWordsValidation() throws {
        // Test that common ZIL keywords are in reserved words
        #expect(ZConstants.reservedWords.contains("ROUTINE"))
        #expect(ZConstants.reservedWords.contains("OBJECT"))
        #expect(ZConstants.reservedWords.contains("IF"))
        #expect(ZConstants.reservedWords.contains("COND"))
        #expect(ZConstants.reservedWords.contains("TELL"))
        #expect(ZConstants.reservedWords.contains("RTRUE"))
        #expect(ZConstants.reservedWords.contains("RFALSE"))

        // Test that reserved words set is not empty and has reasonable size
        #expect(ZConstants.reservedWords.count > 10)
        #expect(ZConstants.reservedWords.count < 200) // Sanity check

        // Test that non-reserved words are not included
        #expect(!ZConstants.reservedWords.contains("MY-ROUTINE"))
        #expect(!ZConstants.reservedWords.contains("CUSTOM-OBJECT"))
        #expect(!ZConstants.reservedWords.contains(""))
    }

    @Test("ZConstants limits validation")
    func zconstantsLimitsValidation() throws {
        // Test that constants have reasonable values
        #expect(ZConstants.maxLocals == 15)
        #expect(ZConstants.maxCallStack == 1024)
        #expect(ZConstants.maxEvalStack == 1024)
        #expect(ZConstants.headerSize == 64)
        #expect(ZConstants.maxSymbolLength == 255)
        #expect(ZConstants.maxNestingDepth == 64)
        #expect(ZConstants.maxIncludes == 32)

        // Sanity checks for reasonable limits
        #expect(ZConstants.maxLocals > 0)
        #expect(ZConstants.maxCallStack > 0)
        #expect(ZConstants.maxEvalStack > 0)
        #expect(ZConstants.headerSize > 0)
    }

    @Test("ZConstants standard properties")
    func zconstantsStandardProperties() throws {
        // Test that standard properties have correct raw values
        #expect(ZConstants.StandardProperty.parent.rawValue == 1)
        #expect(ZConstants.StandardProperty.child.rawValue == 2)
        #expect(ZConstants.StandardProperty.sibling.rawValue == 3)
        #expect(ZConstants.StandardProperty.name.rawValue == 4)
        #expect(ZConstants.StandardProperty.description.rawValue == 5)
        #expect(ZConstants.StandardProperty.action.rawValue == 6)

        // Test specific property values
        #expect(ZConstants.StandardProperty.north.rawValue == 26)
        #expect(ZConstants.StandardProperty.south.rawValue == 27)
        #expect(ZConstants.StandardProperty.east.rawValue == 28)
        #expect(ZConstants.StandardProperty.west.rawValue == 29)
        #expect(ZConstants.StandardProperty.northeast.rawValue == 30)
        #expect(ZConstants.StandardProperty.northwest.rawValue == 31)
    }

    // MARK: - Integration Tests

    @Test("AST integration with real-world patterns")
    func astIntegrationWithRealWorldPatterns() throws {
        let location = ZEngine.SourceLocation(file: "integration.zil", line: 1, column: 1)

        // Create a realistic routine declaration
        let routineBody = [
            ZILExpression.list([
                ZILExpression.atom("COND", location),
                ZILExpression.list([
                    ZILExpression.list([
                        ZILExpression.atom("VERB?", location),
                        ZILExpression.atom("TAKE", location)
                    ], location),
                    ZILExpression.atom("RTRUE", location)
                ], location)
            ], location)
        ]

        let routine = ZILRoutineDeclaration(
            name: "LANTERN-F",
            parameters: [],
            body: routineBody,
            location: location
        )

        #expect(routine.name == "LANTERN-F")
        #expect(routine.body.count == 1)
        #expect(routine.location == location)

        // Verify the nested structure
        if case .list(let outerElements, _) = routine.body[0],
           case .atom(let condAtom, _) = outerElements[0] {
            #expect(condAtom == "COND")
        } else {
            #expect(Bool(false), "Should have proper nested COND structure")
        }
    }

    @Test("ZUtils integration with AST identifier validation")
    func zutilsIntegrationWithAstIdentifierValidation() throws {
        // Test that ZUtils can clean up identifiers for AST creation
        let invalidName = "123 test-name!"
        let validName = ZUtils.makeValidIdentifier(invalidName)

        #expect(validName == "Z-123-TEST-NAME")

        let location = ZEngine.SourceLocation(file: "validation.zil", line: 1, column: 1)

        // Use cleaned name in AST
        let routine = ZILRoutineDeclaration(
            name: validName,
            body: [ZILExpression.atom("RTRUE", location)],
            location: location
        )

        #expect(routine.name == "Z-123-TEST-NAME")
    }

    @Test("Sendable conformance verification")
    func sendableConformanceVerification() throws {
        let location = ZEngine.SourceLocation(file: "sendable.zil", line: 1, column: 1)

        // Test that AST types conform to Sendable
        let expr: any Sendable = ZILExpression.atom("TEST", location)
        #expect(expr is ZILExpression)

        let param: any Sendable = ZILParameter(name: "PARAM", location: location)
        #expect(param is ZILParameter)

        let routine: any Sendable = ZILRoutineDeclaration(name: "ROUTINE", body: [], location: location)
        #expect(routine is ZILRoutineDeclaration)

        let object: any Sendable = ZILObjectDeclaration(name: "OBJECT", properties: [], location: location)
        #expect(object is ZILObjectDeclaration)

        let global: any Sendable = ZILGlobalDeclaration(name: "GLOBAL", value: ZILExpression.number(1, location), location: location)
        #expect(global is ZILGlobalDeclaration)

        let property: any Sendable = ZILPropertyDeclaration(name: "PROP", defaultValue: ZILExpression.atom("DEFAULT", location), location: location)
        #expect(property is ZILPropertyDeclaration)

        let constant: any Sendable = ZILConstantDeclaration(name: "CONST", value: ZILExpression.number(42, location), location: location)
        #expect(constant is ZILConstantDeclaration)

        let insertFile: any Sendable = ZILInsertFileDeclaration(filename: "file.zil", location: location)
        #expect(insertFile is ZILInsertFileDeclaration)

        let version: any Sendable = ZILVersionDeclaration(version: "ZIP", location: location)
        #expect(version is ZILVersionDeclaration)
    }
}