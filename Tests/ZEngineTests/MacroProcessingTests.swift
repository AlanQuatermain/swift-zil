import Testing
@testable import ZEngine

@Suite("Macro Processing Tests")
struct MacroProcessingTests {

    @Test("ZIL FORM-based macro expansion")
    func zilFormBasedMacroExpansion() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define: ENABLE(INT) -> <FORM PUT .INT ,C-ENABLED? 1>
        // This represents: <DEFMAC ENABLE ('INT) <FORM PUT .INT ,C-ENABLED? 1>>
        let body = ZILExpression.list([
            .atom("FORM", location),
            .atom("PUT", location),
            .localVariable("INT", location), // .INT syntax in ZIL
            .globalVariable("C-ENABLED?", location), // ,C-ENABLED? syntax
            .number(1, location)
        ], location)

        let success = processor.defineMacro(
            name: "ENABLE",
            parameters: [.standard("INT")],  // Parameter name without quote in our implementation
            body: body,
            at: location
        )
        #expect(success == true, "Should successfully define FORM-based macro")

        // Test expansion with an interrupt name
        let result = processor.expandMacro(
            name: "ENABLE",
            arguments: [.atom("MY-INTERRUPT", location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("FORM-based macro should expand, but got: \(result)")
            return
        }

        // Should expand to: <PUT MY-INTERRUPT ,C-ENABLED? 1>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded result should be a list, but got: \(expanded)")
            return
        }
        #expect(elements.count == 4, "Should have PUT + interrupt + global + value")

        guard case .atom(let putOp, _) = elements[0] else {
            Issue.record("First element should be PUT, but got: \(elements[0])")
            return
        }
        #expect(putOp == "PUT", "Should start with PUT operation")

        guard case .atom(let interrupt, _) = elements[1] else {
            Issue.record("Second element should be substituted interrupt name, but got: \(elements[1])")
            return
        }
        #expect(interrupt == "MY-INTERRUPT", "Should substitute parameter correctly")

        guard case .globalVariable(let globalVar, _) = elements[2] else {
            Issue.record("Third element should be global variable, but got: \(elements[2])")
            return
        }
        #expect(globalVar == "C-ENABLED?", "Should preserve global variable reference")

        guard case .number(let value, _) = elements[3] else {
            Issue.record("Fourth element should be number, but got: \(elements[3])")
            return
        }
        #expect(value == 1, "Should have value 1")
    }


    @Test("Macro argument count validation")
    func macroArgumentCountValidation() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define macro that expects 2 parameters
        let body = ZILExpression.list([
            .atom("+", location),
            .atom("A", location),
            .atom("B", location)
        ], location)

        _ = processor.defineMacro(
            name: "ADD",
            parameters: [.standard("A"), .standard("B")],
            body: body,
            at: location
        )

        // Try to expand with wrong number of arguments
        let result = processor.expandMacro(
            name: "ADD",
            arguments: [.number(1, location)], // Only 1 argument, need 2
            at: location
        )

        guard case .error(let diagnostic) = result else {
            Issue.record("Should produce argument count error, but got: \(result)")
            return
        }

