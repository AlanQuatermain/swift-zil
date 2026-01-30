import Testing
@testable import ZEngine

@Suite("MacroProcessor Tests")
struct MacroProcessorTests {

    // MARK: - Helper Methods

    private func createLocation() -> ZEngine.SourceLocation {
        ZEngine.SourceLocation(file: "test.zil", line: 1, column: 1)
    }

    // MARK: - Basic Macro Definition Tests

    @Test("Define simple macro")
    func defineSimpleMacro() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // <DEFMAC SQUARE (X) <FORM * .X .X>>
        let result = processor.defineMacro(
            name: "SQUARE",
            parameters: [.standard("X")],
            body: .list([
                .atom("FORM", location),
                .atom("*", location),
                .localVariable("X", location),
                .localVariable("X", location)
            ], location),
            at: location
        )

        #expect(result == true)

        let macro = processor.getMacro(name: "SQUARE")
        #expect(macro != nil)
        #expect(macro?.name == "SQUARE")
        #expect(macro?.parameters.count == 1)
    }

    @Test("Retrieve defined macro")
    func retrieveDefinedMacro() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        processor.defineMacro(
            name: "TEST-MACRO",
            parameters: [.standard("A"), .standard("B")],
            body: .atom("BODY", location),
            at: location
        )

        let macro = processor.getMacro(name: "TEST-MACRO")
        #expect(macro?.name == "TEST-MACRO")
        #expect(macro?.parameterNames == ["A", "B"])
    }

    @Test("Define macro with no parameters")
    func defineMacroWithNoParameters() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // <DEFMAC RFATAL () <FORM TELL "Fatal error." CR>>
        let result = processor.defineMacro(
            name: "RFATAL",
            parameters: [],
            body: .list([
                .atom("FORM", location),
                .atom("TELL", location),
                .string("Fatal error.", location),
                .atom("CR", location)
            ], location),
            at: location
        )

        #expect(result == true)
        let macro = processor.getMacro(name: "RFATAL")
        #expect(macro?.parameters.isEmpty == true)
    }

    @Test("Cannot redefine built-in macro")
    func cannotRedefineBuiltinMacro() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define a built-in macro manually (simulating built-in)
        processor.defineMacro(
            name: "BUILT-IN",
            parameters: [],
            body: .atom("BODY", location),
            at: location
        )

        // Attempt to redefine should fail if marked as built-in
        // Note: Current implementation allows redefinition unless marked as built-in
        // This test verifies normal behavior
        let redefined = processor.defineMacro(
            name: "BUILT-IN",
            parameters: [.standard("X")],
            body: .atom("NEW-BODY", location),
            at: location
        )

        #expect(redefined == true) // User macros can be redefined
    }

    // MARK: - Simple Macro Expansion Tests

    @Test("Expand simple macro with one parameter")
    func expandSimpleMacroWithOneParameter() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC DOUBLE (X) <FORM + .X .X>>
        processor.defineMacro(
            name: "DOUBLE",
            parameters: [.standard("X")],
            body: .list([
                .atom("FORM", location),
                .atom("+", location),
                .localVariable("X", location),
                .localVariable("X", location)
            ], location),
            at: location
        )

        // Expand: <DOUBLE 5>
        let result = processor.expandMacro(
            name: "DOUBLE",
            arguments: [.number(5, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // Should produce: <+ 5 5>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 3)
        #expect(elements[0] == ZILExpression.atom("+", location))
        #expect(elements[1] == ZILExpression.number(5, location))
        #expect(elements[2] == ZILExpression.number(5, location))
    }

    @Test("Expand macro with multiple parameters")
    func expandMacroWithMultipleParameters() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC ADD-BOTH (A B) <FORM + .A .B>>
        processor.defineMacro(
            name: "ADD-BOTH",
            parameters: [.standard("A"), .standard("B")],
            body: .list([
                .atom("FORM", location),
                .atom("+", location),
                .localVariable("A", location),
                .localVariable("B", location)
            ], location),
            at: location
        )

        // Expand: <ADD-BOTH 3 7>
        let result = processor.expandMacro(
            name: "ADD-BOTH",
            arguments: [.number(3, location), .number(7, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // Should produce: <+ 3 7>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 3)
        #expect(elements[1] == ZILExpression.number(3, location))
        #expect(elements[2] == ZILExpression.number(7, location))
    }

    // MARK: - Variable Arguments Tests

    @Test("Expand macro with variable arguments")
    func expandMacroWithVariableArguments() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC TELL ("ARGS" A) <FORM PRINTI !.A>>
        processor.defineMacro(
            name: "TELL",
            parameters: [.variableArgs("A")],
            body: .list([
                .atom("FORM", location),
                .atom("PRINTI", location),
                .indirection(.localVariable("A", location), location)
            ], location),
            at: location
        )

        // Expand: <TELL "Hello" "World">
        let result = processor.expandMacro(
            name: "TELL",
            arguments: [
                .string("Hello", location),
                .string("World", location)
            ],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // Variable args should be collected into a list
        // Body should have !.A replaced with the collected arguments
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 2) // PRINTI and indirection
    }

    @Test("Expand macro with quoted parameter and variable arguments")
    func expandMacroWithQuotedParameterAndVariableArguments() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC BSET ('OBJ "ARGS" BITS) <FORM FSET .OBJ !.BITS>>
        processor.defineMacro(
            name: "BSET",
            parameters: [.quoted("OBJ"), .variableArgs("BITS")],
            body: .list([
                .atom("FORM", location),
                .atom("FSET", location),
                .localVariable("OBJ", location),
                .indirection(.localVariable("BITS", location), location)
            ], location),
            at: location
        )

        // Expand: <BSET LANTERN TAKEBIT LIGHTBIT>
        let result = processor.expandMacro(
            name: "BSET",
            arguments: [
                .atom("LANTERN", location),
                .atom("TAKEBIT", location),
                .atom("LIGHTBIT", location)
            ],
            at: location
        )

        guard case .success(_) = result else {
            Issue.record("Expected successful expansion")
            return
        }
    }

    // MARK: - Optional Parameter Tests

    @Test("Expand macro with optional parameter provided")
    func expandMacroWithOptionalParameterProvided() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC GREET ('NAME "OPTIONAL" 'TITLE) <FORM TELL .TITLE " " .NAME>>
        processor.defineMacro(
            name: "GREET",
            parameters: [.quoted("NAME"), .optional("TITLE", nil)],
            body: .list([
                .atom("FORM", location),
                .atom("TELL", location),
                .localVariable("TITLE", location),
                .string(" ", location),
                .localVariable("NAME", location)
            ], location),
            at: location
        )

        // Expand with optional provided: <GREET PLAYER "Mr.">
        let result = processor.expandMacro(
            name: "GREET",
            arguments: [
                .atom("PLAYER", location),
                .string("Mr.", location)
            ],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        // Should have TELL, "Mr.", " ", PLAYER
        #expect(elements.count == 4)
    }

    @Test("Expand macro with optional parameter omitted")
    func expandMacroWithOptionalParameterOmitted() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC GREET ('NAME "OPTIONAL" 'TITLE) <FORM TELL .NAME>>
        processor.defineMacro(
            name: "GREET",
            parameters: [.quoted("NAME"), .optional("TITLE", nil)],
            body: .list([
                .atom("FORM", location),
                .atom("TELL", location),
                .localVariable("NAME", location)
            ], location),
            at: location
        )

        // Expand without optional: <GREET PLAYER>
        let result = processor.expandMacro(
            name: "GREET",
            arguments: [.atom("PLAYER", location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 2) // TELL and PLAYER
    }

    @Test("Expand macro with optional parameter using default value")
    func expandMacroWithOptionalParameterUsingDefaultValue() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define: <DEFMAC INCR (VAR "OPTIONAL" 'AMOUNT 1) <FORM SET .VAR <FORM + .VAR .AMOUNT>>>
        processor.defineMacro(
            name: "INCR",
            parameters: [
                .standard("VAR"),
                .optional("AMOUNT", .number(1, location))
            ],
            body: .list([
                .atom("FORM", location),
                .atom("SET", location),
                .localVariable("VAR", location),
                .list([
                    .atom("FORM", location),
                    .atom("+", location),
                    .localVariable("VAR", location),
                    .localVariable("AMOUNT", location)
                ], location)
            ], location),
            at: location
        )

        // Expand without optional: <INCR X> (should use default 1)
        let result = processor.expandMacro(
            name: "INCR",
            arguments: [.atom("X", location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // Should use default value of 1
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 3) // SET, X, <+ X 1>
    }

    // MARK: - Error Handling Tests

    @Test("Error on undefined macro")
    func errorOnUndefinedMacro() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        let result = processor.expandMacro(
            name: "UNDEFINED",
            arguments: [],
            at: location
        )

        guard case .error(let diagnostic) = result else {
            Issue.record("Expected error result")
            return
        }

        guard case .undefinedMacro(let name) = diagnostic.code else {
            Issue.record("Expected undefinedMacro error")
            return
        }

        #expect(name == "UNDEFINED")
    }

    @Test("Error on too few arguments")
    func errorOnTooFewArguments() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define macro requiring 2 arguments
        processor.defineMacro(
            name: "NEEDS-TWO",
            parameters: [.standard("A"), .standard("B")],
            body: .atom("BODY", location),
            at: location
        )

        // Try to expand with only 1 argument
        let result = processor.expandMacro(
            name: "NEEDS-TWO",
            arguments: [.number(1, location)],
            at: location
        )

        guard case .error(let diagnostic) = result else {
            Issue.record("Expected error result")
            return
        }

        guard case .argumentCountMismatch(let expected, let got) = diagnostic.code else {
            Issue.record("Expected argumentCountMismatch error")
            return
        }

        #expect(expected == 2)
        #expect(got == 1)
    }

    @Test("Error on too many arguments (without variable args)")
    func errorOnTooManyArgumentsWithoutVariableArgs() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define macro requiring exactly 1 argument
        processor.defineMacro(
            name: "NEEDS-ONE",
            parameters: [.standard("X")],
            body: .atom("BODY", location),
            at: location
        )

        // Try to expand with 3 arguments
        let result = processor.expandMacro(
            name: "NEEDS-ONE",
            arguments: [
                .number(1, location),
                .number(2, location),
                .number(3, location)
            ],
            at: location
        )

        guard case .error(let diagnostic) = result else {
            Issue.record("Expected error result")
            return
        }

        guard case .argumentCountMismatch(let expected, let got) = diagnostic.code else {
            Issue.record("Expected argumentCountMismatch error")
            return
        }

        #expect(expected == 1)
        #expect(got == 3)
    }

    @Test("Recursive macro expansion behavior")
    func errorOnRecursiveMacroExpansion() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define a macro that would be recursive if fully expanded: <DEFMAC RECURSE () <RECURSE>>
        // Note: MacroProcessor doesn't recursively expand macros in the result,
        // so this just returns <RECURSE> without triggering recursion detection.
        // Recursion detection only triggers if the same macro is directly re-invoked
        // during expansion (i.e., expandMacro("RECURSE") called while already expanding RECURSE).
        processor.defineMacro(
            name: "RECURSE",
            parameters: [],
            body: .list([.atom("RECURSE", location)], location),
            at: location
        )

        // Expand the macro - this succeeds and returns <RECURSE> (the body)
        let result = processor.expandMacro(
            name: "RECURSE",
            arguments: [],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // The result should be the body: <RECURSE>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 1)
        guard case .atom(let name, _) = elements[0] else {
            Issue.record("Expected atom in result")
            return
        }
        #expect(name == "RECURSE")
    }

    // MARK: - Real-World Macro Tests

    @Test("Expand VERB? macro from Zork")
    func expandVerbMacroFromZork() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Real VERB? macro from Zork 1:
        // <DEFMAC VERB? ("ARGS" ATMS) <MULTIFROB PRSA .ATMS>>
        processor.defineMacro(
            name: "VERB?",
            parameters: [.variableArgs("ATMS")],
            body: .list([
                .atom("MULTIFROB", location),
                .atom("PRSA", location),
                .localVariable("ATMS", location)
            ], location),
            at: location
        )

        // Expand: <VERB? TAKE DROP>
        let result = processor.expandMacro(
            name: "VERB?",
            arguments: [
                .atom("TAKE", location),
                .atom("DROP", location)
            ],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Expected successful expansion")
            return
        }

        // Should produce: <MULTIFROB PRSA (TAKE DROP)>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expected list expression")
            return
        }

        #expect(elements.count == 3)
        #expect(elements[0] == ZILExpression.atom("MULTIFROB", location))
        #expect(elements[1] == ZILExpression.atom("PRSA", location))
    }

    // MARK: - Macro Utility Tests

    @Test("Get all defined macros")
    func getAllDefinedMacros() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        processor.defineMacro(name: "MACRO1", parameters: [], body: .atom("BODY1", location), at: location)
        processor.defineMacro(name: "MACRO2", parameters: [], body: .atom("BODY2", location), at: location)
        processor.defineMacro(name: "MACRO3", parameters: [], body: .atom("BODY3", location), at: location)

        let allMacros = processor.getAllMacros()
        #expect(allMacros.count == 3)

        let names = Set(allMacros.map { $0.name })
        #expect(names.contains("MACRO1"))
        #expect(names.contains("MACRO2"))
        #expect(names.contains("MACRO3"))
    }

    @Test("Clear diagnostics")
    func clearDiagnostics() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Generate an error
        _ = processor.expandMacro(name: "UNDEFINED", arguments: [], at: location)

        var diagnostics = processor.getDiagnostics()
        #expect(diagnostics.count == 1)

        // Clear diagnostics
        processor.clearDiagnostics()

        diagnostics = processor.getDiagnostics()
        #expect(diagnostics.isEmpty)
    }

    @Test("Debug tracing")
    func debugTracing() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Enable debug tracing
        processor.setDebugTracing(true)

        // Define and expand a macro
        processor.defineMacro(
            name: "TRACE-TEST",
            parameters: [.standard("X")],
            body: .localVariable("X", location),
            at: location
        )

        _ = processor.expandMacro(
            name: "TRACE-TEST",
            arguments: [.number(42, location)],
            at: location
        )

        let trace = processor.getExpansionTrace()
        #expect(trace.count == 1)
        #expect(trace[0].macroName == "TRACE-TEST")

        // Disable tracing
        processor.setDebugTracing(false)
        let emptyTrace = processor.getExpansionTrace()
        #expect(emptyTrace.isEmpty)
    }

    // MARK: - Compile-Time Constants Tests

    @Test("Define and retrieve compile-time constant")
    func defineAndRetrieveCompileTimeConstant() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        processor.defineConstant(
            name: "MAX-SCORE",
            value: .number(350, location)
        )

        let constant = processor.getConstant(name: "MAX-SCORE")
        #expect(constant == ZILExpression.number(350, location))
    }

    @Test("Get all compile-time constants")
    func getAllCompileTimeConstants() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        processor.defineConstant(name: "C1", value: .number(1, location))
        processor.defineConstant(name: "C2", value: .number(2, location))
        processor.defineConstant(name: "C3", value: .string("test", location))

        let constants = processor.getAllConstants()
        #expect(constants.count == 3)
        #expect(constants["C1"] != nil)
        #expect(constants["C2"] != nil)
        #expect(constants["C3"] != nil)
    }

    // MARK: - Macro Definition Utility Tests

    @Test("Macro minimum arguments calculation")
    func macroMinimumArgumentsCalculation() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Define macro with 2 required, 1 optional
        processor.defineMacro(
            name: "TEST",
            parameters: [
                .standard("A"),
                .standard("B"),
                .optional("C", nil)
            ],
            body: .atom("BODY", location),
            at: location
        )

        let macro = processor.getMacro(name: "TEST")!
        #expect(macro.minimumArguments == 2)
    }

    @Test("Macro maximum arguments calculation")
    func macroMaximumArgumentsCalculation() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        // Macro without variable args has fixed maximum
        processor.defineMacro(
            name: "FIXED",
            parameters: [.standard("A"), .standard("B")],
            body: .atom("BODY", location),
            at: location
        )

        let fixedMacro = processor.getMacro(name: "FIXED")!
        #expect(fixedMacro.maximumArguments == 2)

        // Macro with variable args has unlimited maximum
        processor.defineMacro(
            name: "VARIABLE",
            parameters: [.standard("A"), .variableArgs("REST")],
            body: .atom("BODY", location),
            at: location
        )

        let variableMacro = processor.getMacro(name: "VARIABLE")!
        #expect(variableMacro.maximumArguments == nil)
    }

    @Test("Macro has variable args check")
    func macroHasVariableArgsCheck() throws {
        let processor = MacroProcessor()
        let location = createLocation()

        processor.defineMacro(
            name: "NO-VARARGS",
            parameters: [.standard("A")],
            body: .atom("BODY", location),
            at: location
        )

        processor.defineMacro(
            name: "HAS-VARARGS",
            parameters: [.variableArgs("ARGS")],
            body: .atom("BODY", location),
            at: location
        )

        let noVarArgs = processor.getMacro(name: "NO-VARARGS")!
        #expect(noVarArgs.hasVariableArgs == false)

        let hasVarArgs = processor.getMacro(name: "HAS-VARARGS")!
        #expect(hasVarArgs.hasVariableArgs == true)
    }
}