        guard case .argumentCountMismatch(let expected, let got) = diagnostic.code else {
            Issue.record("Should be argument count mismatch error, but got: \(diagnostic.code)")
            return
        }
        #expect(expected == 2, "Should expect 2 arguments")
        #expect(got == 1, "Should have received 1 argument")
    }

    @Test("Undefined macro error")
    func undefinedMacroError() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        let result = processor.expandMacro(
            name: "NONEXISTENT",
            arguments: [],
            at: location
        )

        guard case .error(let diagnostic) = result else {
            Issue.record("Should produce undefined macro error, but got: \(result)")
            return
        }

        guard case .undefinedMacro(let name) = diagnostic.code else {
            Issue.record("Should be undefined macro error, but got: \(diagnostic.code)")
            return
        }
        #expect(name == "NONEXISTENT", "Should reference the undefined macro name")
    }

    @Test("Recursive macro detection")
    func recursiveMacroDetection() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define a macro that calls itself: RECURSE() -> (RECURSE)
        let recursiveBody = ZILExpression.list([
            .atom("RECURSE", location)
        ], location)

        _ = processor.defineMacro(
            name: "RECURSE",
            parameters: [],
            body: recursiveBody,
            at: location
        )

        // Test that expandExpression handles recursive expansion gracefully
        let testExpression = ZILExpression.list([
            .atom("RECURSE", location)
        ], location)

        // This should detect recursion and return the original expression to break the cycle
        let expandedExpr = processor.expandExpression(testExpression)

        // The result should be the original expression since recursion was detected
        guard case .list(let elements, _) = expandedExpr else {
            Issue.record("Should return a list expression, but got: \(expandedExpr)")
            return
        }
        #expect(elements.count == 1, "Should have one element")
        guard case .atom(let atomName, _) = elements[0] else {
            Issue.record("Should contain RECURSE atom, but got: \(elements[0])")
            return
        }
        #expect(atomName == "RECURSE", "Should contain RECURSE atom (recursion prevented)")
    }

    @Test("Complex macro with nested substitution")
    func complexMacroWithNestedSubstitution() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define TRIPLE(X) -> (+ X (+ X X))
        let innerAdd = ZILExpression.list([
            .atom("+", location),
            .atom("X", location),
            .atom("X", location)
        ], location)

        let outerAdd = ZILExpression.list([
            .atom("+", location),
            .atom("X", location),
            innerAdd
        ], location)

        _ = processor.defineMacro(
            name: "TRIPLE",
            parameters: [.standard("X")],
            body: outerAdd,
            at: location
        )

        let result = processor.expandMacro(
            name: "TRIPLE",
            arguments: [.number(3, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Complex macro should expand successfully, but got: \(result)")
            return
        }

        // Should expand to: (+ 3 (+ 3 3))
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded result should be a list, but got: \(expanded)")
            return
        }
        #expect(elements.count == 3, "Should have + operator and 2 operands")

        guard case .number(let firstOperand, _) = elements[1] else {
            Issue.record("Second element should be number 3, but got: \(elements[1])")
            return
        }
        #expect(firstOperand == 3, "First operand should be 3")

        guard case .list(let nestedAdd, _) = elements[2] else {
            Issue.record("Third element should be nested addition, but got: \(elements[2])")
            return
        }
        #expect(nestedAdd.count == 3, "Nested addition should have 3 elements")
    }

    @Test("Macro direct substitution system")
    func macroDirectSubstitution() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define macro with direct substitution
        // LET-TEMP(EXPR) -> (SET TEMP EXPR)
        let body = ZILExpression.list([
            .atom("SET", location),
            .localVariable("TEMP", location),  // This should NOT get hygiene treatment in ZIL
            .atom("EXPR", location)
        ], location)

        _ = processor.defineMacro(
            name: "LET-TEMP",
            parameters: [.standard("EXPR")],
            body: body,
            at: location
        )

        let result = processor.expandMacro(
            name: "LET-TEMP",
            arguments: [.number(42, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Macro should expand with direct substitution, but got: \(result)")
            return
        }

        // Check that TEMP was preserved (no hygiene in ZIL)
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded result should be a list, but got: \(expanded)")
            return
        }
        #expect(elements.count == 3, "Should have SET + variable + value")

        guard case .localVariable(let varName, _) = elements[1] else {
            Issue.record("Second element should be original local variable, but got: \(elements[1])")
            return
        }
        #expect(varName == "TEMP", "Variable should keep original name (no hygiene in ZIL)")

        guard case .number(let value, _) = elements[2] else {
            Issue.record("Third element should be substituted parameter, but got: \(elements[2])")
            return
        }
        #expect(value == 42, "Parameter should be directly substituted")
    }

    @Test("Macro expansion in nested expressions")
    func macroExpansionInNestedExpressions() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define SQUARE(X) -> (* X X)
        let squareBody = ZILExpression.list([
            .atom("*", location),
            .atom("X", location),
            .atom("X", location)
        ], location)

        _ = processor.defineMacro(
            name: "SQUARE",
            parameters: [.standard("X")],
            body: squareBody,
            at: location
        )

        // Create expression that uses SQUARE: (+ (SQUARE 3) (SQUARE 4))
        let expression = ZILExpression.list([
            .atom("+", location),
            .list([.atom("SQUARE", location), .number(3, location)], location),
            .list([.atom("SQUARE", location), .number(4, location)], location)
        ], location)

        let expanded = processor.expandExpression(expression)

        // Should expand to: (+ (* 3 3) (* 4 4))
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded expression should be a list, but got: \(expanded)")
            return
        }
        #expect(elements.count == 3, "Should have + and 2 operands")

        // Check first SQUARE expansion: (* 3 3)
        guard case .list(let firstSquare, _) = elements[1] else {
            Issue.record("First operand should be expanded SQUARE, but got: \(elements[1])")
            return
        }
        #expect(firstSquare.count == 3, "First SQUARE should have * and 2 operands")

        // Check second SQUARE expansion: (* 4 4)
        guard case .list(let secondSquare, _) = elements[2] else {
            Issue.record("Second operand should be expanded SQUARE, but got: \(elements[2])")
            return
        }
        #expect(secondSquare.count == 3, "Second SQUARE should have * and 2 operands")
    }


    @Test("Debug tracing functionality")
    func debugTracingFunctionality() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Enable debug tracing
        processor.setDebugTracing(true)

        // Define and expand a macro
        let body = ZILExpression.list([
            .atom("DEBUG-CALL", location),
            .atom("ARG", location)
        ], location)

        _ = processor.defineMacro(
            name: "DEBUG-MACRO",
            parameters: [.standard("ARG")],
            body: body,
            at: location
        )

        _ = processor.expandMacro(
            name: "DEBUG-MACRO",
            arguments: [.number(123, location)],
            at: location
        )

        let trace = processor.getExpansionTrace()
        #expect(trace.count == 1, "Should have one expansion trace entry")

        if let entry = trace.first {
            #expect(entry.macroName == "DEBUG-MACRO", "Trace should record macro name")
            #expect(entry.arguments.count == 1, "Trace should record arguments")
            #expect(entry.location.file == "test.zil", "Trace should record location")
        }

        // Disable tracing
        processor.setDebugTracing(false)
        let emptyTrace = processor.getExpansionTrace()
        #expect(emptyTrace.isEmpty, "Trace should be cleared when disabled")
    }

    @Test("Macro lookup and enumeration")
    func macroLookupAndEnumeration() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Should have no built-in macros initially (ZIL has no built-in macros)
        let initialMacros = processor.getAllMacros()
        #expect(initialMacros.count == 0, "ZIL should have no built-in macros")

        // Define custom macro
        let customBody = ZILExpression.atom("CUSTOM", location)
        _ = processor.defineMacro(
            name: "CUSTOM",
            parameters: [],
            body: customBody,
            at: location
        )

        // Look up custom macro
        let customMacro = processor.getMacro(name: "CUSTOM")
        #expect(customMacro != nil, "Should find custom macro")
        #expect(customMacro?.name == "CUSTOM", "Should have correct name")
        #expect(customMacro?.isBuiltIn == false, "Custom macro should not be built-in")

        // All macros should now include custom one
        let allMacros = processor.getAllMacros()
        #expect(allMacros.count == 1, "Should have one macro")

        let customFound = allMacros.contains { $0.name == "CUSTOM" }
        #expect(customFound, "Should find custom macro in enumeration")
    }

    @Test("Comprehensive diagnostics collection")
    func comprehensiveDiagnosticsCollection() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Initially should have no diagnostics
        let initialDiagnostics = processor.getDiagnostics()
        #expect(initialDiagnostics.isEmpty, "Should start with no diagnostics")

        // Generate multiple types of errors

        // 1. Undefined macro error
        let undefResult = processor.expandMacro(
            name: "UNDEFINED-MACRO",
            arguments: [],
            at: location
        )
        guard case .error = undefResult else {
            Issue.record("Should produce undefined macro error, but got: \(undefResult)")
            return
        }

        // 2. Argument count mismatch error
        let body = ZILExpression.atom("BODY", location)
        _ = processor.defineMacro(
            name: "TWO-PARAM",
            parameters: [.standard("A"), .standard("B")],
            body: body,
            at: location
        )

        let mismatchResult = processor.expandMacro(
            name: "TWO-PARAM",
            arguments: [.number(1, location)], // Only 1 arg, needs 2
            at: location
        )
        guard case .error = mismatchResult else {
            Issue.record("Should produce argument count error, but got: \(mismatchResult)")
            return
        }

        // Check that both diagnostics were collected
        let allDiagnostics = processor.getDiagnostics()
        #expect(allDiagnostics.count == 2, "Should have collected two diagnostics")

        // Verify diagnostic types
        let undefinedDiag = allDiagnostics.first { diagnostic in
            if case .undefinedMacro = diagnostic.code {
                return true
            }
            return false
        }
        #expect(undefinedDiag != nil, "Should have undefined macro diagnostic")

        let mismatchDiag = allDiagnostics.first { diagnostic in
            if case .argumentCountMismatch = diagnostic.code {
                return true
            }
            return false
        }
        #expect(mismatchDiag != nil, "Should have argument count mismatch diagnostic")

        // Test diagnostic message formatting
        if let undef = undefinedDiag {
            let message = undef.message
            #expect(message.contains("UNDEFINED-MACRO"), "Message should contain macro name")
            #expect(message.contains("Undefined"), "Message should indicate undefined error")
        }

        if let mismatch = mismatchDiag {
            let message = mismatch.message
            #expect(message.contains("2"), "Message should contain expected count")
            #expect(message.contains("1"), "Message should contain actual count")
        }

        // Test clearing diagnostics
        processor.clearDiagnostics()
        let clearedDiagnostics = processor.getDiagnostics()
        #expect(clearedDiagnostics.isEmpty, "Diagnostics should be cleared")
    }

    @Test("Macro expansion error handling")
    func macroExpansionErrorHandling() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Test recursive macro with detailed error tracking
        let recursiveBody = ZILExpression.list([
            .atom("RECURSIVE-CALL", location)
        ], location)

        _ = processor.defineMacro(
            name: "RECURSIVE-CALL",
            parameters: [],
            body: recursiveBody,
            at: location
        )

        // This should detect recursion and handle it gracefully
        let testExpr = ZILExpression.list([
            .atom("RECURSIVE-CALL", location)
        ], location)

        // Using expandExpression to trigger recursion detection
        let result = processor.expandExpression(testExpr)

        // Should return original expression due to recursion prevention
        if case .list(let elements, _) = result {
            #expect(elements.count == 1, "Should have one element")
            if case .atom(let name, _) = elements[0] {
                #expect(name == "RECURSIVE-CALL", "Should preserve original call due to recursion")
            }
        }

        // Test error recovery with malformed macro bodies
        // Create a scenario where macro expansion might encounter issues
        let complexBody = ZILExpression.list([
            .atom("COMPLEX-OP", location),
            .localVariable("PARAM", location),
            .list([
                .atom("NESTED", location),
                .localVariable("PARAM", location)
            ], location)
        ], location)

        let defineSuccess = processor.defineMacro(
            name: "COMPLEX-MACRO",
            parameters: [.standard("PARAM")],
            body: complexBody,
            at: location
        )
        #expect(defineSuccess == true, "Should define complex macro")

        // Expand with various argument types
        let numberResult = processor.expandMacro(
            name: "COMPLEX-MACRO",
            arguments: [.number(42, location)],
            at: location
        )

        guard case .success(let expanded) = numberResult else {
            Issue.record("Complex macro should expand successfully, but got: \(numberResult)")
            return
        }

        // Verify proper substitution in nested structure
        if case .list(let elements, _) = expanded {
            #expect(elements.count == 3, "Should have three elements in expansion")

            // Check that parameter was substituted in nested structure
            if case .list(let nestedElements, _) = elements[2] {
                #expect(nestedElements.count == 2, "Nested list should have two elements")
                if case .number(let value, _) = nestedElements[1] {
                    #expect(value == 42, "Parameter should be substituted in nested context")
                }
            }
        }

        // Verify no errors were generated for successful expansion
        let diagnosticsAfterSuccess = processor.getDiagnostics()
        #expect(diagnosticsAfterSuccess.isEmpty, "Should have no diagnostics after successful expansion")
    }

    @Test("Multiple diagnostic accumulation and management")
    func multipleDiagnosticAccumulation() throws {
        let processor = MacroProcessor()
        let location1 = SourceLocation(file: "test.zil", line: 1, column: 1)
        let location2 = SourceLocation(file: "test.zil", line: 5, column: 10)
        let location3 = SourceLocation(file: "test.zil", line: 8, column: 5)

        // Generate multiple errors from different locations
        _ = processor.expandMacro(name: "UNDEF1", arguments: [], at: location1)
        _ = processor.expandMacro(name: "UNDEF2", arguments: [], at: location2)
        _ = processor.expandMacro(name: "UNDEF3", arguments: [], at: location3)

        let diagnostics = processor.getDiagnostics()
        #expect(diagnostics.count == 3, "Should accumulate three diagnostics")

        // Verify each diagnostic has correct location
        for (index, diagnostic) in diagnostics.enumerated() {
            switch index {
            case 0:
                #expect(diagnostic.location.line == 1, "First diagnostic should be from line 1")
            case 1:
                #expect(diagnostic.location.line == 5, "Second diagnostic should be from line 5")
            case 2:
                #expect(diagnostic.location.line == 8, "Third diagnostic should be from line 8")
            default:
                break
            }
        }

        // Test partial clearing by generating more errors after clearing
        processor.clearDiagnostics()

        // Generate new error
        _ = processor.expandMacro(name: "NEW-UNDEF", arguments: [], at: location1)

        let newDiagnostics = processor.getDiagnostics()
        #expect(newDiagnostics.count == 1, "Should have only new diagnostic after clearing")

        if let newDiag = newDiagnostics.first, case .undefinedMacro(let name) = newDiag.code {
            #expect(name == "NEW-UNDEF", "Should have new undefined macro name")
        }
    }

    @Test("FORM construction engine basic functionality")
    func formConstructionBasicFunctionality() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define ENABLE macro using FORM: ENABLE(INT) -> <FORM PUT .INT ,C-ENABLED? 1>
        let formBody = ZILExpression.list([
            .atom("FORM", location),
            .atom("PUT", location),
            .localVariable("INT", location), // .INT parameter
            .globalVariable("C-ENABLED?", location), // ,C-ENABLED? global
            .number(1, location)
        ], location)

        _ = processor.defineMacro(
            name: "ENABLE",
            parameters: [.standard("INT")],
            body: formBody,
            at: location
        )

        // Test expansion: <ENABLE MY-INTERRUPT> -> <PUT MY-INTERRUPT ,C-ENABLED? 1>
        let result = processor.expandMacro(
            name: "ENABLE",
            arguments: [.atom("MY-INTERRUPT", location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("FORM-based macro should expand successfully, but got: \(result)")
            return
        }

        // Should expand to: <PUT MY-INTERRUPT ,C-ENABLED? 1>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded result should be a list, but got: \(expanded)")
            return
        }

        #expect(elements.count == 4, "Should have PUT + interrupt + global + value")

        guard case .atom(let operation, _) = elements[0] else {
            Issue.record("First element should be PUT, but got: \(elements[0])")
            return
        }
        #expect(operation == "PUT", "Should start with PUT operation")

        guard case .atom(let interrupt, _) = elements[1] else {
            Issue.record("Second element should be substituted interrupt name, but got: \(elements[1])")
            return
        }
        #expect(interrupt == "MY-INTERRUPT", "Should substitute parameter correctly")

        guard case .globalVariable(let global, _) = elements[2] else {
            Issue.record("Third element should be global variable, but got: \(elements[2])")
            return
        }
        #expect(global == "C-ENABLED?", "Should preserve global variable")

        guard case .number(let value, _) = elements[3] else {
            Issue.record("Fourth element should be number, but got: \(elements[3])")
            return
        }
        #expect(value == 1, "Should have value 1")
    }

    @Test("FORM construction with multiple parameters")
    func formConstructionMultipleParameters() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define SETG macro: SETG(VAR, VAL) -> <FORM SETG .VAR .VAL>
        let formBody = ZILExpression.list([
            .atom("FORM", location),
            .atom("SETG", location),
            .localVariable("VAR", location),
            .localVariable("VAL", location)
        ], location)

        _ = processor.defineMacro(
            name: "SETGLOBAL",
            parameters: [.standard("VAR"), .standard("VAL")],
            body: formBody,
            at: location
        )

        // Test expansion: <SETGLOBAL SCORE 100> -> <SETG SCORE 100>
        let result = processor.expandMacro(
            name: "SETGLOBAL",
            arguments: [.atom("SCORE", location), .number(100, location)],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("FORM macro with multiple parameters should expand, but got: \(result)")
            return
        }

        guard case .list(let elements, _) = expanded else {
            Issue.record("Expanded result should be a list, but got: \(expanded)")
            return
        }

        #expect(elements.count == 3, "Should have SETG + variable + value")

        guard case .atom(let op, _) = elements[0] else {
            Issue.record("First element should be SETG, but got: \(elements[0])")
            return
        }
        #expect(op == "SETG", "Should be SETG operation")

        guard case .atom(let varName, _) = elements[1] else {
            Issue.record("Second element should be variable name, but got: \(elements[1])")
            return
        }
        #expect(varName == "SCORE", "Should substitute VAR parameter")

        guard case .number(let value, _) = elements[2] else {
            Issue.record("Third element should be value, but got: \(elements[2])")
            return
        }
        #expect(value == 100, "Should substitute VAL parameter")
    }

    @Test("FORM construction error handling")
    func formConstructionErrorHandling() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define invalid FORM macro with malformed FORM expression
        let invalidFormBody = ZILExpression.list([
            .atom("FORM", location)
            // Missing operation - should cause FORM construction to fail gracefully
        ], location)

        _ = processor.defineMacro(
            name: "INVALID-FORM",
            parameters: [],
            body: invalidFormBody,
            at: location
        )

        // Test expansion - should fall back to regular substitution when FORM fails
        let result = processor.expandMacro(
            name: "INVALID-FORM",
            arguments: [],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Even invalid FORM should not cause macro expansion to fail completely, but got: \(result)")
            return
        }

        // Should fall back to the original FORM expression with substitutions applied
        guard case .list(let elements, _) = expanded else {
            Issue.record("Should fall back to list expression, but got: \(expanded)")
            return
        }

        guard case .atom(let formAtom, _) = elements[0] else {
            Issue.record("Should preserve FORM atom, but got: \(elements[0])")
            return
        }
        #expect(formAtom == "FORM", "Should preserve FORM keyword in fallback")
    }

    @Test("FORM construction with nested expressions")
    func formConstructionNestedExpressions() throws {
        let processor = MacroProcessor()
        let location = SourceLocation(file: "test.zil", line: 1, column: 1)

        // Define macro that creates FORM with nested expressions
        // COND-SET(VAR, COND, VAL) -> <FORM COND .COND <FORM SETG .VAR .VAL>>
        let innerForm = ZILExpression.list([
            .atom("FORM", location),
            .atom("SETG", location),
            .localVariable("VAR", location),
            .localVariable("VAL", location)
        ], location)

        let outerForm = ZILExpression.list([
            .atom("FORM", location),
            .atom("COND", location),
            .localVariable("COND-PARAM", location),  // Changed parameter name to avoid collision
            innerForm
        ], location)

        _ = processor.defineMacro(
            name: "COND-SET",
            parameters: [.standard("VAR"), .standard("COND-PARAM"), .standard("VAL")],
            body: outerForm,
            at: location
        )

        // Test expansion
        let result = processor.expandMacro(
            name: "COND-SET",
            arguments: [
                .atom("WINNER", location),
                .atom("T", location),
                .number(1, location)
            ],
            at: location
        )

        guard case .success(let expanded) = result else {
            Issue.record("Nested FORM macro should expand, but got: \(result)")
            return
        }

        // Should expand to: <COND T <SETG WINNER 1>>
        guard case .list(let elements, _) = expanded else {
            Issue.record("Result should be a list, but got: \(expanded)")
            return
        }

        #expect(elements.count == 3, "Should have COND + condition + action")

        guard case .atom(let condOp, _) = elements[0] else {
            Issue.record("First element should be COND, but got: \(elements[0])")
            return
        }
        #expect(condOp == "COND", "Should be COND operation")

        guard case .atom(let condition, _) = elements[1] else {
            Issue.record("Second element should be condition, but got: \(elements[1])")
            return
        }
        #expect(condition == "T", "Should substitute condition parameter")

        // Check the nested SETG form
        guard case .list(let nestedElements, _) = elements[2] else {
            Issue.record("Third element should be nested list, but got: \(elements[2])")
            return
        }
        #expect(nestedElements.count == 3, "Nested form should have SETG + var + val")

        guard case .atom(let setgOp, _) = nestedElements[0] else {
            Issue.record("Nested first element should be SETG, but got: \(nestedElements[0])")
            return
        }
        #expect(setgOp == "SETG", "Nested form should start with SETG")
    }
}